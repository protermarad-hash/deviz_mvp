import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options_loader.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool _isOnline = false;
  static String? _lastErrorMessage;

  /// Notifică UI-ul când starea online/offline se schimbă.
  static final ValueNotifier<bool> onlineNotifier = ValueNotifier(false);

  static bool get isInitialized => _initialized;
  /// True dacă Firebase e inițializat ȘI există conexiune la internet.
  static bool get isOnline => _initialized && _isOnline;
  static String? get lastErrorMessage => _lastErrorMessage;

  static void registerRuntimeError(Object error) {
    _lastErrorMessage = error.toString();
  }

  /// Verifică rapid conectivitate via DNS lookup (fără pachete extra).
  static Future<bool> checkOnline() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 2));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _isOnline = false;
    }
    onlineNotifier.value = _isOnline;
    return _isOnline;
  }

  static Future<void> initializeSafe() async {
    _lastErrorMessage = null;
    try {
      final options = resolveFirebaseOptions();
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      _initialized = true;
      // Verificăm conectivitate în paralel, nu blocăm startup-ul.
      checkOnline();
    } catch (error) {
      _initialized = false;
      _isOnline = false;
      _lastErrorMessage = error.toString();
    }
  }
}
