import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[NotificationRuntime] init Firebase în background handler eșuat: $e');
  }
}

typedef NotificationTapHandler = Future<void> Function(
  Map<String, dynamic> payload,
);

class NotificationRuntimeService {
  NotificationRuntimeService._();

  static final NotificationRuntimeService instance =
      NotificationRuntimeService._();

  static const String _currentTokenKey =
      'notification_runtime_current_token_v1';
  static const String _currentUserIdKey = 'notification_runtime_user_id_v1';
  static const String _currentUserEmailKey =
      'notification_runtime_user_email_v1';
  static const String _channelId = 'modaris_realtime_notifications';
  static const String _channelName = 'Notificari ProVentaris';
  static const String _channelDescription =
      'Notificari operationale trimise catre utilizatori.';

  final NotificationCenterService _service = NotificationCenterService();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  AndroidNotificationChannel? _androidChannel;
  bool _initialized = false;
  NotificationTapHandler? _tapHandler;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _supportsPush => _isAndroid || _isIos;

  Future<void> initialize({
    required String userId,
    String userEmail = '',
    NotificationTapHandler? onTap,
  }) async {
    _tapHandler = onTap ?? _tapHandler;
    if (!_supportsPush) return;
    await _ensureInitialized();
    if (userId.trim().isEmpty) return;

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _service.registerDeviceToken(
        userId: userId.trim(),
        userEmail: userEmail.trim(),
        token: token.trim(),
        platform: _isAndroid ? 'android' : 'ios',
        deviceLabel: _isAndroid ? 'android_device' : 'ios_device',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentTokenKey, token.trim());
      await prefs.setString(_currentUserIdKey, userId.trim());
      await prefs.setString(_currentUserEmailKey, userEmail.trim());
    }
  }

  Future<void> deactivateCurrentDevice() async {
    if (!_supportsPush) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_currentTokenKey) ?? '';
    if (token.trim().isEmpty) return;
    await _service.deactivateDeviceToken(token.trim());
    await prefs.remove(_currentTokenKey);
    await prefs.remove(_currentUserIdKey);
    await prefs.remove(_currentUserEmailKey);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _androidChannel = const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) async {
        await _handlePayload(response.payload);
      },
    );
    if (_isAndroid && _androidChannel != null) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel!);
    }

    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _handleRemoteMessageTap(message);
    });
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteMessageTap(initialMessage);
    }
    _messaging.onTokenRefresh.listen((token) async {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_currentUserIdKey) ?? '';
      final userEmail = prefs.getString(_currentUserEmailKey) ?? '';
      if (userId.trim().isEmpty) return;
      await _service.registerDeviceToken(
        userId: userId.trim(),
        userEmail: userEmail.trim(),
        token: token.trim(),
        platform: _isAndroid ? 'android' : 'ios',
        deviceLabel: _isAndroid ? 'android_device' : 'ios_device',
      );
      await prefs.setString(_currentTokenKey, token.trim());
    });
    _initialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!.trim()
        : (message.data['title'] ?? 'Notificare').toString().trim();
    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!.trim()
        : (message.data['body'] ?? '').toString().trim();
    final payload = jsonEncode(message.data);
    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel?.id ?? _channelId,
          _androidChannel?.name ?? _channelName,
          channelDescription:
              _androidChannel?.description ?? _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    await _handlePayload(jsonEncode(message.data));
  }

  Future<void> _handlePayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      await _tapHandler?.call(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('[NotificationRuntime] procesare payload notificare eșuată: $e');
    }
  }

  /// Afișează o notificare locală imediată, fără server (util pentru alerte on-device).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    if (!_supportsPush) return;
    await _ensureInitialized();
    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel?.id ?? _channelId,
          _androidChannel?.name ?? _channelName,
          channelDescription:
              _androidChannel?.description ?? _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data.isEmpty ? null : jsonEncode(data),
    );
  }

  // ── Alerte specifice aplicației ───────────────────────────────────────────

  Future<void> showReminderProgramare({
    required String titlu,
    required String beneficiar,
    required String ora,
    required String tehnician,
    required String appointmentId,
  }) async {
    await showLocalNotification(
      title: 'Programare maine: $titlu',
      body: '$beneficiar • $ora • $tehnician',
      data: <String, dynamic>{'type': 'programare', 'id': appointmentId},
    );
  }

  Future<void> showAlertaStocMinim({
    required String produsNume,
    required double cantitateRamasa,
    required String unitate,
    required double pragMinim,
  }) async {
    await showLocalNotification(
      title: 'Stoc minim: $produsNume',
      body: 'Cantitate ramasa: ${cantitateRamasa.toStringAsFixed(1)} $unitate '
          '(prag minim: ${pragMinim.toStringAsFixed(1)} $unitate)',
      data: <String, dynamic>{'type': 'stoc', 'produs': produsNume},
    );
  }

  Future<void> showProgramareFinalizata({
    required String titlu,
    required String tehnician,
    required String appointmentId,
  }) async {
    await showLocalNotification(
      title: 'Programare finalizata',
      body: '$titlu — finalizata de $tehnician',
      data: <String, dynamic>{'type': 'programare', 'id': appointmentId},
    );
  }

  Future<void> showAlertaPlataRestanta({
    required String partenerNume,
    required double suma,
    required int zileDeLa,
  }) async {
    await showLocalNotification(
      title: 'Plata restanta: $partenerNume',
      body: '${suma.toStringAsFixed(2)} RON restant de $zileDeLa zile',
      data: <String, dynamic>{'type': 'financiar', 'partener': partenerNume},
    );
  }
}
