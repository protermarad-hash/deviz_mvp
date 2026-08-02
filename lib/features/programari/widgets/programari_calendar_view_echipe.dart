part of '../programari_page.dart';

/// Vizualizare "Pe echipe" — coloane de calendar pe ECHIPĂ (nu pe angajat
/// individual), cu o coloană finală "Neasignat" pentru programările fără
/// echipă cunoscută. Mod ADĂUGAT lângă planner-ul existent (coloane de zi),
/// NU îl înlocuiește. Suportă drag & drop între coloane (etapa 3) — vezi
/// [reassignTeamOnDrop] pentru regula de reasignare.
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
    return DragTarget<_EchipeDragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.sourceColumnId != column.id,
      onAcceptWithDetails: (details) =>
          _handleEchipeTeamDrop(details.data, column.id),
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isDropTarget
                ? headerColor.withValues(alpha: 0.10)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDropTarget
                  ? headerColor
                  : headerColor.withValues(alpha: 0.3),
              width: isDropTarget ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              // Rând separat pentru indicatorul de zonă de drop — NICIODATĂ
              // în Row-ul de titlu de mai sus (regresia "elevated cards" din
              // trecut a fost cauzată exact de asta).
              if (isDropTarget)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: headerColor.withValues(alpha: 0.14),
                  child: Text(
                    'Plasează aici pentru a reasigna',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: headerColor,
                    ),
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
                            _buildEchipeAppointmentCard(
                          column.items[index],
                          sourceColumnId: column.id,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEchipeAppointmentCard(
    Appointment item, {
    required String sourceColumnId,
  }) {
    final card = _buildEchipeAppointmentCardContent(item);
    return LongPressDraggable<_EchipeDragPayload>(
      data: _EchipeDragPayload(item: item, sourceColumnId: sourceColumnId),
      delay: const Duration(milliseconds: 300),
      feedback: AppDragGhostCard(
        width: 284,
        child: _buildEchipeAppointmentCardContent(item),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _buildEchipeAppointmentCardContent(Appointment item) {
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

  /// Aplică regula pură [reassignTeamOnDrop] la programarea trasă, apoi
  /// salvează optimist: actualizare imediată din `_items` (pattern mirror
  /// pe cel de la `_showClientDataEditDialog`), `saveAppointment` fire-and-
  /// forget în fundal, cu revenire la starea anterioară + notificare vizuală
  /// la eroare.
  void _handleEchipeTeamDrop(
    _EchipeDragPayload payload,
    String targetColumnId,
  ) {
    if (payload.sourceColumnId == targetColumnId) {
      return; // no-op explicit — evită scrieri inutile în coada offline
    }

    final item = payload.item;
    final previousIndex = _items.indexWhere((a) => a.id == item.id);
    if (previousIndex < 0) return;
    final previous = _items[previousIndex];

    final newTeamIds = reassignTeamOnDrop(
      currentTeamIds: item.resolvedAssignedTeamIds,
      sourceColumnId: payload.sourceColumnId,
      targetColumnId: targetColumnId,
    );
    // Aceeași regulă de derivare a teamId legacy ca în
    // appointment_form_dialog.dart (enforcedAssignedTeamIds → teamId).
    final newTeamId = newTeamIds.isNotEmpty ? newTeamIds.first : '';
    final updated = item.copyWith(
      teamId: newTeamId,
      assignedTeamIds: newTeamIds,
    );

    _setStateLogged('echipe drag&drop reassign team', () {
      final list = List.of(_items);
      list[previousIndex] = updated;
      _items = list;
      _updateFilteredCache();
    });

    widget.repository.saveAppointment(updated).catchError((e) {
      if (!mounted) return;
      _setStateLogged('echipe drag&drop revert', () {
        final idx = _items.indexWhere((a) => a.id == item.id);
        if (idx >= 0) {
          final list = List.of(_items);
          list[idx] = previous;
          _items = list;
          _updateFilteredCache();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la reasignarea echipei: $e')),
      );
    });
  }
}

/// Payload de drag pentru vizualizarea "Pe echipe" — reține atât programarea
/// trasă, cât și coloana EXACTĂ din care a pornit drag-ul. Necesar pentru că
/// o programare cu 2+ echipe apare duplicată (același obiect) în mai multe
/// coloane simultan — `sourceColumnId` nu poate fi dedus doar din item.
class _EchipeDragPayload {
  const _EchipeDragPayload({required this.item, required this.sourceColumnId});

  final Appointment item;
  final String sourceColumnId;
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
