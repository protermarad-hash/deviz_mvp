import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Statusuri de sistem cu mapare de culoare CONSECVENTĂ în toată aplicația.
/// NU suprascrie colorCode-urile custom existente ale programărilor —
/// e destinat statusurilor generice de flux (planificat/în curs/finalizat/
/// amânat/anulat) folosite în design system.
enum AppStatusKind {
  planificata,
  inCurs,
  finalizata,
  amanata,
  anulata,
  info,
  neutral,
}

/// Chip colorat pentru status — paletă semantică HVAC consecventă:
/// albastru = normal/planificat, portocaliu = în desfășurare,
/// verde = finalizat, gri = amânat/inactiv, roșu = anulat/critic.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.customColor,
  });

  final String label;
  final AppStatusKind status;
  final IconData? icon;

  /// Override opțional al culorii semantice din [status] — folosit pentru
  /// badge-uri care nu au un status de flux propriu-zis (ex: recurență).
  /// Fără el, comportamentul existent (mapare pe [AppStatusKind]) e neschimbat.
  final Color? customColor;

  Color _colorFor(AppStatusKind status, ColorScheme scheme) {
    switch (status) {
      case AppStatusKind.planificata:
        return const Color(0xFF0057B8);
      case AppStatusKind.inCurs:
        return const Color(0xFFB45309);
      case AppStatusKind.finalizata:
        return const Color(0xFF15803D);
      case AppStatusKind.amanata:
        // Gri mai închis decât Gray 500 (0xFF6B7280) — la fundal mai saturat
        // (alpha 0.22 mai jos), gri-ul deschis pica sub prag de contrast
        // lizibil. Aceeași nuanță (gri), doar mai intensă.
        return const Color(0xFF4B5563);
      case AppStatusKind.anulata:
        return const Color(0xFFDC2626);
      case AppStatusKind.info:
        return scheme.primary;
      case AppStatusKind.neutral:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = customColor ?? _colorFor(status, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        // Fundal mai saturat (0.12 -> 0.22) la cererea explicită de "culori
        // mai pronunțate" pe chip-urile de status — text-ul rămâne la
        // culoarea plină (nediluată), deci contrastul crește proporțional
        // cu saturația fundalului, nu scade.
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
