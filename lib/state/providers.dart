import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/timecode/timecode.dart';
import '../models/cue.dart';
import '../models/session_model.dart';
import '../models/show_segment.dart';
import '../models/user_model.dart';

// ─── App / User Profile ──────────────────────────────────────────────────────

class AppState {
  const AppState({this.userName, this.userRole, this.isLoading = true});

  final String? userName;
  final String? userRole;
  final bool isLoading;

  bool get isOnboarded => userName != null && userName!.isNotEmpty;

  AppState copyWith({String? userName, String? userRole, bool? isLoading}) =>
      AppState(
        userName: userName ?? this.userName,
        userRole: userRole ?? this.userRole,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppState(
      userName: prefs.getString('user_name'),
      userRole: prefs.getString('user_role'),
      isLoading: false,
    );
  }

  Future<void> saveProfile(String name, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_role', role);
    state = state.copyWith(userName: name, userRole: role, isLoading: false);
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((_) => AppStateNotifier());

// ─── Timecode ────────────────────────────────────────────────────────────────

class TimecodeState {
  const TimecodeState({
    this.frames = 0,
    this.isRunning = false,
    this.framerate = 25,
  });

  final int frames;
  final bool isRunning;
  final int framerate;

  TimecodeState copyWith({int? frames, bool? isRunning, int? framerate}) =>
      TimecodeState(
        frames: frames ?? this.frames,
        isRunning: isRunning ?? this.isRunning,
        framerate: framerate ?? this.framerate,
      );
}

class TimecodeNotifier extends StateNotifier<TimecodeState> {
  TimecodeNotifier() : super(const TimecodeState());

  void update(int frames, {required bool isRunning, int? framerate}) =>
      state = state.copyWith(
          frames: frames, isRunning: isRunning, framerate: framerate);

  void setFramerate(int framerate) =>
      state = state.copyWith(framerate: framerate);
}

final timecodeProvider =
    StateNotifierProvider<TimecodeNotifier, TimecodeState>(
        (_) => TimecodeNotifier());

// ─── Session ─────────────────────────────────────────────────────────────────

final currentSessionProvider = StateProvider<SessionModel?>((ref) => null);

// ─── Show Time ───────────────────────────────────────────────────────────────

class ShowTimeState {
  const ShowTimeState({
    this.elapsedMs = 0,
    this.isRunning = false,
    this.isFreeRunning = false,
    this.segmentName = '',
    this.hasSegments = false,
  });

  final int elapsedMs;
  final bool isRunning;
  final bool isFreeRunning;
  final String segmentName;

  /// False when the session has no segments defined — suppresses the display.
  final bool hasSegments;

  Duration get elapsed => Duration(milliseconds: elapsedMs);

  String get formatted {
    final d = elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  ShowTimeState copyWith({
    int? elapsedMs,
    bool? isRunning,
    bool? isFreeRunning,
    String? segmentName,
    bool? hasSegments,
  }) =>
      ShowTimeState(
        elapsedMs: elapsedMs ?? this.elapsedMs,
        isRunning: isRunning ?? this.isRunning,
        isFreeRunning: isFreeRunning ?? this.isFreeRunning,
        segmentName: segmentName ?? this.segmentName,
        hasSegments: hasSegments ?? this.hasSegments,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class ShowTimeNotifier extends StateNotifier<ShowTimeState> {
  ShowTimeNotifier(this._ref) : super(const ShowTimeState()) {
    _tcSub = _ref.listen<TimecodeState>(timecodeProvider, _onTC);
    _sessionSub = _ref.listen<SessionModel?>(currentSessionProvider, _onSession);
    // Bootstrap: listeners only fire on future changes, so read current state now.
    final session = _ref.read(currentSessionProvider);
    if (session != null) _onSession(null, session);
  }

  final Ref _ref;
  late final ProviderSubscription<TimecodeState> _tcSub;
  late final ProviderSubscription<SessionModel?> _sessionSub;

  Timer? _wallClockTimer;
  DateTime? _freeRunningStartedAt;
  int _freeRunningBaseMs = 0;

  /// Actual elapsed milliseconds for each completed segment, keyed by segment id.
  final Map<String, int> _completedMs = {};

  String? _currentSegmentId;

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onSession(SessionModel? prev, SessionModel? next) {
    // When switching sessions, reset all state.
    _cancelFreeRunning();
    _completedMs.clear();
    _currentSegmentId = null;
    if (next == null || !next.hasSegments) {
      state = const ShowTimeState();
      return;
    }
    // Set hasSegments: true BEFORE evaluating so that _handleTCStopped's
    // copyWith(isRunning: false) preserves it rather than inheriting false.
    state = const ShowTimeState(hasSegments: true);
    _evaluate(next, _ref.read(timecodeProvider));
  }

  void _onTC(TimecodeState? _, TimecodeState next) {
    final session = _ref.read(currentSessionProvider);
    if (session == null || !session.hasSegments) return;
    _evaluate(session, next);
  }

  // ── Core evaluation ────────────────────────────────────────────────────────

  void _evaluate(SessionModel session, TimecodeState tc) {
    if (tc.isRunning) {
      _handleTCRunning(session, tc);
    } else {
      _handleTCStopped(session, tc);
    }
  }

  void _handleTCRunning(SessionModel session, TimecodeState tc) {
    final seg = _findTCSegment(session.segments, tc.frames, tc.framerate);
    if (seg == null) return; // TC on, but outside any defined segment (pre-show etc.)

    if (seg.id != _currentSegmentId) {
      // We've entered a (possibly new) TC segment.
      if (_freeRunningStartedAt != null && _currentSegmentId != null) {
        // Record actual free-running duration for the segment we were just in.
        _completedMs[_currentSegmentId!] =
            DateTime.now().difference(_freeRunningStartedAt!).inMilliseconds;
      }
      _cancelFreeRunning();
      _currentSegmentId = seg.id;
    }

    final segStartMs = _segmentStartMs(session, seg);
    final segTcStartFrames =
        Timecode.stringToFrames(seg.tcStart!, tc.framerate);
    final tcElapsedMs =
        ((tc.frames - segTcStartFrames) / tc.framerate * 1000).round();

    state = ShowTimeState(
      elapsedMs: segStartMs + tcElapsedMs,
      isRunning: true,
      isFreeRunning: false,
      segmentName: seg.label,
      hasSegments: true,
    );
  }

  void _handleTCStopped(SessionModel session, TimecodeState tc) {
    // If already free-running, just keep the wall clock going — don't restart.
    if (_freeRunningStartedAt != null) return;

    // Mark current TC segment complete (using its defined TC range).
    if (_currentSegmentId != null) {
      final cur = _segmentById(session, _currentSegmentId!);
      if (cur != null && cur.isTimecoded && cur.tcEnd != null) {
        final startF = Timecode.stringToFrames(cur.tcStart!, tc.framerate);
        final endF = Timecode.stringToFrames(cur.tcEnd!, tc.framerate);
        _completedMs[_currentSegmentId!] =
            ((endF - startF) / tc.framerate * 1000).round();
      }
    }

    // Look for the next free-running segment.
    final curIdx = _currentSegmentId != null
        ? session.segments.indexWhere((s) => s.id == _currentSegmentId)
        : -1;
    final nextIdx = curIdx + 1;
    if (nextIdx < session.segments.length &&
        session.segments[nextIdx].isFreeRunning) {
      final freeSeg = session.segments[nextIdx];
      _currentSegmentId = freeSeg.id;
      _freeRunningBaseMs = state.elapsedMs;
      _freeRunningStartedAt = DateTime.now();
      _wallClockTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) {
        _tickFreeRunning(freeSeg.label);
      });
    } else {
      // TC stopped with no free-running section — show time pauses.
      state = state.copyWith(isRunning: false);
    }
  }

  void _tickFreeRunning(String segmentName) {
    if (_freeRunningStartedAt == null) return;
    final elapsed =
        DateTime.now().difference(_freeRunningStartedAt!).inMilliseconds;
    state = ShowTimeState(
      elapsedMs: _freeRunningBaseMs + elapsed,
      isRunning: true,
      isFreeRunning: true,
      segmentName: segmentName,
      hasSegments: true,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the TC segment that contains [frames], or null.
  ShowSegment? _findTCSegment(
      List<ShowSegment> segments, int frames, int framerate) {
    for (final seg in segments) {
      if (!seg.isTimecoded || seg.tcStart == null) continue;
      final start = Timecode.stringToFrames(seg.tcStart!, framerate);
      final end = seg.tcEnd != null
          ? Timecode.stringToFrames(seg.tcEnd!, framerate)
          : start + (framerate * 3600 * 24); // open-ended: up to 24h
      if (frames >= start && frames < end) return seg;
    }
    return null;
  }

  /// Accumulated show time (ms) at the start of [targetSegment].
  int _segmentStartMs(SessionModel session, ShowSegment targetSegment) {
    int total = 0;
    final framerate = _ref.read(timecodeProvider).framerate;
    for (final seg in session.segments) {
      if (seg.id == targetSegment.id) break;
      if (_completedMs.containsKey(seg.id)) {
        total += _completedMs[seg.id]!;
      } else if (seg.isTimecoded &&
          seg.tcStart != null &&
          seg.tcEnd != null) {
        final s = Timecode.stringToFrames(seg.tcStart!, framerate);
        final e = Timecode.stringToFrames(seg.tcEnd!, framerate);
        total += ((e - s) / framerate * 1000).round();
      } else if (seg.isFreeRunning) {
        total += seg.estimatedDurationSecs * 1000;
      }
    }
    return total;
  }

  ShowSegment? _segmentById(SessionModel session, String id) {
    final idx = session.segments.indexWhere((s) => s.id == id);
    return idx >= 0 ? session.segments[idx] : null;
  }

  /// Resets show time back to zero (e.g. between shows, or after aborting).
  void reset() {
    _cancelFreeRunning();
    _completedMs.clear();
    _currentSegmentId = null;
    final session = _ref.read(currentSessionProvider);
    state = ShowTimeState(hasSegments: session?.hasSegments ?? false);
  }

  /// Freezes the free-running wall clock without discarding elapsed time.
  /// Use when TC stops unexpectedly in mid-interval and the show will not resume.
  void stopFreeRunning() {
    if (!state.isFreeRunning) return;
    _cancelFreeRunning();
    state = state.copyWith(isRunning: false, isFreeRunning: false);
  }

  void _cancelFreeRunning() {
    _wallClockTimer?.cancel();
    _wallClockTimer = null;
    _freeRunningStartedAt = null;
  }

  @override
  void dispose() {
    _tcSub.close();
    _sessionSub.close();
    _cancelFreeRunning();
    super.dispose();
  }
}

final showTimeProvider =
    StateNotifierProvider<ShowTimeNotifier, ShowTimeState>(
        (ref) => ShowTimeNotifier(ref));

// ─── Session Discovery (mDNS) ─────────────────────────────────────────────────

final discoveredSessionsProvider =
    StateProvider<List<SessionModel>>((ref) => _mockSessions);

final _mockSessions = [
  SessionModel(
    id: 'mock-001',
    name: 'Phantom of the Opera — Wed Night',
    framerate: 25,
    version: 3,
    masterDeviceId: 'device-001',
    created: DateTime(2026, 6, 10, 19, 0),
    hostAddress: '192.168.1.42',
    hostPort: 8080,
    segments: const [
      ShowSegment(
        id: 'seg-act1',
        label: 'Act 1',
        type: ShowSegmentType.timecoded,
        tcStart: '01:00:00:00',
        tcEnd: '01:45:00:00',
      ),
      ShowSegment(
        id: 'seg-interval',
        label: 'Interval',
        type: ShowSegmentType.freeRunning,
        estimatedDurationSecs: 1200, // 20 min estimate
      ),
      ShowSegment(
        id: 'seg-act2',
        label: 'Act 2',
        type: ShowSegmentType.timecoded,
        tcStart: '02:00:00:00',
        tcEnd: '02:30:00:00',
      ),
    ],
    users: const [
      UserModel(
        name: 'Sarah',
        role: 'Stage Manager',
        permission: Permission.directEdit,
        isMaster: true,
        isConnected: true,
      ),
      UserModel(
        name: 'James',
        role: 'Lighting Op',
        permission: Permission.propose,
        isConnected: true,
      ),
      UserModel(
        name: 'Tom',
        role: 'Director',
        permission: Permission.view,
        isConnected: false,
      ),
    ],
    cues: const [
      Cue(id: 1, label: 'Overture Start',    timecode: '01:02:30:00'),
      Cue(id: 2, label: 'Chandelier Drop',   timecode: '01:08:15:12'),
      Cue(id: 3, label: 'Fly Cue 1',         timecode: '01:12:34:00'),
      Cue(id: 4, label: 'Costume Change 1',  timecode: '01:23:10:15'),
      Cue(id: 5, label: 'Scene 2 — Lights',  timecode: '01:31:45:00'),
      Cue(id: 6, label: 'Music Sting',       timecode: '01:42:18:10'),
      // Show-time cue during interval (no TC)
      Cue(
        id: 7,
        label: 'Interval — 5 min call',
        triggerType: CueTriggerType.showTime,
        showTimeSecs: 2700 + 900, // 45 min Act1 + 15 min into interval
      ),
      Cue(id: 8, label: 'Act 2 — Opening',   timecode: '02:00:30:00'),
      Cue(id: 9, label: 'Barricade Fly',     timecode: '02:10:00:00'),
      Cue(id: 10, label: 'Final Blackout',   timecode: '02:28:00:00'),
    ],
  ),
  SessionModel(
    id: 'mock-002',
    name: 'Les Misérables — Tech Run',
    framerate: 30,
    version: 1,
    masterDeviceId: 'device-002',
    created: DateTime(2026, 6, 10, 14, 0),
    hostAddress: '192.168.1.55',
    hostPort: 8080,
    users: const [
      UserModel(
        name: 'Alex',
        role: 'Stage Manager',
        permission: Permission.directEdit,
        isMaster: true,
        isConnected: true,
      ),
      UserModel(
        name: 'Priya',
        role: 'Sound Op',
        permission: Permission.view,
        isConnected: true,
      ),
    ],
    cues: const [
      Cue(id: 1, label: 'Act 1 — Prologue', timecode: '00:00:30:00'),
      Cue(id: 2, label: 'Barricade Fly',    timecode: '00:45:20:00'),
      Cue(id: 3, label: 'Interval',         timecode: '01:20:00:00'),
    ],
  ),
];
