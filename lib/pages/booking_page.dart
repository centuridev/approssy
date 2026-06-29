import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingPage extends StatefulWidget {
  final Service service;

  const BookingPage({super.key, required this.service});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime selectedDay = DateTime.now();
  String selectedHour = "";
  List<String> blockedHours = [];

  List<String> generateHours() {
    List<String> hours = [];

    int start = 7;
    int end = 20;

    for (int h = start; h < end; h++) {
      hours.add("${h.toString().padLeft(2, '0')}:00");
      hours.add("${h.toString().padLeft(2, '0')}:30");
    }

    return hours;
  }

  @override
  void initState() {
    super.initState();
    _loadBlockedHours(selectedDay);
  }

  Future<void> _loadBlockedHours(DateTime day) async {
    final startDay = DateTime(day.year, day.month, day.day, 0, 0);
    final endDay = DateTime(day.year, day.month, day.day, 23, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'confirmed')
        .where(
          'selectedDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDay),
        )
        .where(
          'selectedDateTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endDay),
        )
        .get();

    final allHours = generateHours();
    final List<String> blocked = [];

    for (final hour in allHours) {
      final proposedStart = DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(hour.split(':')[0]),
        int.parse(hour.split(':')[1]),
      );

      final proposedEnd = proposedStart.add(
        Duration(minutes: widget.service.duration),
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final reservedStart = (data['selectedDateTime'] as Timestamp).toDate();

        DateTime reservedEnd;

        if (data['blockedUntil'] != null) {
          reservedEnd = (data['blockedUntil'] as Timestamp).toDate();
        } else {
          reservedEnd = reservedStart.add(
            Duration(minutes: data['serviceDuration'] ?? 0),
          );
        }

        final hasConflict =
            proposedStart.isBefore(reservedEnd) &&
            proposedEnd.isAfter(reservedStart);

        if (hasConflict) {
          blocked.add(hour);
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        selectedDay = day;
        selectedHour = "";
        blockedHours = blocked;
      });
    }
  }

  Future createBooking() async {
    final user = FirebaseAuth.instance.currentUser;

    final userData = await FirebaseFirestore.instance
        .collection('utenti')
        .doc(user!.uid)
        .get();

    final selectedDateTime = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      int.parse(selectedHour.split(':')[0]),
      int.parse(selectedHour.split(':')[1]),
    );

    final appointmentData = {
      'userId': user.uid,
      'clientName': userData['nome'] ?? '',
      'clientLastName': userData['cognome'] ?? '',
      'phone': userData['telefono'] ?? '',
      'email': userData['email'] ?? user.email ?? '',
      'serviceName': widget.service.name,
      'servicePrice': widget.service.price,
      'serviceDuration': widget.service.duration,
      'selectedDateTime': Timestamp.fromDate(selectedDateTime),
      'status': 'pending',
      'createdAt': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('appointments')
        .add(appointmentData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Prenotazione inviata! Rodika sarà notificata."),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hours = generateHours();

    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime(2030),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) {
              return isSameDay(selectedDay, day);
            },
            onDaySelected: (selected, focused) {
              _loadBlockedHours(selected);
            },
            enabledDayPredicate: (day) {
              if (day.weekday == DateTime.saturday) {
                return false;
              }
              return true;
            },
          ),

          const SizedBox(height: 20),

          const Text(
            "Seleziona orario",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: hours.map((hour) {
                  final isBlocked = blockedHours.contains(hour);

                  return ChoiceChip(
                    label: Text(hour),
                    selected: selectedHour == hour,
                    disabledColor: Colors.grey.shade300,
                    selectedColor: const Color(0xFFDDA33B),
                    onSelected: isBlocked
                        ? null
                        : (val) {
                            setState(() {
                              selectedHour = hour;
                            });
                          },
                  );
                }).toList(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: selectedHour.isEmpty ? null : createBooking,
              child: const Text(
                "Conferma prenotazione",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
