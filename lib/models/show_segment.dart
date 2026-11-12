import 'package:flutter/foundation.dart';

enum ShowSegmentType { timecoded, freeRunning }

@immutable
class ShowSegment {
  const ShowSegment({
    required this.id,
    required this.label,
    required this.type,
    this.tcStart,
    this.tcEnd,
    this.estimatedDurationSecs = 0,
  });

  final String id;
  final String label;
  final ShowSegmentType type;

  /// "HH:MM:SS:FF" — only for timecoded segments.
  final String? tcStart;

  /// "HH:MM:SS:FF" — optional for timecoded; defines when this segment ends
  /// and the next begins. Used to record completed duration when TC drops.
  final String? tcEnd;

  /// Planning estimate for freeRunning segments (seconds).
  /// Replaced by actual wall-clock measurement once the segment completes.
  final int estimatedDurationSecs;

  bool get isTimecoded => type == ShowSegmentType.timecoded;
  bool get isFreeRunning => type == ShowSegmentType.freeRunning;

  factory ShowSegment.fromJson(Map<String, dynamic> json) => ShowSegment(
        id: json['id'] as String,
        label: json['label'] as String,
        type: json['type'] == 'timecoded'
            ? ShowSegmentType.timecoded
            : ShowSegmentType.freeRunning,
        tcStart: json['tc_start'] as String?,
        tcEnd: json['tc_end'] as String?,
        estimatedDurationSecs:
            json['estimated_duration_secs'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': isTimecoded ? 'timecoded' : 'free_running',
        if (tcStart != null) 'tc_start': tcStart,
        if (tcEnd != null) 'tc_end': tcEnd,
        'estimated_duration_secs': estimatedDurationSecs,
      };

  ShowSegment copyWith({
    String? id,
    String? label,
    ShowSegmentType? type,
    String? tcStart,
    String? tcEnd,
    int? estimatedDurationSecs,
  }) =>
      ShowSegment(
        id: id ?? this.id,
        label: label ?? this.label,
        type: type ?? this.type,
        tcStart: tcStart ?? this.tcStart,
        tcEnd: tcEnd ?? this.tcEnd,
        estimatedDurationSecs:
            estimatedDurationSecs ?? this.estimatedDurationSecs,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowSegment &&
          id == other.id &&
          label == other.label &&
          type == other.type &&
          tcStart == other.tcStart &&
          tcEnd == other.tcEnd &&
          estimatedDurationSecs == other.estimatedDurationSecs;

  @override
  int get hashCode =>
      Object.hash(id, label, type, tcStart, tcEnd, estimatedDurationSecs);
}
