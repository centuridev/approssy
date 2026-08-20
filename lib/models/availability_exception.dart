import 'package:cloud_firestore/cloud_firestore.dart';

import 'time_interval.dart';

enum AvailabilityExceptionType { closed, customHours }

class AvailabilityException {
  final String id;
  final DateTime date;
  final AvailabilityExceptionType type;
  final String reason;
  final String? startTime;
  final String? endTime;
  final List<TimeInterval> blockedIntervals;

  const AvailabilityException({
    required this.id,
    required this.date,
    required this.type,
    this.reason = '',
    this.startTime,
    this.endTime,
    this.blockedIntervals = const [],
  });

  bool get isClosed {
    return type == AvailabilityExceptionType.closed;
  }

  factory AvailabilityException.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final timestamp = data['date'];

    final rawIntervals = data['blockedIntervals'];

    final intervals = rawIntervals is List
        ? rawIntervals
              .whereType<Map>()
              .map(
                (item) => TimeInterval.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <TimeInterval>[];

    return AvailabilityException(
      id: id,
      date: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(id) ?? DateTime.now(),
      type: _typeFromString(data['type']?.toString()),
      reason: data['reason']?.toString() ?? '',
      startTime: data['startTime']?.toString(),
      endTime: data['endTime']?.toString(),
      blockedIntervals: intervals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'type': _typeToString(type),
      'reason': reason,
      'startTime': startTime,
      'endTime': endTime,
      'blockedIntervals': blockedIntervals
          .map((interval) => interval.toMap())
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static AvailabilityExceptionType _typeFromString(String? value) {
    switch (value) {
      case 'custom_hours':
        return AvailabilityExceptionType.customHours;
      case 'closed':
      default:
        return AvailabilityExceptionType.closed;
    }
  }

  static String _typeToString(AvailabilityExceptionType type) {
    switch (type) {
      case AvailabilityExceptionType.closed:
        return 'closed';
      case AvailabilityExceptionType.customHours:
        return 'custom_hours';
    }
  }
}
