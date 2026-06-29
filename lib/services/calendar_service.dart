class CalendarService {
  static List<String> generateHours() {
    List<String> hours = [];

    int start = 7;
    int end = 20;

    for (int h = start; h < end; h++) {
      hours.add("${h.toString().padLeft(2, '0')}:00");
      hours.add("${h.toString().padLeft(2, '0')}:30");
    }

    return hours;
  }
}
