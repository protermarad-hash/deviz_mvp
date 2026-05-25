import 'package:flutter/material.dart';

import '../../core/auth/field_auth_service.dart';
import 'field_login_page.dart';

class FieldAuthGate extends StatefulWidget {
  const FieldAuthGate({
    super.key,
    required this.authService,
    required this.authenticatedBuilder,
    this.loginTitle = 'Autentificare utilizator',
  });

  final FieldAuthService authService;
  final WidgetBuilder authenticatedBuilder;
  final String loginTitle;

  @override
  State<FieldAuthGate> createState() => _FieldAuthGateState();
}

class _FieldAuthGateState extends State<FieldAuthGate> {
  @override
  void initState() {
    super.initState();
    widget.authService.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, _) {
        if (widget.authService.isLoading && !widget.authService.isAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!widget.authService.isAuthenticated) {
          return FieldLoginPage(
            authService: widget.authService,
            title: widget.loginTitle,
          );
        }
        return widget.authenticatedBuilder(context);
      },
    );
  }
}
