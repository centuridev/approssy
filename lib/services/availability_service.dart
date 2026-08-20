import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/availability_exception.dart';
import '../models/weekly_availability.dart';

class AvailabilityService {
  AvailabilityService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String weeklyCollection = 'weekly_availability';

  static const String exceptionsCollection = 'availability_exceptions';

  static const List<String> dayIds = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static String dateId(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String weekdayId(DateTime date) {
    return dayIds[date.weekday - 1];
  }

  static Stream<List<WeeklyAvailability>> watchWeeklyAvailability() {
    return _firestore.collection(weeklyCollection).snapshots().map((snapshot) {
      final dataById = {
        for (final document in snapshot.docs) document.id: document.data(),
      };

      return dayIds.map((dayId) {
        final data = dataById[dayId];

        if (data == null) {
          return defaultForDay(dayId);
        }

        return WeeklyAvailability.fromMap(dayId: dayId, data: data);
      }).toList();
    });
  }

  static Future<WeeklyAvailability> getWeeklyAvailabilityForDate(
    DateTime date,
  ) async {
    final dayId = weekdayId(date);

    final document = await _firestore
        .collection(weeklyCollection)
        .doc(dayId)
        .get();

    if (!document.exists || document.data() == null) {
      return defaultForDay(dayId);
    }

    return WeeklyAvailability.fromMap(dayId: dayId, data: document.data()!);
  }

  static Future<void> saveWeeklyAvailability(
    WeeklyAvailability availability,
  ) async {
    await _firestore
        .collection(weeklyCollection)
        .doc(availability.dayId)
        .set(availability.toMap(), SetOptions(merge: true));
  }

  static Stream<List<AvailabilityException>> watchExceptions() {
    return _firestore
        .collection(exceptionsCollection)
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => AvailabilityException.fromMap(
                  id: document.id,
                  data: document.data(),
                ),
              )
              .toList(),
        );
  }

  static Future<AvailabilityException?> getException(DateTime date) async {
    final id = dateId(date);

    final document = await _firestore
        .collection(exceptionsCollection)
        .doc(id)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return AvailabilityException.fromMap(
      id: document.id,
      data: document.data()!,
    );
  }

  static Future<void> saveException(AvailabilityException exception) async {
    final id = dateId(exception.date);

    await _firestore
        .collection(exceptionsCollection)
        .doc(id)
        .set(exception.toMap(), SetOptions(merge: true));
  }

  static Future<void> deleteException(DateTime date) async {
    await _firestore
        .collection(exceptionsCollection)
        .doc(dateId(date))
        .delete();
  }

  static WeeklyAvailability defaultForDay(String dayId) {
    final isSunday = dayId == 'sunday';

    return WeeklyAvailability(
      dayId: dayId,
      enabled: !isSunday,
      startTime: isSunday ? null : '09:00',
      endTime: isSunday ? null : '20:00',
      breaks: const [],
    );
  }

  static Future<void> createDefaultWeek() async {
    final batch = _firestore.batch();

    for (final dayId in dayIds) {
      final reference = _firestore.collection(weeklyCollection).doc(dayId);

      batch.set(
        reference,
        defaultForDay(dayId).toMap(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
