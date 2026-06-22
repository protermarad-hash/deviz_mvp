import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../core/auth_session.dart';
import '../core/cloud/firebase_bootstrap.dart';
import '../core/cloud/offline_sync_runtime.dart';

class DevizUltraBootstrapApp extends StatefulWidget {
  const DevizUltraBootstrapApp({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DevizUltraBootstrapApp> createState() => _DevizUltraBootstrapAppState();
}

class _DevizUltraBootstrapAppState extends State<DevizUltraBootstrapApp>
    with WidgetsBindingObserver {
  late final AppSessionController _session;
  late final Future<void> _bootstrap;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = AppSessionController.localOnly();
    _bootstrap = _initializeBootstrap();
    // Pe Windows, Firestore (SDK C++) e lent → verificările dese de
    // conectivitate + sync creează presiune inutilă. Rărim intervalul la 2 min.
    // Pe Android păstrăm 30s (comportamentul actual).
    final syncInterval = Platform.isWindows
        ? const Duration(minutes: 2)
        : const Duration(seconds: 30);
    _syncTimer = Timer.periodic(
      syncInterval,
      (_) async {
        // Re-verifică conectivitate înainte de sync.
        await FirebaseBootstrap.checkOnline();
        await OfflineSyncRuntime.instance.syncPending();
      },
    );
  }

  Future<void> _initializeBootstrap() async {
    await _session.initialize();
    // Curăță IMEDIAT coada de sync: elimină itemele vechi (sincronizate/moarte).
    // Fără aceasta, operațiile JSON pe coada mare blochează UI la prima utilizare.
    unawaited(OfflineSyncRuntime.instance.cleanupQueue());
    // syncPending rulează în fundal - nu blochează UI-ul la startup
    unawaited(OfflineSyncRuntime.instance.syncPending());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verifică conectivitate când app revine în prim-plan.
      FirebaseBootstrap.checkOnline().then(
        (_) => OfflineSyncRuntime.instance.syncPending(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        return AppSessionScope(
          controller: _session,
          child: widget.child,
        );
      },
    );
  }
}
