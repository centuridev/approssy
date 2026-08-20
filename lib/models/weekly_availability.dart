import 'time_interval.dart';

class WeeklyAvailability {
  final String dayId;
  final bool enabled;
  final String? startTime;
  final String? endTime;
  final List<TimeInterval> breaks;

  const WeeklyAvailability({
    required this.dayId,
    required this.enabled,
    this.startTime,
    this.endTime,
    this.breaks = const [],
  });

  factory WeeklyAvailability.fromMap({
    required String dayId,
    required Map<String, dynamic> data,
  }) {
    final rawBreaks = data['breaks'];

    final breaks = rawBreaks is List
        ? rawBreaks
              .whereType<Map>()
              .map(
                (item) => TimeInterval.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <TimeInterval>[];

    return WeeklyAvailability(
      dayId: dayId,
      enabled: data['enabled'] == true,
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      breaks: breaks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'startTime': startTime,
      'endTime': endTime,
      'breaks': breaks.map((interval) => interval.toMap()).toList(),
    };
  }

  WeeklyAvailability copyWith({
    bool? enabled,
    String? startTime,
    String? endTime,
    List<TimeInterval>? breaks,
  }) {
    return WeeklyAvailability(
      dayId: dayId,
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breaks: breaks ?? this.breaks,
    );
  }
}
