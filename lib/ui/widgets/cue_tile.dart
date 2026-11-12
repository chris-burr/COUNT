import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/cue.dart';
import '../../theme/app_theme.dart';
import 'countdown_chip.dart';

class CueTile extends StatelessWidget {
  const CueTile({
    super.key,
    required this.cue,
    required this.currentFrames,
    required this.framerate,
    this.currentShowTimeMs = 0,
    this.cueShowMs = 0,
    this.hasSegments = false,
    this.index,
    this.isNext = false,
    this.canEdit = false,
    this.onTap,
    this.onLongPress,
  });

  final Cue cue;
  final int currentFrames;
  final int framerate;
  final int currentShowTimeMs;

  /// Precomputed show-time position of this cue in ms.
  /// When [hasSegments] is true this is used for past/present comparisons so
  /// that the TC source framerate doesn't bleed into the cue list logic.
  final int cueShowMs;
  final bool hasSegments;

  final int? index;
  final bool isNext;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // When the session has segments, express everything in show-time-equivalent
    // frames so that CountdownChip comparisons stay framerate-agnostic.
    final int cueFrames;
    final int effectiveCurrentFrames;
    if (hasSegments) {
      cueFrames = (cueShowMs / 1000 * framerate).round();
      effectiveCurrentFrames = (currentShowTimeMs / 1000 * framerate).round();
    } else {
      cueFrames = cue.isTimecoded
          ? cue.toFrames(framerate)
          : (cue.showTimeSecs ?? 0) * framerate;
      effectiveCurrentFrames = cue.isTimecoded
          ? currentFrames
          : (currentShowTimeMs / 1000 * framerate).round();
    }

    final isPast = cueFrames < effectiveCurrentFrames;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isNext
              ? AppColors.surfaceHighlight
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNext
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.border,
            width: isNext ? 1.5 : 1,
          ),
          boxShadow: isNext
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Cue number
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${cue.id}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isNext
                            ? AppColors.primaryLight
                            : isPast
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Label + position
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cue.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isNext
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isPast
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            decoration:
                                isPast ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _PositionLabel(
                          cue: cue,
                          isPast: isPast,
                        ),
                      ],
                    ),
                  ),
                  // Countdown / past indicator
                  CountdownChip(
                    cueFrames: cueFrames,
                    currentFrames: effectiveCurrentFrames,
                    framerate: framerate,
                  ),
                  if (isNext) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows either the TC timecode or a show-time badge depending on cue type.
class _PositionLabel extends StatelessWidget {
  const _PositionLabel({required this.cue, required this.isPast});
  final Cue cue;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    if (cue.isTimecoded) {
      return Text(
        cue.timecode ?? '',
        style: GoogleFonts.spaceMono(
          fontSize: 11,
          color: isPast ? AppColors.textMuted : AppColors.textSecondary,
        ),
      );
    }

    // Show-time cue
    final secs = cue.showTimeSecs ?? 0;
    final h = secs ~/ 3600;
    final m = (secs ~/ 60).remainder(60).toString().padLeft(2, '0');
    final s = secs.remainder(60).toString().padLeft(2, '0');
    final label = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Text(
            'SHOW',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.warning,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 11,
            color: isPast ? AppColors.textMuted : AppColors.warning,
          ),
        ),
      ],
    );
  }
}
