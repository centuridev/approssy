import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String _role = 'client';
  bool _isLoadingRole = true;

  String get role => _role;

  bool get isAdmin => _role == 'admin';

  bool get isLoadingRole => _isLoadingRole;

  Future<void> loadRole(String? userId) async {
    _isLoadingRole = true;
    notifyListeners();

    if (userId == null) {
      _role = 'client';
      _isLoadingRole = false;
      notifyListeners();
      return;
    }

    try {
      _role = await AuthService.getUserRole(userId);
    } catch (_) {
      _role = 'client';
    }

    _isLoadingRole = false;
    notifyListeners();
  }

  Future<void> refreshRole() async {
    await loadRole(FirebaseAuth.instance.currentUser?.uid);
  }

  void resetRole() {
    _role = 'client';
    _isLoadingRole = false;
    notifyListeners();
  }
}
