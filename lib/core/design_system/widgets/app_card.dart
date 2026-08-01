import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Wrapper subțire peste [Card] — respectă [CardThemeData] global definit în
/// app_theme_preset.dart (culoare, elevație, formă); standardizează DOAR
/// padding-ul intern via [AppSpacing].
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final shape = cardTheme.shape;
    final borderRadius = shape is RoundedRectangleBorder &&
            shape.borderRadius is BorderRadius
        ? shape.borderRadius as BorderRadius
        : BorderRadius.circular(24);

    final content = Padding(padding: padding, child: child);

    return Card(
      margin: margin ?? EdgeInsets.zero,
      color: color,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: content,
            )
          : content,
    );
  }
}
