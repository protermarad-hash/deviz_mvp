import 'package:flutter/material.dart';

import '../../app_theme_preset.dart';
import '../app_tokens.dart';

/// FAB cu fundal gradient — `FloatingActionButton` standard Flutter NU
/// suportă gradient nativ pe `backgroundColor`, așa că se construiește peste
/// `Container` + `Material` + `InkWell` (nu peste `FloatingActionButton`).
/// Folosește implicit [AppBrandTheme.shellAccentGradient].
class AppGradientFab extends StatelessWidget {
  const AppGradientFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.gradient,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;

  /// Override opțional — implicit `AppBrandTheme.shellAccentGradient`.
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final effectiveGradient = gradient ??
        brand?.shellAccentGradient ??
        LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
          ],
        );
    final isExtended = label != null && label!.trim().isNotEmpty;

    // IntrinsicWidth OBLIGATORIU: Scaffold oferă slotului `floatingActionButton`
    // constrângeri loose dar mărginite (max = lățimea ecranului). Fără
    // IntrinsicWidth, `Center` de mai jos (Align fără widthFactor) se extinde
    // la maximul disponibil sub asemenea constrângeri, iar `Container` cu
    // `width: null` (varianta extended) moștenește acea lățime completă —
    // bug reprodus în producție: FAB-ul "Adaugă" devenea bară full-width.
    // IntrinsicWidth forțează dimensionarea după conținutul real, indiferent
    // de constrângerile primite din Scaffold.
    return IntrinsicWidth(
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: isExtended ? 20 : 0),
        width: isExtended ? null : 56,
        decoration: BoxDecoration(
          gradient: effectiveGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: effectiveGradient.colors.first.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Center(
              child: isExtended
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
