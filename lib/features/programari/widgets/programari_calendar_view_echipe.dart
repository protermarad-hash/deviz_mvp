part of '../programari_page.dart';

/// Vizualizare "Pe echipe" — coloane de calendar pe ECHIPĂ (nu pe angajat
/// individual), cu o coloană finală "Neasignat" pentru programările fără
/// echipă cunoscută. Mod ADĂUGAT lângă planner-ul existent (coloane de zi),
/// NU îl înlocuiește. FĂRĂ drag & drop — doar vizualizare (etapă separată).
/// Extension (nu mixin) pentru a evita circularitatea "on ClassItself";
/// `part of` păstrează accesul complet la starea privată a paginii.
extension _ProgramariCalendarEchipeViewX on _ProgramariPageState {
  AppStatusKind _appStatusKindFor(Appointment item) {
    switch (_normalizeStatusValue(item.status)) {
      case 'in_curs':
        return AppStatusKind.inCurs;
      case 'finalizata':
        return AppStatusKind.finalizata;
      case 'amanata':
        return AppStatusKind.amanata;
      case 'anulata':
        return AppStatusKind.anulata;
      case 'planificata':
      default:
        return AppStatusKind.planificata;
    }
  }

  Widget _buildCalendarViewEchipe(List<Appointment> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final day = _dateOnly(_calendarFocusDate);
        final isTodayRange = _isSameDate(day, DateTime.now());
        final grouped = groupAppointmentsByTeam(
          _calendarItemsForDate(day),
          _masterTeams,
        );
        final columns = <_EchipeColumnData>[
          for (final team in _masterTeams)
            _EchipeColumnData(
              id: team.id,
              name: team.name.trim().isEmpty ? team.id : team.name,
              color: team.colorValue != 0 ? Color(team.colorValue) : null,
              items: grouped[team.id] ?? const <Appointment>[],
            ),
          _EchipeColumnData(
            id: kUnassignedTeamColumnId,
            name: 'Neasignat',
            color: null,
            items: grouped[kUnassignedTeamColumnId] ?? const <Appointment>[],
          ),
        ];

        const columnWidth = 300.0;
        final bottomSpacing = AppViewportGuard.bottomSpacing(
          reserveForFab: _canCreateOperationalAppointments,
        );

        return Column(
          children: [
            _buildCalendarNavBar(<DateTime>[day], isTodayRange),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(8, 8, 8, bottomSpacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: columnWidth,
                          child: _buildEchipeColumn(column),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEchipeColumn(_EchipeColumnData column) {
    final cs = Theme.of(context).colorScheme;
    final headerColor = column.color ?? cs.primary;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: headerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    column.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: headerColor,
                    ),
                  ),
                ),
                Text(
                  '${column.items.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: headerColor,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: column.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Nicio programare.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: column.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _buildEchipeAppointmentCard(column.items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEchipeAppointmentCard(Appointment item) {
    final clientLabel = _resolvedClientName(item.clientId, item.clientName);
    final titleOrClient =
        item.title.trim().isNotEmpty ? item.title : clientLabel;
    final start = item.effectiveStartDateTime;
    final end = item.effectiveEndDateTime;
    final accent = _appointmentAccentColor(item);
    final avatarData = _avatarDataForAppointment(item);
    final isRecurring = item.recurrenceRule != 'none' &&
        item.recurrenceRule.trim().isNotEmpty;
    return AppCard(
      elevated: true,
      accentColor: accent,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () => _openDetails(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  titleOrClient,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isRecurring) ...[
                Icon(Icons.repeat, size: 14, color: accent),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_formatTime(start)} - ${_formatTime(end)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              AppStatusChip(
                label: _statusLabel(item.status),
                status: _appStatusKindFor(item),
              ),
              if (avatarData.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                AppTeamAvatarStack(avatars: avatarData, size: 20, maxVisible: 3),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EchipeColumnData {
  const _EchipeColumnData({
    required this.id,
    required this.name,
    required this.color,
    required this.items,
  });

  final String id;
  final String name;
  final Color? color;
  final List<Appointment> items;
}
