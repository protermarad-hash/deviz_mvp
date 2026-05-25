import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'deviz_theme_controller.dart';
import '../core/repositories/local_app_data_repository.dart';
import '../core/widgets/app_viewport_guard.dart';
import '../core/widgets/pen_aware_scroll_behavior.dart';
import 'role_ready_shell.dart';

class DevizUltraApp extends StatefulWidget {
  const DevizUltraApp({
    super.key,
    this.fieldAuthRoleKey,
    this.fieldAuthUserLabel,
    this.fieldAuthUserName,
    this.fieldAuthUserId,
    this.fieldAuthTeamId,
  });

  final String? fieldAuthRoleKey;
  /// Email-ul utilizatorului (folosit pentru funcționalitate)
  final String? fieldAuthUserLabel;
  /// Numele real al utilizatorului din Firestore (afișat în UI)
  final String? fieldAuthUserName;
  final String? fieldAuthUserId;
  final String? fieldAuthTeamId;

  @override
  State<DevizUltraApp> createState() => _DevizUltraAppState();
}

class _DevizUltraAppState extends State<DevizUltraApp> {
  late final LocalAppDataRepository _appDataRepository;
  late final DevizThemeController _themeController;
  late final Future<void> _themeBootstrap;

  @override
  void initState() {
    super.initState();
    _appDataRepository = LocalAppDataRepository();
    _themeController = DevizThemeController();
    _themeBootstrap =
        _themeController.initialize(_appDataRepository.loadCompanyProfile);
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _themeBootstrap,
      builder: (context, snapshot) => DevizThemeScope(
        controller: _themeController,
        child: AnimatedBuilder(
          animation: _themeController,
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ProVentaris',
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
            theme: _themeController.theme,
            home: RoleReadyAppShell(
              appDataRepository: _appDataRepository,
              fieldAuthRoleKey: widget.fieldAuthRoleKey,
              fieldAuthUserLabel: widget.fieldAuthUserLabel,
              fieldAuthUserName: widget.fieldAuthUserName,
              fieldAuthUserId: widget.fieldAuthUserId,
              fieldAuthTeamId: widget.fieldAuthTeamId,
            ),
          ),
        ),
      ),
    );
  }
}
