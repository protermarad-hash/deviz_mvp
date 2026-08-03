import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/design_system/widgets/app_card.dart';

/// Card KPI compact (icon + etichetă + valoare + subtext opțional) —
/// sursă unică pentru cele 3 copii aproape identice `_SumarCard` din
/// `programari_parteneri_page.dart`, `programari_profitabilitate_page.dart`
/// și `programari_consum_materiale_page.dart` (aug 2026).
///
/// Randare via [AppCard] elevated — aceeași rețetă (`AppElevatedCardStyle`)
/// deja folosită pe cardurile din Listă/Calendar/Pe echipe. [accentColor]
/// e furnizat de apelant (deja purta o semantică de culoare — primary/
/// verde/roșu/portocaliu în funcție de starea datelor) și devine atât
/// culoarea iconiței/valorii, cât și accentul cardului (bară + umbră).
class ProgramariSumarCard extends StatelessWidget {
  const ProgramariSumarCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.sub = '',
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      accentColor: accentColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
