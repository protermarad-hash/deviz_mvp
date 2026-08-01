import 'package:flutter/material.dart';

import '../../../core/design_system/widgets/app_team_avatar_stack.dart';

/// Rândul secundar (iconiță recurență + avatare echipă) al cardului din
/// planner-ul Calendar — extras ca widget testabil independent, SEPARAT de
/// rândul de titlu. Randează gol (`SizedBox.shrink`) dacă nu există nici
/// recurență, nici avatare — evită un rând gol în `Column`.
///
/// Motivul extragerii (aug 2026): înainte, aceste elemente erau plasate în
/// `Row`-ul titlului, alături de `Expanded(Text(title))` — reducând spațiul
/// disponibil titlului în interiorul lățimii FIXE a coloanei de zi (176/240pt),
/// cauzând trunchiere agresivă a textului indiferent de dimensiunea ecranului.
class CalendarCardMetaRow extends StatelessWidget {
  const CalendarCardMetaRow({
    super.key,
    required this.isRecurring,
    required this.avatars,
    required this.accentColor,
  });

  final bool isRecurring;
  final List<AppAvatarData> avatars;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (!isRecurring && avatars.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRecurring) ...[
          Icon(Icons.repeat, size: 13, color: accentColor),
          const SizedBox(width: 4),
        ],
        if (avatars.isNotEmpty)
          AppTeamAvatarStack(avatars: avatars, size: 18, maxVisible: 2),
      ],
    );
  }
}
