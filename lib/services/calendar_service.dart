class CalendarService {
  static List<String> generateHours({int startHour = 7, int endHour = 20}) {
    final List<String> hours = [];

    for (int hour = startHour; hour < endHour; hour++) {
      hours.add('${hour.toString().padLeft(2, '0')}:00');

      hours.add('${hour.toString().padLeft(2, '0')}:30');
    }

    return hours;
  }

  static DateTime dateFromHour({required DateTime day, required String hour}) {
    final parts = hour.split(':');

    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static DateTime startOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  static DateTime endOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
  }

  static bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
