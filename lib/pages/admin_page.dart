import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/loyalty_service.dart';
import '../main.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  String _formatDate(dynamic date) {
    if (date == null) return 'Senza data';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return date.toString();
  }

  String _formatTime(dynamic date) {
    if (date == null || date is! Timestamp) return 'Non definita';
    final dt = date.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> updateStatus(
    BuildContext context,
    String id,
    String status,
  ) async {
    try {
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(id);

      final appointment = await appointmentRef.get();
      final data = appointment.data()!;

      final Map<String, dynamic> updateData = {'status': status};

      if (status == 'confirmed') {
        final selectedDateTime = data['selectedDateTime'] as Timestamp;
        final serviceDuration = data['serviceDuration'] ?? 0;

        updateData['confirmedAt'] = Timestamp.now();
        updateData['blockedUntil'] = Timestamp.fromDate(
          selectedDateTime.toDate().add(Duration(minutes: serviceDuration)),
        );
      }

      await appointmentRef.update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appuntamento $status con successo')),
      );

      if (status == 'confirmed') {
        final count = await LoyaltyService.getConfirmedBookingsCount(
          data['userId'],
        );

        final discountedAlready = await LoyaltyService.hasDiscountAwarded(
          data['userId'],
        );

        if (count == 10 && !discountedAlready) {
          await LoyaltyService.recordDiscountAwarded(data['userId']);

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Hai vinto uno sconto!'),
              content: const Text(
                'Il cliente ha raggiunto 10 appuntamenti. Hai guadagnato uno sconto di 5€.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante l\'aggiornamento dell\'appuntamento: $e',
          ),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    if (status == 'confirmed') return Colors.green;
    if (status == 'cancelled') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, provider, child) {
        if (!provider.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: Text("Prenotazioni")),
            body: Center(child: Text("Accesso Negato")),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Prenotazioni")),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('status', whereIn: ['pending', 'confirmed'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Errore Firestore: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var appointments = snapshot.data!.docs.toList();

              appointments.sort((a, b) {
                final aMap = a.data() as Map<String, dynamic>? ?? {};
                final bMap = b.data() as Map<String, dynamic>? ?? {};
                final aTs = aMap['selectedDateTime'] as Timestamp?;
                final bTs = bMap['selectedDateTime'] as Timestamp?;
                final aDate = aTs?.toDate();
                final bDate = bTs?.toDate();

                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return aDate.compareTo(bDate);
              });

              if (appointments.isEmpty) {
                return const Center(child: Text("Nessuna prenotazione"));
              }

              return ListView.builder(
                itemCount: appointments.length,
                itemBuilder: (context, index) {
                  final docSnap = appointments[index];
                  final data = docSnap.data() as Map<String, dynamic>? ?? {};
                  final docId = docSnap.id;
                  final status = data['status'] ?? 'pending';

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${data['clientName'] ?? 'Cliente'} ${data['clientLastName'] ?? ''}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Telefono: ${data['phone'] ?? 'Non disponibile'}",
                          ),
                          Text("Email: ${data['email'] ?? 'Non disponibile'}"),
                          Text(
                            "Servizio: ${data['serviceName'] ?? 'Sin servizio'}",
                          ),
                          Text(
                            "Durata: ${data['serviceDuration']?.toString() ?? '0'} min",
                          ),
                          Text(
                            "Data: ${_formatDate(data['selectedDateTime'])}",
                          ),
                          Text("Ora: ${_formatTime(data['selectedDateTime'])}"),

                          if (data['blockedUntil'] != null)
                            Text(
                              "Bloccato fino: ${_formatTime(data['blockedUntil'])}",
                            ),

                          const SizedBox(height: 10),

                          Text(
                            "Status: $status",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _statusColor(status),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (status == 'pending')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(160, 45),
                                  ),
                                  onPressed: () {
                                    updateStatus(context, docId, 'confirmed');
                                  },
                                  child: const Text('CONFERMA APPUNTAMENTO'),
                                ),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  minimumSize: const Size(120, 45),
                                ),
                                onPressed: () {
                                  updateStatus(context, docId, 'cancelled');
                                },
                                child: const Text('ANNULLA'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
