import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'pages/catalogo_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'services/push_notification_service.dart';

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingSubscription;

void listenNewBookings() {
  _bookingSubscription?.cancel();

  _bookingSubscription = FirebaseFirestore.instance
      .collection('appointments')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snapshot) {
        // Aquí se podrán agregar notificaciones posteriormente.
      });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  listenNewBookings();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const RossiApp(),
    ),
  );

  /*
   * Se ejecuta después de runApp para no bloquear
   * la pantalla inicial si Firebase Messaging tarda.
   */
  unawaited(PushNotificationService.initialize());
}

class RossiApp extends StatelessWidget {
  const RossiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rosi Beauty Premium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDDA33B)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (!mounted) return;

      await context.read<AuthProvider>().loadRole(user?.uid);

      if (user != null) {
        await PushNotificationService.saveCurrentToken(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const CatalogoPage();
        }

        return const LoginPage();
      },
    );
  }
}
