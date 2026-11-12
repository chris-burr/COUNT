import 'package:flutter/foundation.dart';

enum CueTriggerType { timecode, showTime }

@immutable
class Cue {
  const Cue({
    required this.id,
    required this.label,
    this.triggerType = CueTriggerType.timecode,
    this.timecode,
    this.showTimeSecs,
  });

  final int id;
  final String label;
  final CueTriggerType triggerType;

  /// "HH:MM:SS:FF" — present when triggerType == timecode.
  final String? timecode;

  /// Seconds from show start — present when triggerType == showTime.
  final int? showTimeSecs;

  bool get isTimecoded => triggerType == CueTriggerType.timecode;
  bool get isShowTime => triggerType == CueTriggerType.showTime;

  /// TC frames for this cue. Returns 0 for show-time cues.
  int toFrames(int framerate) {
    if (timecode == null) return 0;
    final parts = timecode!.split(':');
    if (parts.length != 4) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    final f = int.tryParse(parts[3]) ?? 0;
    return ((h * 3600 + m * 60 + s) * framerate) + f;
  }

  /// Show time in milliseconds, for unified sorting.
  /// TC cues: pass their show-time equivalent (computed externally).
  /// Show-time cues: (showTimeSecs ?? 0) * 1000.
  int showTimeMs() => (showTimeSecs ?? 0) * 1000;

  factory Cue.fromJson(Map<String, dynamic> json) {
    final typeStr = json['trigger_type'] as String? ?? 'timecode';
    final triggerType = typeStr == 'show_time'
        ? CueTriggerType.showTime
        : CueTriggerType.timecode;
    return Cue(
      id: json['id'] as int,
      label: json['label'] as String,
      triggerType: triggerType,
      timecode: json['timecode'] as String?,
      showTimeSecs: json['show_time_secs'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'trigger_type': isTimecoded ? 'timecode' : 'show_time',
        if (timecode != null) 'timecode': timecode,
        if (showTimeSecs != null) 'show_time_secs': showTimeSecs,
      };

  Cue copyWith({
    int? id,
    String? label,
    CueTriggerType? triggerType,
    String? timecode,
    int? showTimeSecs,
  }) =>
      Cue(
        id: id ?? this.id,
        label: label ?? this.label,
        triggerType: triggerType ?? this.triggerType,
        timecode: timecode ?? this.timecode,
        showTimeSecs: showTimeSecs ?? this.showTimeSecs,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cue &&
          id == other.id &&
          label == other.label &&
          triggerType == other.triggerType &&
          timecode == other.timecode &&
          showTimeSecs == other.showTimeSecs;

  @override
  int get hashCode =>
      Object.hash(id, label, triggerType, timecode, showTimeSecs);
}
