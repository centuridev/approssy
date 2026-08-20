import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/availability_exception.dart';
import '../services/availability_service.dart';

class AvailabilityExceptionsPage extends StatefulWidget {
  const AvailabilityExceptionsPage({super.key});

  @override
  State<AvailabilityExceptionsPage> createState() =>
      _AvailabilityExceptionsPageState();
}

class _AvailabilityExceptionsPageState
    extends State<AvailabilityExceptionsPage> {
  static const Color gold = Color(0xFFDDA33B);

  late DateTime _focusedDay;

  final Set<String> _selectedDateIds = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _focusedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateId(DateTime date) {
    return AvailabilityService.dateId(_normalizeDay(date));
  }

  DateTime _dateFromId(String id) {
    return DateTime.parse(id);
  }

  bool _isSelected(DateTime day) {
    return _selectedDateIds.contains(_dateId(day));
  }

  void _toggleSelectedDay(DateTime day) {
    final normalizedDay = _normalizeDay(day);
    final today = _normalizeDay(DateTime.now());

    if (normalizedDay.isBefore(today)) {
      return;
    }

    final id = _dateId(normalizedDay);

    setState(() {
      if (_selectedDateIds.contains(id)) {
        _selectedDateIds.remove(id);
      } else {
        _selectedDateIds.add(id);
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatSelectedDates() {
    final dates = _selectedDateIds.map(_dateFromId).toList()..sort();

    return dates.map(_formatDate).join(', ');
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();

    String selectedReason = 'Festività';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Chiudi le date selezionate'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 5),

                    Text(_formatSelectedDates()),

                    const SizedBox(height: 18),

                    const Text(
                      'Motivo della chiusura',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Festività',
                          child: Text('Festività'),
                        ),
                        DropdownMenuItem(value: 'Ferie', child: Text('Ferie')),
                        DropdownMenuItem(
                          value: 'Malattia',
                          child: Text('Malattia'),
                        ),
                        DropdownMenuItem(
                          value: 'Impegno personale',
                          child: Text('Impegno personale'),
                        ),
                        DropdownMenuItem(value: 'Altro', child: Text('Altro')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedReason = value;
                        });
                      },
                    ),

                    if (selectedReason == 'Altro') ...[
                      const SizedBox(height: 14),

                      TextField(
                        controller: controller,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione del motivo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('ANNULLA'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: gold,
                  ),
                  onPressed: () {
                    final reason = selectedReason == 'Altro'
                        ? controller.text.trim()
                        : selectedReason;

                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Inserisci il motivo.')),
                      );

                      return;
                    }

                    Navigator.of(dialogContext).pop(reason);
                  },
                  child: const Text('CONFERMA'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> _saveClosedDates() async {
    if (_selectedDateIds.isEmpty || _isSaving) {
      return;
    }

    final reason = await _askReason();

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedDates = _selectedDateIds.map(_dateFromId).toList();

      for (final date in selectedDates) {
        final exception = AvailabilityException(
          id: AvailabilityService.dateId(date),
          date: date,
          type: AvailabilityExceptionType.closed,
          reason: reason,
          blockedIntervals: const [],
        );

        await AvailabilityService.saveException(exception);
      }

      if (!mounted) return;

      setState(() {
        _selectedDateIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedDates.length == 1
                ? 'Giorno chiuso correttamente.'
                : '${selectedDates.length} giorni chiusi correttamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteException(AvailabilityException exception) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Riaprire questo giorno?'),
          content: Text(
            '${_formatDate(exception.date)}\n\n'
            'Il giorno tornerà a utilizzare '
            'l’orario settimanale abituale.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('ANNULLA'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'RIAPRI',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await AvailabilityService.deleteException(exception.date);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Eccezione eliminata. '
            'Il giorno è nuovamente disponibile.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l’eliminazione: $error')),
      );
    }
  }

  Widget _buildCalendar(Map<String, AvailabilityException> exceptionsByDate) {
    final today = _normalizeDay(DateTime.now());

    return TableCalendar<void>(
      firstDay: today,
      lastDay: DateTime(2030, 12, 31),
      focusedDay: _focusedDay,

      selectedDayPredicate: _isSelected,

      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },

      onDaySelected: (selectedDay, focusedDay) {
        final id = _dateId(selectedDay);

        if (exceptionsByDate.containsKey(id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Questa data è già configurata. '
                'Elimina prima l’eccezione esistente.',
              ),
            ),
          );

          return;
        }

        setState(() {
          _focusedDay = focusedDay;
        });

        _toggleSelectedDay(selectedDay);
      },

      enabledDayPredicate: (day) {
        return !_normalizeDay(day).isBefore(today);
      },

      calendarFormat: CalendarFormat.month,

      availableCalendarFormats: const {CalendarFormat.month: 'Mese'},

      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
      ),

      calendarStyle: const CalendarStyle(
        selectedDecoration: BoxDecoration(color: gold, shape: BoxShape.circle),
        selectedTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        todayDecoration: BoxDecoration(
          color: Color(0x55DDA33B),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),

      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final exception = exceptionsByDate[_dateId(day)];

          if (exception == null) {
            return null;
          }

          return _ClosedDayCell(day: day);
        },

        todayBuilder: (context, day, focusedDay) {
          final exception = exceptionsByDate[_dateId(day)];

          if (exception != null) {
            return _ClosedDayCell(day: day);
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Festività e orari speciali')),
      body: StreamBuilder<List<AvailabilityException>>(
        stream: AvailabilityService.watchExceptions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Errore durante il caricamento: '
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final exceptions = snapshot.data ?? const <AvailabilityException>[];

          final exceptionsByDate = {
            for (final exception in exceptions)
              AvailabilityService.dateId(exception.date): exception,
          };

          final sortedExceptions = List<AvailabilityException>.from(exceptions)
            ..sort((first, second) => first.date.compareTo(second.date));

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
                  children: [
                    Card(
                      elevation: 0,
                      color: gold.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: gold),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Tocca una o più date per '
                          'selezionarle. Queste date saranno '
                          'chiuse solo nel giorno indicato '
                          'e non influenzeranno le altre '
                          'settimane.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildCalendar(exceptionsByDate),

                    if (_selectedDateIds.isNotEmpty) ...[
                      const SizedBox(height: 12),

                      Card(
                        color: gold.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDateIds.length == 1
                                    ? '1 data selezionata'
                                    : '${_selectedDateIds.length} '
                                          'date selezionate',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(_formatSelectedDates()),

                              const SizedBox(height: 10),

                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedDateIds.clear();
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('ANNULLA SELEZIONE'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    const Text(
                      'Chiusure programmate',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (sortedExceptions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(Icons.event_available, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Non ci sono chiusure '
                                  'programmate.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...sortedExceptions.map((exception) {
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x22DDA33B),
                              child: Icon(Icons.event_busy, color: gold),
                            ),
                            title: Text(
                              _formatDate(exception.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              exception.reason.isEmpty
                                  ? 'Giorno chiuso'
                                  : exception.reason,
                            ),
                            trailing: IconButton(
                              tooltip: 'Riapri giorno',
                              onPressed: () {
                                _deleteException(exception);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: gold,
                      ),
                      onPressed: _selectedDateIds.isEmpty || _isSaving
                          ? null
                          : _saveClosedDates,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_busy),
                      label: Text(
                        _isSaving
                            ? 'SALVATAGGIO...'
                            : 'CHIUDI DATE SELEZIONATE',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClosedDayCell extends StatelessWidget {
  final DateTime day;

  const _ClosedDayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
