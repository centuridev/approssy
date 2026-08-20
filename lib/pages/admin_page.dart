import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/loyalty_service.dart';
import 'availability_management_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const Duration pendingHoldDuration = Duration(hours: 2);

  static const Color gold = Color(0xFFDDA33B);

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  Timer? _expirationTimer;

  bool _isCheckingExpired = false;

  final Set<String> _processingAppointmentIds = {};

  String _selectedStatusFilter = 'active';
  String _selectedDateFilter = 'upcoming';

  static const List<_StatusFilterOption> _statusFilters = [
    _StatusFilterOption(
      id: 'active',
      label: 'Attive',
      icon: Icons.event_available,
    ),
    _StatusFilterOption(
      id: 'pending',
      label: 'In attesa',
      icon: Icons.hourglass_top,
    ),
    _StatusFilterOption(
      id: 'confirmed',
      label: 'Confermate',
      icon: Icons.check_circle_outline,
    ),
    _StatusFilterOption(
      id: 'rejected',
      label: 'Rifiutate',
      icon: Icons.cancel_outlined,
    ),
    _StatusFilterOption(
      id: 'cancelled',
      label: 'Annullate',
      icon: Icons.event_busy,
    ),
    _StatusFilterOption(
      id: 'expired',
      label: 'Scadute',
      icon: Icons.timer_off_outlined,
    ),
    _StatusFilterOption(id: 'all', label: 'Tutte', icon: Icons.list_alt),
  ];

  static const List<_DateFilterOption> _dateFilters = [
    _DateFilterOption(id: 'today', label: 'Oggi', icon: Icons.today),
    _DateFilterOption(id: 'upcoming', label: 'Prossime', icon: Icons.upcoming),
    _DateFilterOption(id: 'past', label: 'Passate', icon: Icons.history),
    _DateFilterOption(
      id: 'all',
      label: 'Tutte le date',
      icon: Icons.date_range,
    ),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _expirePendingAppointments();
    });

    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {});

      _expirePendingAppointments();
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final date = _dateTimeFromValue(value);

    if (date == null) {
      return 'Senza data';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(dynamic value) {
    final date = _dateTimeFromValue(value);

    if (date == null) {
      return 'Non definita';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _getHoldUntil(Map<String, dynamic> data) {
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

  bool _isPendingExpired(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? '';

    if (status != 'pending') {
      return false;
    }

    final holdUntil = _getHoldUntil(data);

    if (holdUntil == null) {
      return true;
    }

    return !holdUntil.isAfter(DateTime.now());
  }

  String _effectiveStatus(Map<String, dynamic> data) {
    if (_isPendingExpired(data)) {
      return 'expired';
    }

    return data['status']?.toString() ?? 'pending';
  }

  String _remainingHoldText(Map<String, dynamic> data) {
    final holdUntil = _getHoldUntil(data);

    if (holdUntil == null) {
      return 'Scaduta';
    }

    final difference = holdUntil.difference(DateTime.now());

    if (difference.isNegative || difference.inSeconds <= 0) {
      return 'Scaduta';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }

    return '${difference.inMinutes} min';
  }

  Future<void> _expirePendingAppointments() async {
    if (_isCheckingExpired) {
      return;
    }

    _isCheckingExpired = true;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      bool hasExpiredAppointments = false;

      for (final document in snapshot.docs) {
        final data = document.data();

        if (_isPendingExpired(data)) {
          batch.update(document.reference, {
            'status': 'expired',
            'expiredAt': FieldValue.serverTimestamp(),
            'holdUntil': FieldValue.delete(),
          });

          hasExpiredAppointments = true;
        }
      }

      if (hasExpiredAppointments) {
        await batch.commit();
      }
    } catch (error) {
      debugPrint(
        'Errore durante il controllo delle prenotazioni scadute: $error',
      );
    } finally {
      _isCheckingExpired = false;
    }
  }

  Future<void> _confirmAppointment(String appointmentId) async {
    final callable = _functions.httpsCallable('confirmAppointment');

    await callable.call<void>({'appointmentId': appointmentId});
  }

  Future<void> _rejectAppointment(String appointmentId) async {
    final callable = _functions.httpsCallable('rejectAppointment');

    await callable.call<void>({'appointmentId': appointmentId});
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    final callable = _functions.httpsCallable('cancelAppointment');

    await callable.call<void>({'appointmentId': appointmentId});
  }

  Future<void> _updateStatus({
    required String appointmentId,
    required String newStatus,
  }) async {
    if (_processingAppointmentIds.contains(appointmentId)) {
      return;
    }

    setState(() {
      _processingAppointmentIds.add(appointmentId);
    });

    Map<String, dynamic>? appointmentData;

    try {
      final appointmentReference = FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId);

      final appointmentSnapshot = await appointmentReference.get();

      if (!appointmentSnapshot.exists) {
        throw Exception('Prenotazione non trovata');
      }

      appointmentData = appointmentSnapshot.data();

      switch (newStatus) {
        case 'confirmed':
          await _confirmAppointment(appointmentId);
          break;

        case 'rejected':
          await _rejectAppointment(appointmentId);
          break;

        case 'cancelled':
          await _cancelAppointment(appointmentId);
          break;

        default:
          throw Exception('Stato non valido');
      }

      if (!mounted) {
        return;
      }

      final statusMessage = switch (newStatus) {
        'confirmed' => 'Prenotazione confermata con successo',
        'rejected' => 'Prenotazione rifiutata',
        'cancelled' => 'Prenotazione annullata',
        _ => 'Prenotazione aggiornata',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(statusMessage)));

      if (newStatus == 'confirmed' && appointmentData != null) {
        await _checkLoyaltyReward(appointmentData);
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      final errorMessage =
          error.message ?? 'Errore durante la comunicazione con il server';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Errore Firebase'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante l\'aggiornamento: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingAppointmentIds.remove(appointmentId);
        });
      }
    }
  }

  Future<void> _checkLoyaltyReward(Map<String, dynamic> appointmentData) async {
    final userId = appointmentData['userId']?.toString();

    if (userId == null || userId.isEmpty) {
      return;
    }

    final count = await LoyaltyService.getConfirmedBookingsCount(userId);

    final discountAlreadyAwarded = await LoyaltyService.hasDiscountAwarded(
      userId,
    );

    if (count == 10 && !discountAlreadyAwarded) {
      await LoyaltyService.recordDiscountAwarded(userId);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Premio fedeltà raggiunto'),
            content: const Text(
              'Il cliente ha raggiunto 10 appuntamenti '
              'confermati e ha ottenuto uno sconto di 5€.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _confirmRejection(String appointmentId) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rifiutare la prenotazione?'),
          content: const Text(
            'L\'orario verrà liberato immediatamente '
            'e potrà essere prenotato da un altro cliente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('INDIETRO'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('RIFIUTA', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldReject != true || !mounted) {
      return;
    }

    await _updateStatus(appointmentId: appointmentId, newStatus: 'rejected');
  }

  Future<void> _confirmCancellation(String appointmentId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Annullare l\'appuntamento?'),
          content: const Text(
            'L\'appuntamento confermato verrà annullato '
            'e l\'orario tornerà disponibile.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('INDIETRO'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ANNULLA', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    await _updateStatus(appointmentId: appointmentId, newStatus: 'cancelled');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'cancelled':
        return Colors.grey.shade700;

      case 'expired':
        return Colors.deepOrange;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.withValues(alpha: 0.10);

      case 'rejected':
        return Colors.red.withValues(alpha: 0.08);

      case 'cancelled':
        return Colors.grey.withValues(alpha: 0.10);

      case 'expired':
        return Colors.deepOrange.withValues(alpha: 0.08);

      case 'pending':
      default:
        return Colors.orange.withValues(alpha: 0.10);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'IN ATTESA';

      case 'confirmed':
        return 'CONFERMATA';

      case 'rejected':
        return 'RIFIUTATA';

      case 'cancelled':
        return 'ANNULLATA';

      case 'expired':
        return 'SCADUTA';

      default:
        return status.toUpperCase();
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;

      case 'rejected':
        return Icons.cancel;

      case 'cancelled':
        return Icons.event_busy;

      case 'expired':
        return Icons.timer_off;

      case 'pending':
      default:
        return Icons.hourglass_top;
    }
  }

  bool _matchesStatusFilter(Map<String, dynamic> data) {
    final effectiveStatus = _effectiveStatus(data);

    switch (_selectedStatusFilter) {
      case 'active':
        return effectiveStatus == 'pending' || effectiveStatus == 'confirmed';

      case 'pending':
        return effectiveStatus == 'pending';

      case 'confirmed':
        return effectiveStatus == 'confirmed';

      case 'rejected':
        return effectiveStatus == 'rejected';

      case 'cancelled':
        return effectiveStatus == 'cancelled';

      case 'expired':
        return effectiveStatus == 'expired';

      case 'all':
      default:
        return true;
    }
  }

  bool _matchesDateFilter(Map<String, dynamic> data) {
    final appointmentDate = _dateTimeFromValue(data['selectedDateTime']);

    if (appointmentDate == null) {
      return _selectedDateFilter == 'all';
    }

    final appointmentDay = _normalizeDay(appointmentDate);
    final today = _normalizeDay(DateTime.now());

    switch (_selectedDateFilter) {
      case 'today':
        return appointmentDay == today;

      case 'upcoming':
        return appointmentDay.isAtSameMomentAs(today) ||
            appointmentDay.isAfter(today);

      case 'past':
        return appointmentDay.isBefore(today);

      case 'all':
      default:
        return true;
    }
  }

  int _countByStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> appointments,
    String filterId,
  ) {
    return appointments.where((document) {
      final data = document.data();
      final effectiveStatus = _effectiveStatus(data);

      switch (filterId) {
        case 'active':
          return effectiveStatus == 'pending' || effectiveStatus == 'confirmed';

        case 'pending':
          return effectiveStatus == 'pending';

        case 'confirmed':
          return effectiveStatus == 'confirmed';

        case 'rejected':
          return effectiveStatus == 'rejected';

        case 'cancelled':
          return effectiveStatus == 'cancelled';

        case 'expired':
          return effectiveStatus == 'expired';

        case 'all':
        default:
          return true;
      }
    }).length;
  }

  int _statusPriority(String status) {
    switch (status) {
      case 'pending':
        return 0;

      case 'confirmed':
        return 1;

      case 'rejected':
        return 2;

      case 'cancelled':
        return 3;

      case 'expired':
        return 4;

      default:
        return 5;
    }
  }

  void _sortAppointments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> appointments,
  ) {
    final now = DateTime.now();

    appointments.sort((first, second) {
      final firstData = first.data();
      final secondData = second.data();

      final firstDate = _dateTimeFromValue(firstData['selectedDateTime']);

      final secondDate = _dateTimeFromValue(secondData['selectedDateTime']);

      if (firstDate == null && secondDate == null) {
        return 0;
      }

      if (firstDate == null) {
        return 1;
      }

      if (secondDate == null) {
        return -1;
      }

      if (_selectedDateFilter == 'past') {
        return secondDate.compareTo(firstDate);
      }

      if (_selectedDateFilter == 'all') {
        final firstIsFuture = !firstDate.isBefore(now);
        final secondIsFuture = !secondDate.isBefore(now);

        if (firstIsFuture && !secondIsFuture) {
          return -1;
        }

        if (!firstIsFuture && secondIsFuture) {
          return 1;
        }

        if (!firstIsFuture && !secondIsFuture) {
          return secondDate.compareTo(firstDate);
        }
      }

      final firstPriority = _statusPriority(_effectiveStatus(firstData));

      final secondPriority = _statusPriority(_effectiveStatus(secondData));

      if (firstPriority != secondPriority) {
        return firstPriority.compareTo(secondPriority);
      }

      return firstDate.compareTo(secondDate);
    });
  }

  String _emptyStateMessage() {
    final statusLabel = _statusFilters
        .firstWhere((filter) => filter.id == _selectedStatusFilter)
        .label
        .toLowerCase();

    final dateLabel = _dateFilters
        .firstWhere((filter) => filter.id == _selectedDateFilter)
        .label
        .toLowerCase();

    return 'Nessuna prenotazione $statusLabel per $dateLabel.';
  }

  Widget _buildFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> appointments,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stato prenotazione',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),

          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((filter) {
                final selected = _selectedStatusFilter == filter.id;

                final count = _countByStatus(appointments, filter.id);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: gold,
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(
                      color: selected ? gold : Colors.grey.shade300,
                    ),
                    avatar: Icon(
                      filter.icon,
                      size: 18,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                    label: Text('${filter.label} ($count)'),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedStatusFilter = filter.id;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 20),

              const SizedBox(width: 8),

              const Text(
                'Periodo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),

              const Spacer(),

              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDateFilter,
                  borderRadius: BorderRadius.circular(12),
                  items: _dateFilters.map((filter) {
                    return DropdownMenuItem<String>(
                      value: filter.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(filter.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(filter.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedDateFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMoney(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return '${number.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatDurationMinutes(dynamic value) {
    final minutes = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

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

  List<Map<String, dynamic>> _servicesFromAppointment(
    Map<String, dynamic> data,
  ) {
    final rawServices = data['services'];

    if (rawServices is! List) {
      return [];
    }

    return rawServices
        .whereType<Map>()
        .map((service) => Map<String, dynamic>.from(service))
        .toList();
  }

  List<Map<String, dynamic>> _extrasFromService(Map<String, dynamic> service) {
    final rawExtras = service['extras'];

    if (rawExtras is! List) {
      return [];
    }

    return rawExtras
        .whereType<Map>()
        .map((extra) => Map<String, dynamic>.from(extra))
        .toList();
  }

  Widget _buildServicesSummary(Map<String, dynamic> data) {
    final services = _servicesFromAppointment(data);

    // Compatibilità con le vecchie prenotazioni.
    if (services.isEmpty) {
      return Column(
        children: [
          _AppointmentInfoRow(
            icon: Icons.design_services_outlined,
            label: 'Servizio',
            value: data['serviceName']?.toString() ?? 'Senza servizio',
          ),
          _AppointmentInfoRow(
            icon: Icons.euro,
            label: 'Prezzo',
            value: _formatMoney(data['servicePrice']),
          ),
          _AppointmentInfoRow(
            icon: Icons.timer_outlined,
            label: 'Durata',
            value: _formatDurationMinutes(data['serviceDuration']),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.design_services_outlined, size: 16, color: gold),
              SizedBox(width: 6),
              Text(
                'Servizi prenotati',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),

          const SizedBox(height: 7),

          ...services.asMap().entries.map((entry) {
            final index = entry.key;
            final service = entry.value;
            final extras = _extrasFromService(service);

            final name = service['name']?.toString() ?? 'Servizio';

            final basePrice = service['price'];
            final baseDuration = service['duration'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. $name',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${_formatMoney(basePrice)}'
                    ' · '
                    '${_formatDurationMinutes(baseDuration)}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),

                  if (extras.isNotEmpty) ...[
                    const SizedBox(height: 5),

                    const Text(
                      'Extra',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    ...extras.map((extra) {
                      final extraName = extra['name']?.toString() ?? 'Extra';

                      return Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '+ ',
                              style: TextStyle(
                                fontSize: 10,
                                color: gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Expanded(
                              child: Text(
                                extraName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),

                            const SizedBox(width: 5),

                            Text(
                              '${_formatMoney(extra['price'])}'
                              ' · '
                              '+${_formatDurationMinutes(extra['duration'])}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (index < services.length - 1) const Divider(height: 12),
                ],
              ),
            );
          }),

          const Divider(height: 8),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Totale',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),

              Text(
                _formatDurationMinutes(data['serviceDuration']),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: 10),

              Text(
                _formatMoney(data['servicePrice']),
                style: const TextStyle(
                  color: gold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final appointmentId = document.id;

    final originalStatus = data['status']?.toString() ?? 'pending';

    final displayedStatus = _effectiveStatus(data);

    final pendingExpired = displayedStatus == 'expired';

    final isProcessing = _processingAppointmentIds.contains(appointmentId);

    final statusColor = _statusColor(displayedStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      elevation: 2,
      color: _statusBackgroundColor(displayedStatus),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${data['clientName'] ?? 'Cliente'} '
                    '${data['clientLastName'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(displayedStatus),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel(displayedStatus),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _AppointmentInfoRow(
              icon: Icons.phone_outlined,
              label: 'Telefono',
              value: data['phone']?.toString() ?? 'Non disponibile',
            ),

            _AppointmentInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: data['email']?.toString() ?? 'Non disponibile',
            ),

            _buildServicesSummary(data),

            _AppointmentInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Data',
              value: _formatDate(data['selectedDateTime']),
            ),

            _AppointmentInfoRow(
              icon: Icons.access_time,
              label: 'Ora',
              value: _formatTime(data['selectedDateTime']),
            ),

            if (originalStatus == 'pending' && !pendingExpired) ...[
              const Divider(height: 24),

              _AppointmentInfoRow(
                icon: Icons.lock_clock_outlined,
                label: 'Blocco temporaneo fino alle',
                value: _formatTime(data['holdUntil']),
                bold: true,
              ),

              _AppointmentInfoRow(
                icon: Icons.hourglass_bottom,
                label: 'Tempo rimanente',
                value: _remainingHoldText(data),
                valueColor: Colors.orange,
                bold: true,
              ),
            ],

            if (originalStatus == 'confirmed' &&
                data['blockedUntil'] != null) ...[
              const Divider(height: 24),

              _AppointmentInfoRow(
                icon: Icons.event_available,
                label: 'Orario occupato fino alle',
                value: _formatTime(data['blockedUntil']),
                bold: true,
              ),
            ],

            if (isProcessing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],

            if (originalStatus == 'pending' && !pendingExpired) ...[
              const SizedBox(height: 16),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(150, 45),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isProcessing
                        ? null
                        : () {
                            _updateStatus(
                              appointmentId: appointmentId,
                              newStatus: 'confirmed',
                            );
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('CONFERMA'),
                  ),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(130, 45),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isProcessing
                        ? null
                        : () {
                            _confirmRejection(appointmentId);
                          },
                    icon: const Icon(Icons.close),
                    label: const Text('RIFIUTA'),
                  ),
                ],
              ),
            ],

            if (originalStatus == 'confirmed') ...[
              const SizedBox(height: 16),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, 45),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: isProcessing
                    ? null
                    : () {
                        _confirmCancellation(appointmentId);
                      },
                icon: const Icon(Icons.event_busy),
                label: const Text('ANNULLA'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingRole) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!provider.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Prenotazioni')),
            body: const Center(child: Text('Accesso negato')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Prenotazioni'),
            actions: [
              IconButton(
                tooltip: 'Gestione disponibilità',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvailabilityManagementPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
              ),

              IconButton(
                tooltip: 'Aggiorna',
                onPressed: _isCheckingExpired
                    ? null
                    : _expirePendingAppointments,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Errore Firestore: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAppointments = snapshot.data?.docs.toList() ?? [];

              final filteredAppointments = allAppointments.where((document) {
                final data = document.data();

                return _matchesStatusFilter(data) && _matchesDateFilter(data);
              }).toList();

              _sortAppointments(filteredAppointments);

              return Column(
                children: [
                  _buildFilters(allAppointments),

                  Expanded(
                    child: filteredAppointments.isEmpty
                        ? _EmptyAppointmentsView(message: _emptyStateMessage())
                        : RefreshIndicator(
                            onRefresh: _expirePendingAppointments,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                top: 5,
                                bottom: 24,
                              ),
                              itemCount: filteredAppointments.length,
                              itemBuilder: (context, index) {
                                return _buildAppointmentCard(
                                  filteredAppointments[index],
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusFilterOption {
  final String id;
  final String label;
  final IconData icon;

  const _StatusFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _DateFilterOption {
  final String id;
  final String label;
  final IconData icon;

  const _DateFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _AppointmentInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _AppointmentInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),

          const SizedBox(width: 8),

          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppointmentsView extends StatelessWidget {
  final String message;

  const _EmptyAppointmentsView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
