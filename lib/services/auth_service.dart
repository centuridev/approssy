import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static const String _usersCollection = 'utenti';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene role del usuario ('admin' o 'client')
  static Future<String> getUserRole(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      return doc.data()?['role']?.toString() ?? 'client';
    } catch (e) {
      return 'client';
    }
  }

  /// Obtiene datos del usuario
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    return doc.data() ?? {};
  }

  /// Crea perfil de usuario en Firestore
  static Future<void> createUserProfile({
    required String userId,
    required String nome,
    required String cognome,
    required String telefono,
    required String email,
    String role = 'client',
  }) async {
    await _firestore.collection(_usersCollection).doc(userId).set({
      'nome': nome,
      'cognome': cognome,
      'telefono': telefono,
      'email': email,
      'role': role,
      'createdAt': Timestamp.now(),
      'discountAwardedAt': null,
    });
  }

  /// Chequea si es admin
  static Future<bool> isAdmin(String userId) async {
    return await getUserRole(userId) == 'admin';
  }

  /// Set role (para desarrollo)
  static Future<void> setUserRole(String userId, String role) async {
    await _firestore.collection(_usersCollection).doc(userId).update({'role': role});
  }

  /// User actual
  static User? get currentUser => _auth.currentUser;
}
