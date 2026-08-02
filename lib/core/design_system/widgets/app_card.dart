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
    this.onLongPress,
    this.color,
    this.elevated = false,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  /// Variantă "elevated cards" (aug 2026): umbră pronunțată colorată după
  /// [accentColor] + bară de accent pe marginea stângă. Implicit `false` —
  /// păstrează exact comportamentul plat existent peste tot în aplicație.
  final bool elevated;

  /// Culoarea barei de accent + umbrei când [elevated] e `true`. Fără
  /// [accentColor], se folosește `colorScheme.primary`.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final shape = cardTheme.shape;
    final borderRadius = shape is RoundedRectangleBorder &&
            shape.borderRadius is BorderRadius
        ? shape.borderRadius as BorderRadius
        : AppElevatedCardStyle.borderRadius;

    final content = Padding(padding: padding, child: child);

    if (!elevated) {
      return Card(
        margin: margin ?? EdgeInsets.zero,
        color: color,
        child: onTap != null || onLongPress != null
            ? InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: borderRadius,
                child: content,
              )
            : content,
      );
    }

    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
        boxShadow: AppElevatedCardStyle.shadow(accent),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: AppElevatedCardStyle.accentBarWidth,
                  color: accent,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
