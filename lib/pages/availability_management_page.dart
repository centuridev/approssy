import 'package:flutter/material.dart';

import '../models/weekly_availability.dart';
import '../services/availability_service.dart';
import 'availability_exceptions_page.dart';

class AvailabilityManagementPage extends StatefulWidget {
  const AvailabilityManagementPage({super.key});

  @override
  State<AvailabilityManagementPage> createState() =>
      _AvailabilityManagementPageState();
}

class _AvailabilityManagementPageState
    extends State<AvailabilityManagementPage> {
  static const Color gold = Color(0xFFDDA33B);

  bool _isCreatingDefaultWeek = false;

  Future<void> _createDefaultWeek() async {
    if (_isCreatingDefaultWeek) return;

    setState(() {
      _isCreatingDefaultWeek = true;
    });

    try {
      await AvailabilityService.createDefaultWeek();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settimana predefinita creata correttamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la creazione della settimana: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingDefaultWeek = false;
        });
      }
    }
  }

  void _openExceptionsSection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvailabilityExceptionsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione disponibilità'),
        actions: [
          IconButton(
            tooltip: 'Crea settimana predefinita',
            onPressed: _isCreatingDefaultWeek ? null : _createDefaultWeek,
            icon: _isCreatingDefaultWeek
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: StreamBuilder<List<WeeklyAvailability>>(
        stream: AvailabilityService.watchWeeklyAvailability(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Errore durante il caricamento: ${snapshot.error}',
              onRetry: _createDefaultWeek,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final weeklyAvailability =
              snapshot.data ?? const <WeeklyAvailability>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildIntroductionCard(),

              const SizedBox(height: 20),

              const Text(
                'Orario settimanale',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Questo orario si ripete automaticamente '
                'ogni settimana.',
                style: TextStyle(color: Colors.grey.shade700),
              ),

              const SizedBox(height: 14),

              ...weeklyAvailability.map(
                (availability) => _WeeklyAvailabilityCard(
                  key: ValueKey(
                    '${availability.dayId}-'
                    '${availability.enabled}-'
                    '${availability.startTime}-'
                    '${availability.endTime}',
                  ),
                  availability: availability,
                ),
              ),

              const SizedBox(height: 24),

              _buildExceptionsCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return Card(
      elevation: 0,
      color: gold.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: gold),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: gold),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Configura i giorni e gli orari abituali '
                'in cui Rosi riceve le clienti. Le modifiche '
                'saranno utilizzate nel calendario delle '
                'prenotazioni.',
                style: TextStyle(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_busy, color: gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Festività e orari speciali',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              'Da qui Rosi potrà chiudere un giorno completo, '
              'modificare l’orario di una data o bloccare '
              'intervalli specifici.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: gold),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _openExceptionsSection,
                icon: const Icon(Icons.calendar_month, color: gold),
                label: const Text('GESTISCI ECCEZIONI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyAvailabilityCard extends StatefulWidget {
  final WeeklyAvailability availability;

  const _WeeklyAvailabilityCard({super.key, required this.availability});

  @override
  State<_WeeklyAvailabilityCard> createState() =>
      _WeeklyAvailabilityCardState();
}

class _WeeklyAvailabilityCardState extends State<_WeeklyAvailabilityCard> {
  static const Color gold = Color(0xFFDDA33B);

  late bool _enabled;
  late String _startTime;
  late String _endTime;

  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  void _loadInitialValues() {
    _enabled = widget.availability.enabled;

    _startTime = widget.availability.startTime ?? '09:00';

    _endTime = widget.availability.endTime ?? '20:00';
  }

  String get _dayLabel {
    switch (widget.availability.dayId) {
      case 'monday':
        return 'Lunedì';
      case 'tuesday':
        return 'Martedì';
      case 'wednesday':
        return 'Mercoledì';
      case 'thursday':
        return 'Giovedì';
      case 'friday':
        return 'Venerdì';
      case 'saturday':
        return 'Sabato';
      case 'sunday':
        return 'Domenica';
      default:
        return widget.availability.dayId;
    }
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  int _timeToMinutes(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return 0;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return (hour * 60) + minute;
  }

  Future<TimeOfDay?> _showTimePicker(String initialValue) {
    return showTimePicker(
      context: context,
      initialTime: _parseTime(initialValue),
      helpText: 'SELEZIONA ORARIO',
      cancelText: 'ANNULLA',
      confirmText: 'CONFERMA',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _selectStartTime() async {
    final selectedTime = await _showTimePicker(_startTime);

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _startTime = _formatTime(selectedTime);
      _hasChanges = true;
    });
  }

  Future<void> _selectEndTime() async {
    final selectedTime = await _showTimePicker(_endTime);

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _endTime = _formatTime(selectedTime);
      _hasChanges = true;
    });
  }

  bool _validateTimes() {
    if (!_enabled) {
      return true;
    }

    final startMinutes = _timeToMinutes(_startTime);

    final endMinutes = _timeToMinutes(_endTime);

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’orario di chiusura deve essere '
            'successivo all’orario di apertura.',
          ),
        ),
      );

      return false;
    }

    return true;
  }

  Future<void> _save() async {
    if (_isSaving || !_validateTimes()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedAvailability = WeeklyAvailability(
        dayId: widget.availability.dayId,
        enabled: _enabled,
        startTime: _enabled ? _startTime : null,
        endTime: _enabled ? _endTime : null,
        breaks: widget.availability.breaks,
      );

      await AvailabilityService.saveWeeklyAvailability(updatedAvailability);

      if (!mounted) return;

      setState(() {
        _hasChanges = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Orario di $_dayLabel salvato.')));
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _hasChanges ? gold : Colors.grey.shade300,
          width: _hasChanges ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dayLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  _enabled ? 'Aperto' : 'Chiuso',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _enabled ? Colors.green : Colors.red,
                  ),
                ),

                const SizedBox(width: 6),

                Switch(
                  value: _enabled,
                  activeThumbColor: gold,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),

            if (_enabled) ...[
              const Divider(),

              Row(
                children: [
                  Expanded(
                    child: _TimeSelector(
                      label: 'Apertura',
                      value: _startTime,
                      icon: Icons.login,
                      onTap: _selectStartTime,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _TimeSelector(
                      label: 'Chiusura',
                      value: _endTime,
                      icon: Icons.logout,
                      onTap: _selectEndTime,
                    ),
                  ),
                ],
              ),

              if (widget.availability.breaks.isNotEmpty) ...[
                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pause configurate: '
                    '${widget.availability.breaks.length}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ] else ...[
              const Divider(),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I clienti non potranno prenotare '
                        'in questo giorno della settimana.',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_hasChanges) ...[
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: gold,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'SALVATAGGIO...'
                        : 'SALVA $_dayLabel'.toUpperCase(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.red),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('RIPROVA'),
            ),
          ],
        ),
      ),
    );
  }
}
