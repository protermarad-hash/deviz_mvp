import 'package:flutter/material.dart';

/// Valori standard de spațiere pentru tot design system-ul.
/// Nu redefini spațieri hardcodate noi — folosește aceste constante.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Extensie subțire peste [Theme.of(context).textTheme] — NU redefinește
/// stilurile de la zero, doar dă alias-uri semantice consecvente
/// (heading/body/caption) peste tema deja existentă (inclusiv preset-ul
/// activ din app_theme_preset.dart).
class AppTypography {
  const AppTypography._();

  static TextStyle? heading(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  static TextStyle? headingSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  static TextStyle? body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  static TextStyle? bodyStrong(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          );

  static TextStyle? caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
}
