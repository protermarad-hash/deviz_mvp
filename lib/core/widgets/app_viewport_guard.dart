import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppViewportGuard extends StatelessWidget {
  const AppViewportGuard({
    super.key,
    required this.child,
  });

  static const double desktopBottomGutter = 12;
  static const double floatingActionButtonClearance = 80;

  final Widget child;

  static double bottomSpacing({
    double base = 16,
    bool reserveForFab = false,
  }) {
    return base + (reserveForFab ? floatingActionButtonClearance : 0);
  }

  static EdgeInsets scrollablePadding({
    double horizontal = 16,
    double top = 16,
    double bottom = 16,
    bool reserveForFab = false,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottomSpacing(base: bottom, reserveForFab: reserveForFab),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_AppViewportGuardScope.maybeOf(context)) {
      return child;
    }

    final minimumBottom = switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS =>
        desktopBottomGutter,
      _ => 0.0,
    };

    return _AppViewportGuardScope(
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: minimumBottom),
        child: child,
      ),
    );
  }
}

class _AppViewportGuardScope extends InheritedWidget {
  const _AppViewportGuardScope({
    required super.child,
  });

  static bool maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_AppViewportGuardScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(_AppViewportGuardScope oldWidget) => false;
}
