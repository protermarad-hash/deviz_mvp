import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'core/ai_config_store.dart';
import 'core/boot_trace.dart';
import 'core/crash_logger.dart';
import 'core/help/help_repository.dart';
import 'core/auth/field_auth_repository_factory.dart';
import 'core/auth/field_auth_service.dart';
import 'core/cloud/firebase_bootstrap.dart';
import 'core/notifications/appointment_reminder_scheduler.dart';
import 'core/widgets/app_viewport_guard.dart';
import 'core/widgets/pen_aware_scroll_behavior.dart';
import 'features/auth/field_auth_gate.dart';
import 'features/notifications/notification_runtime_service.dart';
import 'app/field_role_ready_shell.dart';

import 'app/deviz_ultra_app.dart';
import 'app/deviz_ultra_bootstrap.dart';

void main() {
  // (2) Erori Flutter framework (build/layout/paint etc.) — logate sincron
  // ÎNAINTE de comportamentul implicit.
  final FlutterExceptionHandler? previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    CrashLogger.log('FlutterError.onError', details.exception, details.stack);
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  // (3) Erori native/platformă (ex: Firebase Auth pe thread greșit) — logate
  // sincron; return true ca să nu propage crash-ul mai departe dacă se poate.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashLogger.log('PlatformDispatcher.onError', error, stack);
    return true;
  };

  // (1) Tot conținutul main() rulează într-o zonă protejată; orice eroare
  // necaptată din zonă este scrisă sincron în crash_log.txt.
  runZonedGuarded<void>(
    _runApp,
    (Object error, StackTrace stack) {
      CrashLogger.log('runZonedGuarded', error, stack);
    },
  );
}

Future<void> _runApp() async {
  BootTrace.reset();
  BootTrace.mark('main:start');
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ro_RO';
  // Toate 3 inițializările rulează în paralel — reduce startup cu ~300-500ms
  await Future.wait([
    initializeDateFormatting('ro_RO'),
    FirebaseBootstrap.initializeSafe(),
    AiConfigStore.load(),
  ]);
  BootTrace.mark(
    'main:firebase init=${FirebaseBootstrap.isInitialized} '
    'online=${FirebaseBootstrap.isOnline}',
  );
  // Inițializare sistem Help — best-effort (nu blochează startup)
  HelpRepository.instance.initialize().then((_) {
    HelpRepository.instance.seedIfEmpty().catchError((_) {});
  }).catchError((_) {});
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Refresh token la login și la fiecare schimbare de stare auth
  FirebaseAuth.instance.authStateChanges().listen((user) {
    BootTrace.mark('main:authState user=${user != null}');
    if (user != null) {
      user.getIdToken(true).catchError((_) => '');
      _fieldAuthService.promoteCloudSessionIfPossible();
    }
  });
  // Timer periodic 30 min — previne expirarea silențioasă a token-ului după inactivitate
  Timer.periodic(const Duration(minutes: 30), (_) {
    FirebaseAuth.instance.currentUser?.getIdToken(true).catchError((_) => '');
  });

  // Reminder-uri programări mâine — fire-and-forget, nu blochează startup
  AppointmentReminderScheduler.instance
      .scheduleRemindersForTomorrow()
      .catchError((_) {});
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const PenAwareScrollBehavior(),
      locale: const Locale('ro', 'RO'),
      supportedLocales: const <Locale>[
        Locale('ro', 'RO'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppViewportGuard(
        child: child ?? const SizedBox.shrink(),
      ),
      home: FieldAuthGate(
        authService: _fieldAuthService,
        authenticatedBuilder: (_) => FieldRoleReadyShell(
          authService: _fieldAuthService,
          child: DevizUltraBootstrapApp(
            child: DevizUltraApp(
              fieldAuthRoleKey: _fieldAuthService.role?.name,
              fieldAuthUserLabel: _fieldAuthService.session?.email,
              fieldAuthUserName: _fieldAuthService.userName,
              fieldAuthUserId: _fieldAuthService.userId,
              fieldAuthTeamId: _fieldAuthService.teamId,
            ),
          ),
        ),
      ),
    ),
  );
}

final FieldAuthService _fieldAuthService =
    FieldAuthService(FieldAuthRepositoryFactory.create());
