import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  static Future<List<String>> getUnavailableHours(DateTime day) async {
    List<String> blocked = [];
    try {
      final startOfDay = Timestamp.fromDate(
        DateTime(day.year, day.month, day.day),
      );
      final endOfDay = Timestamp.fromDate(
        DateTime(day.year, day.month, day.day + 1),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('selectedDateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('selectedDateTime', isLessThan: endOfDay)
          .where('status', isEqualTo: 'confirmed')
          .get();

      for (var doc in snapshot.docs) {
        final selectedDateTime = (doc['selectedDateTime'] as Timestamp).toDate();
        String start = '${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}';
        int duration = doc['serviceDuration'] ?? 0;

        final blockedSlots = calculateSlots(start, duration);
        blocked.addAll(blockedSlots);
      }
    } catch (e) {
      // Handle missing index or other errors: return empty (no hours blocked)
      print('getUnavailableHours error for $day: $e');
      blocked = [];
    }
    return blocked;
  }

  static List<String> calculateSlots(String startHour, int duration) {
    List<String> slots = [];

    int totalSlots = (duration / 30).ceil();

    List<String> parts = startHour.split(":");

    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    DateTime time = DateTime(2025, 1, 1, hour, minute);

    for (int i = 0; i < totalSlots; i++) {
      String formatted =
          "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

      slots.add(formatted);

      time = time.add(const Duration(minutes: 30));
    }

    return slots;
  }
}
