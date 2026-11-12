import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart' show MidiDevice;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/timecode/timecode.dart';
import '../../models/cue.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../state/midi_provider.dart';
import '../../state/providers.dart';
import '../../state/tc_inject_provider.dart';
import '../../theme/app_theme.dart';
import '../screens/cue_editor_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/cue_tile.dart';
import '../widgets/timecode_display.dart';

const _kSidebarWidth = 260.0;

// ─── Root ─────────────────────────────────────────────────────────────────────

class MacShell extends ConsumerWidget {
  const MacShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    if (appState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (!appState.isOnboarded) return const _MacSetupView();
    return const _MacLayout();
  }
}

// ─── First-launch setup ───────────────────────────────────────────────────────

class _MacSetupView extends ConsumerStatefulWidget {
  const _MacSetupView();

  @override
  ConsumerState<_MacSetupView> createState() => _MacSetupViewState();
}

class _MacSetupViewState extends ConsumerState<_MacSetupView> {
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    await ref
        .read(appStateProvider.notifier)
        .saveProfile(_nameCtrl.text.trim(), _roleCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.textPrimary],
                ).createShader(b),
                child: const Text(
                  'COUNT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your profile to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              const _FieldLabel('YOUR NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration:
                    const InputDecoration(hintText: 'e.g. Sarah'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('YOUR ROLE'),
              const SizedBox(height: 8),
              TextField(
                controller: _roleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    hintText: 'e.g. Stage Manager'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Main split-pane layout ───────────────────────────────────────────────────

class _MacLayout extends StatelessWidget {
  const _MacLayout();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SizedBox(width: _kSidebarWidth, child: _MacSidebar()),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.divider,
          ),
          Expanded(child: _MacContentPanel()),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _MacSidebar extends ConsumerWidget {
  const _MacSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(discoveredSessionsProvider);
    final selected = ref.watch(currentSessionProvider);
    final appState = ref.watch(appStateProvider);

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(),
          const SizedBox(height: 8),
          _HostNewButton(onTap: () => _showHostDialog(context, ref)),
          const SizedBox(height: 16),
          _SidebarSectionLabel('NEARBY SESSIONS'),
          const SizedBox(height: 4),
          Expanded(
            child: sessions.isEmpty
                ? const _EmptySessions()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      return _SessionRow(
                        session: s,
                        isSelected: selected?.id == s.id,
                        onTap: () => ref
                            .read(currentSessionProvider.notifier)
                            .state = s,
                      );
                    },
                  ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          _SidebarUserFooter(
            name: appState.userName ?? '',
            role: appState.userRole ?? '',
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _showHostDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('New Session',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Give your session a name so other devices can find it.',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                  hintText: "e.g. Show A — Tuesday Night"),
              onSubmitted: (_) =>
                  _createSession(ctx, ref, nameCtrl.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(minimumSize: Size.zero),
            onPressed: () =>
                _createSession(ctx, ref, nameCtrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createSession(
      BuildContext ctx, WidgetRef ref, String name) {
    if (name.trim().isEmpty) return;
    Navigator.pop(ctx);
    final appState = ref.read(appStateProvider);
    ref.read(currentSessionProvider.notifier).state = SessionModel(
      id: 'host-local',
      name: name.trim(),
      framerate: 25,
      version: 1,
      masterDeviceId: 'this-device',
      users: [
        UserModel(
          name: appState.userName ?? 'Host',
          role: appState.userRole ?? '',
          permission: Permission.directEdit,
          isMaster: true,
          isConnected: true,
        ),
      ],
      cues: const [],
      created: DateTime.now(),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.textPrimary],
        ).createShader(b),
        child: const Text(
          'COUNT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HostNewButton extends StatelessWidget {
  const _HostNewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
        label: const Text('Host New Session'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surfaceElevated,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    required this.session,
    required this.isSelected,
    required this.onTap,
  });
  final SessionModel session;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final connected =
        widget.session.users.where((u) => u.isConnected).length;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : _hovered
                    ? AppColors.surfaceHighlight.withValues(alpha: 0.6)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.session.hostAddress != null
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: widget.isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.session.framerate}fps · $connected user${connected == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_find_rounded,
              size: 40,
              color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text(
            'No sessions found',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your WiFi connection',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SidebarUserFooter extends StatelessWidget {
  const _SidebarUserFooter({
    required this.name,
    required this.role,
    required this.onSettings,
  });
  final String name;
  final String role;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (role.isNotEmpty)
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Settings',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

// ─── Content panel ────────────────────────────────────────────────────────────

class _MacContentPanel extends ConsumerWidget {
  const _MacContentPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const _MacWelcomeView();
    return _MacCuePanel(session: session);
  }
}

class _MacWelcomeView extends StatelessWidget {
  const _MacWelcomeView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              size: 38,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select or host a session',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a session from the sidebar, or host a new one',
            style:
                TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Show-time position helper ────────────────────────────────────────────────

/// Converts a cue's position to show-time milliseconds for unified sorting.
/// For TC cues, traverses the session's segment map to find the equivalent
/// show time. For show-time cues, converts directly from showTimeSecs.
int _cueShowMs(Cue cue, SessionModel session) {
  if (cue.isShowTime) return (cue.showTimeSecs ?? 0) * 1000;
  if (!session.hasSegments) {
    return (cue.toFrames(session.framerate) / session.framerate * 1000).round();
  }
  final frames = cue.toFrames(session.framerate);
  final fr = session.framerate;
  int accumulated = 0;
  for (final seg in session.segments) {
    if (seg.isFreeRunning) {
      accumulated += seg.estimatedDurationSecs * 1000;
      continue;
    }
    if (seg.tcStart == null) continue;
    final segStart = Timecode.stringToFrames(seg.tcStart!, fr);
    final segEnd = seg.tcEnd != null
        ? Timecode.stringToFrames(seg.tcEnd!, fr)
        : segStart + fr * 3600 * 24;
    if (frames >= segStart && frames < segEnd) {
      return accumulated + ((frames - segStart) / fr * 1000).round();
    }
    accumulated += ((segEnd - segStart) / fr * 1000).round();
  }
  // Fallback: cue is outside defined segments
  return (frames / fr * 1000).round();
}

// ─── Cue panel ────────────────────────────────────────────────────────────────

class _MacCuePanel extends ConsumerWidget {
  const _MacCuePanel({required this.session});
  final SessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(timecodeProvider);
    final showTime = ref.watch(showTimeProvider);
    final appState = ref.watch(appStateProvider);

    final currentUser = session.users.firstWhere(
      (u) => u.name == appState.userName,
      orElse: () => const UserModel(
          name: '', role: '', permission: Permission.view),
    );
    final canEdit = currentUser.isMaster ||
        currentUser.permission == Permission.directEdit ||
        currentUser.permission == Permission.propose;

    // Sort cues by show-time position so TC and show-time cues interleave.
    final sortedCues = List<Cue>.from(session.cues)
      ..sort((a, b) =>
          _cueShowMs(a, session).compareTo(_cueShowMs(b, session)));

    // Normalise TC frames into session-framerate space. This keeps cue
    // comparisons correct even when the TC source (injector/MIDI) runs at a
    // different rate than the session (e.g. 30fps source vs 25fps session).
    final normalizedFrames =
        (tc.frames / tc.framerate * session.framerate).round();

    // "Next" = first cue whose show-time position is ahead of now.
    final nowMs = session.hasSegments ? showTime.elapsedMs : null;
    final nextCueIndex = sortedCues.indexWhere((c) {
      if (session.hasSegments && nowMs != null) {
        return _cueShowMs(c, session) > nowMs;
      }
      // Fallback for sessions without segments: compare in session-framerate space.
      return c.isTimecoded && c.toFrames(session.framerate) > normalizedFrames;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MacSessionBar(session: session),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: _MacShowTimeHeader(
            tc: tc,
            showTime: showTime,
            framerate: session.framerate,
          ),
        ),
        if (nextCueIndex >= 0)
          _MacNextCue(
            cue: sortedCues[nextCueIndex],
            cueShowMs: _cueShowMs(sortedCues[nextCueIndex], session),
            currentFrames: normalizedFrames,
            currentShowTimeMs: showTime.elapsedMs,
            framerate: session.framerate,
            hasSegments: session.hasSegments,
          ),
        _MacCueListHeader(
          count: sortedCues.length,
          canEdit: canEdit,
          onAdd: () => _showCueEditor(context, ref, session, null, (cue) {
            ref.read(currentSessionProvider.notifier).state =
                session.copyWith(
              cues: [...session.cues, cue],
              version: session.version + 1,
            );
          }),
        ),
        Expanded(
          child: sortedCues.isEmpty
              ? _MacEmptyCueList(canEdit: canEdit)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: sortedCues.length,
                  itemBuilder: (_, i) {
                    final cue = sortedCues[i];
                    return CueTile(
                      cue: cue,
                      currentFrames: normalizedFrames,
                      currentShowTimeMs: showTime.elapsedMs,
                      cueShowMs: _cueShowMs(cue, session),
                      hasSegments: session.hasSegments,
                      framerate: session.framerate,
                      isNext: i == nextCueIndex,
                      canEdit: canEdit,
                      onTap: canEdit
                          ? () => _showCueEditor(context, ref, session,
                                  cue, (updated) {
                                final newCues = session.cues
                                    .map((c) =>
                                        c.id == cue.id ? updated : c)
                                    .toList();
                                ref
                                    .read(currentSessionProvider.notifier)
                                    .state = session.copyWith(
                                  cues: newCues,
                                  version: session.version + 1,
                                );
                              })
                          : null,
                      onLongPress: canEdit
                          ? () => _confirmDelete(
                              context, ref, session, cue)
                          : null,
                    );
                  },
                ),
        ),
        const _MacDebugBar(),
      ],
    );
  }

  void _showCueEditor(
    BuildContext context,
    WidgetRef ref,
    SessionModel session,
    Cue? existing,
    void Function(Cue) onSave,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 480,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CueEditorScreen(
              session: session,
              existingCue: existing,
              onSave: onSave,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SessionModel session,
    Cue cue,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Cue?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${cue.label}" will be removed from the cue list.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final newCues =
                  session.cues.where((c) => c.id != cue.id).toList();
              ref.read(currentSessionProvider.notifier).state =
                  session.copyWith(
                      cues: newCues, version: session.version + 1);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Session toolbar ──────────────────────────────────────────────────────────

class _MacSessionBar extends ConsumerWidget {
  const _MacSessionBar({required this.session});
  final SessionModel session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = session.users.where((u) => u.isConnected).length;
    final showTime = ref.watch(showTimeProvider);
    final showNotifier = ref.read(showTimeProvider.notifier);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Stop free-running — shown only while interval/free-run clock is ticking
          if (showTime.isFreeRunning) ...[
            _SessionBarButton(
              icon: Icons.pause_rounded,
              label: 'STOP INTERVAL',
              color: AppColors.warning,
              onTap: showNotifier.stopFreeRunning,
            ),
            const SizedBox(width: 8),
          ],
          // Reset show — shown once the show has started
          if (showTime.hasSegments && showTime.elapsedMs > 0) ...[
            _SessionBarButton(
              icon: Icons.replay_rounded,
              label: 'RESET SHOW',
              color: AppColors.textMuted,
              onTap: () => _confirmReset(context, showNotifier),
            ),
            const SizedBox(width: 16),
          ],
          _StatusDot(isConnected: session.hostAddress != null),
          const SizedBox(width: 6),
          Text(
            session.hostAddress ?? 'local',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.people_outline,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            '$connected',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'v${session.version}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, ShowTimeNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Show Time?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This resets the show clock back to zero. '
          'All elapsed segment times will be cleared.',
          style:
              TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.reset();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SessionBarButton extends StatelessWidget {
  const _SessionBarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConnected ? AppColors.success : AppColors.textMuted,
        boxShadow: isConnected
            ? [
                BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.5),
                    blurRadius: 5)
              ]
            : null,
      ),
    );
  }
}

// ─── Show time header (primary display) ──────────────────────────────────────

class _MacShowTimeHeader extends StatelessWidget {
  const _MacShowTimeHeader({
    required this.tc,
    required this.showTime,
    required this.framerate,
  });
  final TimecodeState tc;
  final ShowTimeState showTime;
  final int framerate;

  @override
  Widget build(BuildContext context) {
    if (!showTime.hasSegments) {
      // No segments defined — fall back to the original TC-only display.
      return TimecodeDisplay(
        frames: tc.frames,
        framerate: framerate,
        isRunning: tc.isRunning,
      );
    }

    final tcString = Timecode.framesToString(tc.frames, framerate);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: showTime.isRunning
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.border,
          width: showTime.isRunning ? 1.5 : 1,
        ),
        boxShadow: showTime.isRunning
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show time — primary
          Text(
            showTime.formatted,
            style: GoogleFonts.spaceMono(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: showTime.isRunning
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          // Segment + TC row — secondary
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segment badge
              if (showTime.segmentName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: showTime.isFreeRunning
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: showTime.isFreeRunning
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    showTime.segmentName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: showTime.isFreeRunning
                          ? AppColors.warning
                          : AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Status dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: showTime.isFreeRunning
                      ? AppColors.warning
                      : tc.isRunning
                          ? AppColors.success
                          : AppColors.textMuted,
                  boxShadow: showTime.isRunning
                      ? [
                          BoxShadow(
                            color: (showTime.isFreeRunning
                                    ? AppColors.warning
                                    : AppColors.success)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 7),
              // Status label + TC
              Text(
                showTime.isFreeRunning
                    ? 'FREE RUNNING'
                    : tc.isRunning
                        ? 'TC  $tcString'
                        : 'STOPPED',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: showTime.isFreeRunning
                      ? AppColors.warning
                      : tc.isRunning
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Next cue bar ─────────────────────────────────────────────────────────────

class _MacNextCue extends StatelessWidget {
  const _MacNextCue({
    required this.cue,
    required this.cueShowMs,
    required this.currentFrames,
    required this.currentShowTimeMs,
    required this.framerate,
    required this.hasSegments,
  });
  final Cue cue;

  /// Precomputed show-time position of this cue in ms (from [_cueShowMs]).
  final int cueShowMs;

  final int currentFrames;
  final int currentShowTimeMs;
  final int framerate;
  final bool hasSegments;

  @override
  Widget build(BuildContext context) {
    // Compute countdown: for show-time cues use show time delta; for TC cues
    // use TC delta when no segments, or show-time delta when segments exist.
    final String countdown;
    if (hasSegments) {
      // Use show-time ms for all cues — avoids framerate mismatch between TC
      // source (which may differ from session framerate) and cue positions.
      final deltaSecs = (cueShowMs - currentShowTimeMs) ~/ 1000;
      countdown = _formatSecsDelta(deltaSecs);
    } else {
      final deltaFrames = cue.toFrames(framerate) - currentFrames;
      countdown = Timecode.formatCountdown(deltaFrames, framerate);
    }

    final positionLabel = cue.isTimecoded
        ? (cue.timecode ?? '')
        : _formatShowSecs(cue.showTimeSecs ?? 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.keyboard_double_arrow_right_rounded,
                size: 16, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            const Text(
              'NEXT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cue.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              positionLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'in $countdown',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSecsDelta(int secs) {
    final abs = secs.abs();
    final sign = secs >= 0 ? '-' : '+';
    final m = abs ~/ 60;
    final s = (abs % 60).toString().padLeft(2, '0');
    if (m > 0) return '$sign${m}m ${s}s';
    return '$sign${abs}s';
  }

  static String _formatShowSecs(int secs) {
    final h = secs ~/ 3600;
    final m = (secs ~/ 60).remainder(60).toString().padLeft(2, '0');
    final s = secs.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Cue list header ──────────────────────────────────────────────────────────

class _MacCueListHeader extends StatelessWidget {
  const _MacCueListHeader({
    required this.count,
    required this.canEdit,
    required this.onAdd,
  });
  final int count;
  final bool canEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.queue_outlined,
              size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          const Text(
            'CUE LIST',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count ${count == 1 ? 'cue' : 'cues'}',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted),
            ),
          ),
          const Spacer(),
          if (canEdit)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Cue'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacEmptyCueList extends StatelessWidget {
  const _MacEmptyCueList({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_outlined,
              size: 52,
              color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'No cues yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            const Text(
              'Click “Add Cue” above to get started',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.textMuted,
      ),
    );
  }
}

// ─── Debug bar ────────────────────────────────────────────────────────────────

class _MacDebugBar extends ConsumerStatefulWidget {
  const _MacDebugBar();

  @override
  ConsumerState<_MacDebugBar> createState() => _MacDebugBarState();
}

class _MacDebugBarState extends ConsumerState<_MacDebugBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D14),
          border: Border(top: BorderSide(color: Color(0xFF2A1A3E), width: 1)),
        ),
        child: _expanded ? _buildExpanded() : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    final inject = ref.watch(tcInjectProvider);
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.bug_report_outlined,
                size: 12, color: Color(0xFF7B5EA7)),
            const SizedBox(width: 6),
            const Text(
              'DEBUG',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Color(0xFF7B5EA7),
              ),
            ),
            const SizedBox(width: 12),
            if (inject.isRunning) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'TC ${inject.tcString}',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else
              const Text(
                'TC INJECT IDLE',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            const Spacer(),
            const Icon(Icons.expand_less_rounded,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final inject = ref.watch(tcInjectProvider);
    final midi = ref.watch(midiProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.bug_report_outlined,
                  size: 12, color: Color(0xFF7B5EA7)),
              const SizedBox(width: 6),
              const Text(
                'DEBUG',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Color(0xFF7B5EA7),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: const Icon(Icons.expand_more_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // TC Inject + MIDI in one row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── TC Inject section ──
              const Text(
                'TC INJECT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              // Framerate picker
              _DebugDropdown<int>(
                value: inject.framerate,
                items: const [24, 25, 30],
                label: (v) => '${v}fps',
                onChanged: inject.isRunning
                    ? null
                    : (v) => ref
                        .read(tcInjectProvider.notifier)
                        .setFramerate(v!),
              ),
              const SizedBox(width: 6),
              // Start hour picker
              _DebugDropdown<int>(
                value: inject.startHour,
                items: List.generate(24, (i) => i),
                label: (v) => '${v.toString().padLeft(2, '0')}h',
                onChanged: inject.isRunning
                    ? null
                    : (v) => ref
                        .read(tcInjectProvider.notifier)
                        .setStartHour(v!),
              ),
              const SizedBox(width: 4),
              // Start minute picker
              _DebugDropdown<int>(
                value: inject.startMinute,
                items: List.generate(60, (i) => i),
                label: (v) => '${v.toString().padLeft(2, '0')}m',
                onChanged: inject.isRunning
                    ? null
                    : (v) => ref
                        .read(tcInjectProvider.notifier)
                        .setStartMinute(v!),
              ),
              const SizedBox(width: 8),
              // Play / Stop
              _DebugButton(
                label: inject.isRunning ? '■  STOP' : '▶  RUN',
                active: inject.isRunning,
                onTap: inject.isRunning
                    ? () => ref.read(tcInjectProvider.notifier).stop()
                    : () => ref.read(tcInjectProvider.notifier).start(),
              ),
              const SizedBox(width: 6),
              _DebugButton(
                label: '↺ RESET',
                onTap: () {
                  ref.read(tcInjectProvider.notifier).stop();
                  ref.read(showTimeProvider.notifier).reset();
                },
              ),
              if (inject.isRunning) ...[
                const SizedBox(width: 10),
                Text(
                  inject.tcString,
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(width: 20),
              // ── MIDI section ──
              const Text(
                'MIDI IN',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              _DebugButton(
                label: midi.isScanning ? '…' : 'SCAN',
                onTap: midi.isScanning
                    ? null
                    : () => ref.read(midiProvider.notifier).scan(),
              ),
              if (midi.devices.isNotEmpty) ...[
                const SizedBox(width: 6),
                _DebugDropdown<MidiDevice>(
                  value: midi.selectedDevice,
                  items: midi.devices,
                  label: (d) => d.name,
                  onChanged: midi.isConnected
                      ? null
                      : (d) {
                          if (d != null) {
                            ref
                                .read(midiProvider.notifier)
                                .selectDevice(d.id);
                          }
                        },
                ),
                const SizedBox(width: 6),
                _DebugButton(
                  label: midi.isConnected ? '⏹ DISC' : '⇌ CONN',
                  active: midi.isConnected,
                  onTap: midi.selectedDevice == null
                      ? null
                      : midi.isConnected
                          ? () => ref.read(midiProvider.notifier).disconnect()
                          : () => ref.read(midiProvider.notifier).connect(),
                ),
              ],
              if (midi.isConnected) ...[
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  midi.lastTcString != null ? 'MTC ${midi.lastTcString}' : 'LIVE — waiting',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: midi.lastTcString != null
                        ? AppColors.success.withValues(alpha: 0.9)
                        : AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  const _DebugButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? AppColors.success.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: onTap == null
                ? AppColors.textMuted
                : active
                    ? AppColors.success
                    : AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DebugDropdown<T> extends StatelessWidget {
  const _DebugDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T? value;
  final List<T> items;
  final String Function(T) label;
  final void Function(T?)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          onChanged: onChanged,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(label(item)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
