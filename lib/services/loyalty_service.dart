import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'utenti';

  /// Cuenta citas confirmadas del cliente
  static Future<int> getConfirmedBookingsCount(String userId) async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'confirmed')
        .get();
    return snapshot.docs.length;
  }

  /// Verifica si ya se otorgó el descuento de fidelidad
  static Future<bool> hasDiscountAwarded(String userId) async {
    final userDoc = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .get();
    return userDoc.data()?['discountAwardedAt'] != null;
  }

  /// Guarda que ya se entregó el descuento
  static Future<void> recordDiscountAwarded(String userId) async {
    await _firestore.collection(_usersCollection).doc(userId).update({
      'discountAwardedAt': Timestamp.now(),
    });
  }

  /// Chequea si llegó a 10
  static Future<bool> isLoyaltyMilestone(String userId) async {
    return await getConfirmedBookingsCount(userId) == 10;
  }
}
