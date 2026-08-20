class TimeInterval {
  final String start;
  final String end;
  final String reason;

  const TimeInterval({
    required this.start,
    required this.end,
    this.reason = '',
  });

  factory TimeInterval.fromMap(Map<String, dynamic> data) {
    return TimeInterval(
      start: data['start']?.toString() ?? '',
      end: data['end']?.toString() ?? '',
      reason: data['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'start': start, 'end': end, 'reason': reason};
  }

  TimeInterval copyWith({String? start, String? end, String? reason}) {
    return TimeInterval(
      start: start ?? this.start,
      end: end ?? this.end,
      reason: reason ?? this.reason,
    );
  }
}
