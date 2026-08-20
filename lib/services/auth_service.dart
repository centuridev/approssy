import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static const String _usersCollection = 'utenti';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene el rol del usuario.
  /// Valores esperados: "admin" o "client".
  static Future<String> getUserRole(String userId) async {
    try {
      final document = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!document.exists) {
        return 'client';
      }

      final data = document.data();

      final role = data?['role']?.toString().trim().toLowerCase() ?? 'client';

      return role == 'admin' ? 'admin' : 'client';
    } catch (error) {
      // Intento adicional usando la caché local.
      try {
        final cachedDocument = await _firestore
            .collection(_usersCollection)
            .doc(userId)
            .get(const GetOptions(source: Source.cache));

        final data = cachedDocument.data();

        final role = data?['role']?.toString().trim().toLowerCase() ?? 'client';

        return role == 'admin' ? 'admin' : 'client';
      } catch (_) {
        return 'client';
      }
    }
  }

  /// Obtiene los datos completos del usuario.
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final document = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .get();

    return document.data() ?? {};
  }

  /// Crea el perfil del usuario en Firestore.
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
      'role': role.trim().toLowerCase(),
      'createdAt': Timestamp.now(),
      'discountAwardedAt': null,
    });
  }

  /// Comprueba si un usuario tiene rol de administrador.
  static Future<bool> isAdmin(String userId) async {
    final role = await getUserRole(userId);
    return role == 'admin';
  }

  /// Cambia el rol del usuario.
  static Future<void> setUserRole(String userId, String role) async {
    await _firestore.collection(_usersCollection).doc(userId).update({
      'role': role.trim().toLowerCase(),
    });
  }

  /// Usuario autenticado actualmente.
  static User? get currentUser => _auth.currentUser;
}
