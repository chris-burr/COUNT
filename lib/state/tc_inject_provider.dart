import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/timecode/timecode.dart';
import 'providers.dart';

class TcInjectState {
  const TcInjectState({
    this.isRunning = false,
    this.frames = 0,
    this.framerate = 25,
    this.startHour = 1,
    this.startMinute = 0,
  });

  final bool isRunning;
  final int frames;
  final int framerate;
  final int startHour;
  final int startMinute;

  String get tcString => Timecode.framesToString(frames, framerate);

  TcInjectState copyWith({
    bool? isRunning,
    int? frames,
    int? framerate,
    int? startHour,
    int? startMinute,
  }) =>
      TcInjectState(
        isRunning: isRunning ?? this.isRunning,
        frames: frames ?? this.frames,
        framerate: framerate ?? this.framerate,
        startHour: startHour ?? this.startHour,
        startMinute: startMinute ?? this.startMinute,
      );
}

class TcInjectNotifier extends StateNotifier<TcInjectState> {
  TcInjectNotifier(this._ref) : super(const TcInjectState());

  final Ref _ref;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    final fr = state.framerate;
    final startFrames = (state.startHour * 3600 + state.startMinute * 60) * fr;
    state = state.copyWith(isRunning: true, frames: startFrames);
    _ref.read(timecodeProvider.notifier)
      ..setFramerate(fr)
      ..update(startFrames, isRunning: true);

    // Tick one frame at a time; Duration rounds to nearest ms.
    _timer = Timer.periodic(
      Duration(microseconds: (1000000 / fr).round()),
      (_) {
        final f = state.frames + 1;
        state = state.copyWith(frames: f);
        _ref
            .read(timecodeProvider.notifier)
            .update(f, isRunning: true);
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isRunning: false);
    _ref
        .read(timecodeProvider.notifier)
        .update(state.frames, isRunning: false);
  }

  void setStartHour(int h) => state = state.copyWith(startHour: h);
  void setStartMinute(int m) => state = state.copyWith(startMinute: m);
  void setFramerate(int fr) => state = state.copyWith(framerate: fr);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final tcInjectProvider =
    StateNotifierProvider<TcInjectNotifier, TcInjectState>(
        (ref) => TcInjectNotifier(ref));
