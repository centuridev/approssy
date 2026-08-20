import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _appointmentsChannel =
      AndroidNotificationChannel(
        'appointments',
        'Appuntamenti',
        description:
            'Notifiche relative alla conferma, al rifiuto '
            'e all\'annullamento degli appuntamenti.',
        importance: Importance.high,
      );

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;

  static Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();

      final settings = await _messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Tempo scaduto durante la richiesta dei permessi.',
              );
            },
          );

      debugPrint('Permesso notifiche: ${settings.authorizationStatus}');

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _foregroundSubscription?.cancel();

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );

      await _openedAppSubscription?.cancel();

      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (error, stackTrace) {
      debugPrint('Errore durante l\'inizializzazione delle notifiche: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notifica locale aperta. Payload: ${response.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_appointmentsChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) {
      debugPrint('FCM ricevuto senza contenuto notification: ${message.data}');
      return;
    }

    final notificationId =
        message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      id: notificationId,
      title: notification.title ?? 'Rosi Beauty Premium',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments',
          'Appuntamenti',
          channelDescription:
              'Notifiche relative allo stato degli appuntamenti.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['appointmentId']?.toString(),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final appointmentId = message.data['appointmentId']?.toString();

    final status = message.data['status']?.toString();

    debugPrint('Notifica aperta: appointmentId=$appointmentId, status=$status');

    /*
     * Más adelante podremos navegar directamente
     * hacia la pantalla de la cita correspondiente.
     */
  }

  static Future<void> saveCurrentToken(String userId) async {
    try {
      debugPrint('FCM: avvio salvataggio token per utente $userId');

      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException(
            'Tempo scaduto durante la generazione del token FCM.',
          );
        },
      );

      if (token == null || token.isEmpty) {
        debugPrint('FCM: token non disponibile');
        return;
      }

      await _saveToken(userId: userId, token: token);

      debugPrint('FCM: token salvato correttamente in Firestore');

      await _tokenRefreshSubscription?.cancel();

      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
        newToken,
      ) async {
        await _saveToken(userId: userId, token: newToken);
      });
    } catch (error, stackTrace) {
      debugPrint('FCM: errore durante il salvataggio del token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    final tokenId = token.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    final tokenReference = _firestore
        .collection('utenti')
        .doc(userId)
        .collection('fcmTokens')
        .doc(tokenId);

    final existingToken = await tokenReference.get();

    await tokenReference.set({
      'token': token,
      'platform': _platformName(),
      if (!existingToken.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
