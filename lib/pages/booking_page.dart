import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/availability_exception.dart';
import '../models/booking_selection.dart';
import '../models/service.dart';
import '../models/weekly_availability.dart';
import '../services/availability_service.dart';
import '../services/calendar_service.dart';

class BookingPage extends StatefulWidget {
  final Service? service;
  final List<BookingSelection> selections;

  const BookingPage({super.key, this.service, this.selections = const []})
    : assert(
        service != null || selections.length > 0,
        'È necessario almeno un servizio.',
      );

  List<BookingSelection> get effectiveSelections {
    if (selections.isNotEmpty) {
      return selections;
    }

    if (service != null) {
      return [BookingSelection(service: service!)];
    }

    return const [];
  }

  int get totalDuration {
    return effectiveSelections.fold<int>(
      0,
      (total, selection) => total + selection.totalDuration,
    );
  }

  double get totalPrice {
    return effectiveSelections.fold<double>(
      0,
      (total, selection) => total + selection.totalPrice,
    );
  }

  String get serviceSummary {
    return effectiveSelections
        .map((selection) {
          final extras = selection.selectedExtras;

          if (extras.isEmpty) {
            return selection.service.name;
          }

          return [
            selection.service.name,
            ...extras.map((extra) => extra.name),
          ].join(' + ');
        })
        .join(' + ');
  }

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);

  static const Duration pendingHoldDuration = Duration(hours: 2);

  late DateTime selectedDay;
  late DateTime focusedDay;

  StreamSubscription<List<WeeklyAvailability>>? _availabilitySubscription;

  StreamSubscription<List<AvailabilityException>>? _exceptionsSubscription;

  Map<String, WeeklyAvailability> _weeklyAvailability = {};

  Map<String, AvailabilityException> _exceptionsByDate = {};

  bool _availabilityLoaded = false;
  bool _exceptionsLoaded = false;

  String selectedHour = '';
  List<String> blockedHours = [];

  bool isLoadingHours = false;
  bool isCreatingBooking = false;

  List<String> get hours => CalendarService.generateHours();

  int get totalDuration => widget.totalDuration;

  double get totalPrice => widget.totalPrice;

  List<BookingSelection> get selections => widget.effectiveSelections;

  AvailabilityException? _exceptionForDay(DateTime day) {
    final id = AvailabilityService.dateId(day);
    return _exceptionsByDate[id];
  }

  bool _isDateClosed(DateTime day) {
    final exception = _exceptionForDay(day);

    return exception != null &&
        exception.type == AvailabilityExceptionType.closed;
  }

  @override
  void initState() {
    super.initState();

    selectedDay = _normalizeDay(DateTime.now());
    focusedDay = selectedDay;

    _availabilitySubscription = AvailabilityService.watchWeeklyAvailability()
        .listen(
          (weeklyData) {
            if (!mounted) return;

            _weeklyAvailability = {
              for (final availability in weeklyData)
                availability.dayId: availability,
            };

            _availabilityLoaded = true;

            final firstAvailableDay = _firstSelectableDay(selectedDay);

            setState(() {
              selectedDay = firstAvailableDay;
              focusedDay = firstAvailableDay;
            });

            _loadBlockedHours(firstAvailableDay);
          },
          onError: (error) {
            debugPrint(
              'Errore caricamento disponibilità '
              'settimanale: $error',
            );
          },
        );

    _exceptionsSubscription = AvailabilityService.watchExceptions().listen(
      (exceptions) {
        if (!mounted) return;

        setState(() {
          _exceptionsByDate = {
            for (final exception in exceptions)
              AvailabilityService.dateId(exception.date): exception,
          };

          _exceptionsLoaded = true;
        });

        final availableDay = _firstSelectableDay(selectedDay);

        if (!isSameDay(availableDay, selectedDay)) {
          setState(() {
            selectedDay = availableDay;
            focusedDay = availableDay;
            selectedHour = '';
          });
        }

        _loadBlockedHours(selectedDay);
      },
      onError: (error) {
        debugPrint('Errore caricamento eccezioni: $error');
      },
    );
  }

  @override
  void dispose() {
    _availabilitySubscription?.cancel();
    _exceptionsSubscription?.cancel();
    super.dispose();
  }

  DateTime _normalizeDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  bool _isDayEnabled(DateTime day) {
    final normalizedDay = _normalizeDay(day);

    final today = _normalizeDay(DateTime.now());

    if (normalizedDay.isBefore(today)) {
      return false;
    }

    if (!_availabilityLoaded || !_exceptionsLoaded) {
      return false;
    }

    if (_isDateClosed(normalizedDay)) {
      return false;
    }

    final dayId = AvailabilityService.weekdayId(normalizedDay);

    final availability = _weeklyAvailability[dayId];

    if (availability == null) {
      return false;
    }

    return availability.enabled;
  }

  WeeklyAvailability? _availabilityForDay(DateTime day) {
    final dayId = AvailabilityService.weekdayId(day);

    return _weeklyAvailability[dayId];
  }

  int _timeToMinutes(String? value) {
    if (value == null || value.isEmpty) {
      return 0;
    }

    final parts = value.split(':');

    if (parts.length != 2) {
      return 0;
    }

    final hour = int.tryParse(parts[0]) ?? 0;

    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  int _dateTimeToMinutes(DateTime dateTime) {
    return dateTime.hour * 60 + dateTime.minute;
  }

  DateTime _firstSelectableDay(DateTime initialDay) {
    DateTime candidate = _normalizeDay(initialDay);

    for (int i = 0; i < 366; i++) {
      if (_isDayEnabled(candidate)) {
        return candidate;
      }

      candidate = candidate.add(const Duration(days: 1));
    }

    return _normalizeDay(initialDay);
  }

  DateTime _dateFromHour({required DateTime day, required String hour}) {
    final parts = hour.split(':');

    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime? _getPendingHoldUntil(Map<String, dynamic> data) {
    final holdUntilValue = data['holdUntil'];

    if (holdUntilValue is Timestamp) {
      return holdUntilValue.toDate();
    }

    final createdAtValue = data['createdAt'];

    if (createdAtValue is Timestamp) {
      return createdAtValue.toDate().add(pendingHoldDuration);
    }

    return null;
  }

  bool _appointmentBlocksTime(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';

    if (status == 'confirmed') {
      return true;
    }

    if (status == 'pending') {
      final holdUntil = _getPendingHoldUntil(data);

      return holdUntil != null && holdUntil.isAfter(DateTime.now());
    }

    return false;
  }

  Future<List<String>> _calculateBlockedHours(DateTime day) async {
    if (_isDateClosed(day)) {
      return List<String>.from(hours);
    }

    final availability = _availabilityForDay(day);

    if (availability == null || !availability.enabled) {
      return List<String>.from(hours);
    }

    final openingMinutes = _timeToMinutes(availability.startTime);

    final closingMinutes = _timeToMinutes(availability.endTime);

    final startDay = DateTime(day.year, day.month, day.day);

    final endDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where(
          'selectedDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDay),
        )
        .where(
          'selectedDateTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endDay),
        )
        .get();

    final List<String> blocked = [];
    final now = DateTime.now();

    for (final hour in hours) {
      final proposedStart = _dateFromHour(day: day, hour: hour);

      final proposedEnd = proposedStart.add(Duration(minutes: totalDuration));

      final proposedStartMinutes = _dateTimeToMinutes(proposedStart);

      final proposedEndMinutes = _dateTimeToMinutes(proposedEnd);

      if (proposedStartMinutes < openingMinutes ||
          proposedEndMinutes > closingMinutes) {
        blocked.add(hour);
        continue;
      }

      if (isSameDay(day, now) && proposedStart.isBefore(now)) {
        blocked.add(hour);
        continue;
      }

      for (final document in snapshot.docs) {
        final data = document.data();

        if (!_appointmentBlocksTime(data)) {
          continue;
        }

        final selectedDateTimeValue = data['selectedDateTime'];

        if (selectedDateTimeValue is! Timestamp) {
          continue;
        }

        final reservedStart = selectedDateTimeValue.toDate();

        DateTime reservedEnd;

        final blockedUntilValue = data['blockedUntil'];

        if (blockedUntilValue is Timestamp) {
          reservedEnd = blockedUntilValue.toDate();
        } else {
          final rawDuration = data['serviceDuration'];

          final duration = rawDuration is num
              ? rawDuration.toInt()
              : int.tryParse(rawDuration?.toString() ?? '') ?? 0;

          reservedEnd = reservedStart.add(Duration(minutes: duration));
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

    return blocked;
  }

  Future<void> _loadBlockedHours(DateTime day) async {
    setState(() {
      isLoadingHours = true;
      selectedHour = '';
    });

    try {
      final blocked = await _calculateBlockedHours(day);

      if (!mounted) return;

      setState(() {
        selectedDay = _normalizeDay(day);

        focusedDay = _normalizeDay(day);

        blockedHours = blocked;
        isLoadingHours = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        blockedHours = [];
        isLoadingHours = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante il caricamento '
            'degli orari: $error',
          ),
        ),
      );
    }
  }

  Future<void> _createBooking() async {
    if (selectedHour.isEmpty ||
        isCreatingBooking ||
        !_isDayEnabled(selectedDay)) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sessione scaduta. '
            'Effettua nuovamente il login.',
          ),
        ),
      );

      return;
    }

    final hourToBook = selectedHour;

    setState(() {
      isCreatingBooking = true;
    });

    try {
      final latestBlockedHours = await _calculateBlockedHours(selectedDay);

      if (!mounted) return;

      if (latestBlockedHours.contains(hourToBook)) {
        setState(() {
          blockedHours = latestBlockedHours;
          selectedHour = '';
          isCreatingBooking = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Questo orario non è più '
              'disponibile. '
              'Scegli un altro orario.',
            ),
          ),
        );

        return;
      }

      final userDocument = await FirebaseFirestore.instance
          .collection('utenti')
          .doc(user.uid)
          .get();

      final userData = userDocument.data() ?? {};

      final selectedDateTime = _dateFromHour(
        day: selectedDay,
        hour: hourToBook,
      );

      final now = DateTime.now();

      final holdUntil = now.add(pendingHoldDuration);

      final appointmentData = <String, dynamic>{
        'userId': user.uid,

        'clientName': userData['nome']?.toString() ?? '',

        'clientLastName': userData['cognome']?.toString() ?? '',

        'phone': userData['telefono']?.toString() ?? '',

        'email': userData['email']?.toString() ?? user.email ?? '',

        // Compatibilidad con todo el backend actual.
        'serviceName': widget.serviceSummary,

        'servicePrice': totalPrice,

        'serviceDuration': totalDuration,

        // Nueva estructura completa.
        'services': selections
            .map((selection) => selection.toFirestore())
            .toList(),

        'servicesCount': selections.length,

        'selectedDateTime': Timestamp.fromDate(selectedDateTime),

        'status': 'pending',

        'holdUntil': Timestamp.fromDate(holdUntil),

        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Prenotazione inviata! '
            '${selections.length} '
            '${selections.length == 1 ? 'servizio' : 'servizi'}, '
            '${_formatDuration(totalDuration)}. '
            'L’orario resterà riservato '
            'per 2 ore.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isCreatingBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante la '
            'prenotazione: $error',
          ),
        ),
      );
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) {
      return '$remaining min';
    }

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}min';
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Widget _buildBookingSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riepilogo prenotazione',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: dark,
            ),
          ),

          const SizedBox(height: 10),

          ...selections.map((selection) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${selection.service.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (selection.selectedExtras.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 3),
                      child: Text(
                        '+ ${selection.selectedExtras.map((extra) => extra.name).join(', ')}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          const Divider(),

          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDuration(totalDuration),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _formatPrice(totalPrice),
                style: const TextStyle(
                  color: gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prenotazione')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBookingSummary(),

              TableCalendar(
                firstDay: _normalizeDay(DateTime.now()),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: focusedDay,

                selectedDayPredicate: (day) {
                  return isSameDay(selectedDay, day);
                },

                enabledDayPredicate: _isDayEnabled,

                onDaySelected: (newSelectedDay, newFocusedDay) {
                  if (!_isDayEnabled(newSelectedDay)) {
                    return;
                  }

                  setState(() {
                    selectedDay = _normalizeDay(newSelectedDay);

                    focusedDay = _normalizeDay(newFocusedDay);

                    selectedHour = '';
                  });

                  _loadBlockedHours(newSelectedDay);
                },

                onPageChanged: (newFocusedDay) {
                  focusedDay = _normalizeDay(newFocusedDay);
                },

                calendarFormat: CalendarFormat.month,

                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mese',
                  CalendarFormat.twoWeeks: '2 settimane',
                  CalendarFormat.week: 'Settimana',
                },

                headerStyle: const HeaderStyle(
                  titleCentered: false,
                  formatButtonVisible: false,
                ),

                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: gold,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Color(0x66DDA33B),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Data selezionata: '
                '${selectedDay.day.toString().padLeft(2, '0')}/'
                '${selectedDay.month.toString().padLeft(2, '0')}/'
                '${selectedDay.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Seleziona orario '
                '(${_formatDuration(totalDuration)})',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (isLoadingHours)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: hours.map((hour) {
                      final isBlocked = blockedHours.contains(hour);

                      return ChoiceChip(
                        label: Text(hour),
                        selected: selectedHour == hour,
                        selectedColor: gold,
                        disabledColor: Colors.grey.shade300,
                        onSelected: isBlocked
                            ? null
                            : (selected) {
                                setState(() {
                                  selectedHour = selected ? hour : '';
                                });
                              },
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: dark,
                    foregroundColor: gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      selectedHour.isEmpty ||
                          isCreatingBooking ||
                          !_isDayEnabled(selectedDay)
                      ? null
                      : _createBooking,
                  child: isCreatingBooking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'CONFERMA PRENOTAZIONE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
