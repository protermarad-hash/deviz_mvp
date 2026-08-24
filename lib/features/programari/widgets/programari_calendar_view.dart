part of '../programari_page.dart';

/// Randarea grilei orare a calendarului (planner pe coloane de zi) —
/// extrasă din `_ProgramariPageState` FĂRĂ nicio schimbare de logică.
/// Extension (nu mixin) pentru a evita circularitatea "on ClassItself";
/// `part of` păstrează accesul complet la starea privată a paginii.
extension _ProgramariCalendarViewX on _ProgramariPageState {
  bool _calendarUsesWeekAnchor(int dayCount) =>
      CalendarIntervalNavigation.usesWeekAnchor(dayCount);

  List<DateTime> _calendarDays({required int dayCount}) {
    final start = _calendarUsesWeekAnchor(dayCount)
        ? _startOfWeekMonday(_calendarFocusDate)
        : _dateOnly(_calendarFocusDate);
    return List<DateTime>.generate(
      dayCount,
      (index) => DateTime(start.year, start.month, start.day + index),
      growable: false,
    );
  }

  Widget _buildCalendarNavBar(List<DateTime> visibleDays, bool isTodayRange) {
    final label = _calendarRangeLabel(visibleDays);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _isCalendarNavigating ? null : _goToPreviousCalendarInterval,
            tooltip: 'Interval anterior',
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showCalendarIntervalPicker,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (!isTodayRange)
            IconButton(
              icon: const Icon(Icons.my_location_outlined),
              onPressed: _goToTodayCalendar,
              tooltip: 'Azi',
              iconSize: 20,
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCalendarNavigating ? null : _goToNextCalendarInterval,
            tooltip: 'Interval următor',
          ),
          // Acces direct la panoul zoom/zile, indiferent de starea
          // _barraCollapsed a toolbar-ului principal — altfel utilizatorul
          // trebuia să deschidă mai întâi bara principală ca să ajungă la
          // butonul "Panou calendar".
          IconButton(
            icon: Icon(
              _showCalendarControlPanel
                  ? Icons.view_agenda_outlined
                  : Icons.tune_outlined,
            ),
            onPressed: () {
              // ignore: invalid_use_of_protected_member
              setState(() {
                _showCalendarControlPanel = !_showCalendarControlPanel;
              });
            },
            tooltip: _showCalendarControlPanel
                ? 'Ascunde panou calendar'
                : 'Panou calendar',
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  String _calendarRangeLabel(List<DateTime> days) {
    if (days.isEmpty) {
      return _formatDate(_calendarFocusDate);
    }
    if (days.length == 1) {
      return _formatDateLong(days.first);
    }
    final sameMonth = days.first.year == days.last.year &&
        days.first.month == days.last.month;
    if (sameMonth) {
      return '${days.first.day}-${days.last.day} ${DateFormat('MMMM yyyy', 'ro_RO').format(days.first)}';
    }
    return '${_formatDateLong(days.first)} - ${_formatDateLong(days.last)}';
  }

  String _calendarDayHeaderLabel(DateTime day) {
    final weekday = DateFormat('EEE', 'ro_RO').format(day);
    return '$weekday\n${day.day} ${_monthShort(day.month)}';
  }

  String _monthShort(int month) {
    const months = [
      'ian', 'feb', 'mar', 'apr', 'mai', 'iun',
      'iul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _dayTooltipMessage(DateTime day, DayType dayType) {
    switch (dayType) {
      case DayType.holiday:
        final name = RomanianHolidays.holidayName(day);
        final dateStr = '${day.day} ${_monthShort(day.month)}';
        return name != null ? '$name — $dateStr' : 'Sărbătoare legală';
      case DayType.sunday:
        return 'Duminică';
      case DayType.saturday:
        return 'Sâmbătă';
      case DayType.workday:
        return '';
    }
  }

  List<Appointment> _calendarItemsForDate(DateTime date) {
    final dayStart = _dateOnly(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _filteredItems.where((item) {
      final start = item.effectiveStartDateTime;
      final end = item.effectiveEndDateTime;
      return start.isBefore(dayEnd) && end.isAfter(dayStart);
    }).toList(growable: false)
      ..sort(
        (a, b) => a.effectiveStartDateTime.compareTo(b.effectiveStartDateTime),
      );
  }

  List<Appointment> _listItemsForDisplay(List<Appointment> items) {
    if (items.isEmpty) {
      return items;
    }
    final todayStart = _dateOnly(DateTime.now());
    final pivotIndex = items.indexWhere(
      (item) => !item.effectiveEndDateTime.isBefore(todayStart),
    );
    if (pivotIndex <= 0) {
      return items;
    }
    return <Appointment>[
      ...items.sublist(pivotIndex),
      ...items.sublist(0, pivotIndex),
    ];
  }

  List<CalendarPlacement> _calendarPlacementsForDay(
    List<Appointment> items,
    DateTime day,
  ) =>
      CalendarPlacement.computeForDay(items, day);

  /// Returnează plasamentele calendarului pentru o zi — cu cache per zi.
  /// Cache-ul este invalidat NUMAI când se schimbă `_cachedFilteredItems` sau `_calendarFocusDate`.
  /// Apelat din `_calendarDayColumn` pentru fiecare zi vizibilă.
  List<CalendarPlacement> _cachedPlacementsForDay(DateTime day) {
    // Invalidare cache dacă lista filtrată sau data focus s-au schimbat
    if (!identical(_calendarItemsCacheKey, _cachedFilteredItems) ||
        _calendarFocusDateCacheKey != _calendarFocusDate) {
      _calendarPlacementsCache = {};
      _calendarItemsCacheKey = _cachedFilteredItems;
      _calendarFocusDateCacheKey = _calendarFocusDate;
    }
    _calendarPlacementsCache ??= {};
    final dayKey = DateTime(day.year, day.month, day.day);
    return _calendarPlacementsCache!.putIfAbsent(dayKey, () {
      final dayItems = _calendarItemsForDate(day);
      return _calendarPlacementsForDay(dayItems, day);
    });
  }

  Widget _buildCalendarView(List<Appointment> items) {
    if (!_didScrollCalendarToTodayOnOpen) {
      _didScrollCalendarToTodayOnOpen = true;
      _scheduleCalendarScrollToDate(DateTime.now(), animate: false);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomSpacing = AppViewportGuard.bottomSpacing(
          reserveForFab: _canCreateOperationalAppointments,
        );
        final visibleDayCount = _ProgramariPageState._calendarVisibleDayOptions.contains(
          _calendarVisibleDays,
        )
            ? _calendarVisibleDays
            : 7;
        final visibleDays = _calendarDays(dayCount: visibleDayCount);
        final allVisibleItems =
            visibleDays.expand(_calendarItemsForDate).toList(growable: false);
        final isTodayRange =
            visibleDays.any((day) => _isSameDate(day, DateTime.now()));
        final earliestHour = allVisibleItems.isEmpty
            ? _ProgramariPageState._defaultWorkdayStartHour
            : allVisibleItems
                .map((item) => item.effectiveStartDateTime.hour)
                .reduce((a, b) => a < b ? a : b);
        final latestHour = allVisibleItems.isEmpty
            ? _ProgramariPageState._defaultWorkdayEndHour
            : allVisibleItems
                .map((item) =>
                    item.effectiveEndDateTime.hour +
                    (item.effectiveEndDateTime.minute > 0 ? 1 : 0))
                .reduce((a, b) => a > b ? a : b);
        final startHour = earliestHour < _plannerBaseStartHour
            ? earliestHour
            : _plannerBaseStartHour;
        final endHour =
            latestHour > _plannerBaseEndHour ? latestHour : _plannerBaseEndHour;
        final zoom = _calendarZoom.clamp(0.78, 1.16);
        final hourHeight = 64.0 * zoom;
        final timeColumnWidth = 68.0 * zoom;
        final targetDayColumnWidth =
            (visibleDayCount == 1 ? 240.0 : 176.0) * zoom;
        final totalHours = (endHour - startHour).clamp(1, 24);
        final totalHeight = totalHours * hourHeight;
        final intervalStep = 7; // always navigate by full week
        final useWeekAnchor = _calendarUsesWeekAnchor(visibleDayCount);
        final viewportPlannerWidth = (constraints.maxWidth - timeColumnWidth)
            .clamp(220.0, double.infinity);
        final plannerWidth = (targetDayColumnWidth * visibleDays.length).clamp(
          viewportPlannerWidth,
          double.infinity,
        );

        // Auto-scroll vertical la prima programare a intervalului vizibil —
        // fără el, grila pornea mereu de la `startHour` (poate fi 05:00),
        // iar programările de după-amiază/seară rămâneau sub fold, complet
        // în afara zonei vizibile fără scroll manual (confirmat vizual:
        // "programări care nu apar în Calendar" deși erau randate corect,
        // doar needescoperite). Declanșat DOAR când se schimbă efectiv
        // intervalul vizibil (focus/nr. zile), nu la orice rebuild.
        final verticalScrollKey =
            '${_calendarFocusDate.toIso8601String()}_$visibleDayCount';
        if (_calendarVerticalScrollKey != verticalScrollKey) {
          _calendarVerticalScrollKey = verticalScrollKey;
          final targetVerticalOffsetMinutes =
              calendarVerticalAutoScrollOffsetMinutes(
            startHour: startHour,
            earliestHour: earliestHour,
          );
          final targetVerticalOffset =
              targetVerticalOffsetMinutes / 60 * hourHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!_calendarVerticalScrollController.hasClients) return;
            final maxExtent =
                _calendarVerticalScrollController.position.maxScrollExtent;
            _calendarVerticalScrollController.jumpTo(
              targetVerticalOffset.clamp(0.0, maxExtent),
            );
          });
        }

        return Column(
          children: [
            _buildCalendarNavBar(visibleDays, isTodayRange),
            if (_showCalendarControlPanel)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: AppCard(
                  margin: EdgeInsets.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  // Panoul are conținut variabil (chips zoom/zile) care poate
                  // depăși înălțimea disponibilă pe telefoane mici — limitat +
                  // scrollabil intern ca toate opțiunile să rămână accesibile
                  // (fără asta, ultimele chips-uri erau tăiate sub fold, ex.
                  // "Zoom: Mare", confirmat vizual: overflow 80-176px).
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            // ignore: invalid_use_of_protected_member
                            setState(() {
                              final baseDate = useWeekAnchor
                                  ? _startOfWeekMonday(_calendarFocusDate)
                                  : _dateOnly(_calendarFocusDate);
                              _calendarFocusDate = DateTime(
                                baseDate.year,
                                baseDate.month,
                                baseDate.day - intervalStep,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                          label: Text(
                            visibleDayCount > 1
                                ? 'Interval anterior'
                                : 'Ziua anterioara',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _calendarFocusDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            // ignore: invalid_use_of_protected_member
                            setState(() {
                              _calendarFocusDate = useWeekAnchor
                                  ? _startOfWeekMonday(picked)
                                  : _dateOnly(picked);
                            });
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_calendarRangeLabel(visibleDays)),
                        ),
                        if (!isTodayRange)
                          FilledButton.tonalIcon(
                            onPressed: _goToTodayCalendar,
                            icon: const Icon(Icons.my_location_outlined),
                            label: const Text('Astazi'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () {
                            // ignore: invalid_use_of_protected_member
                            setState(() {
                              final baseDate = useWeekAnchor
                                  ? _startOfWeekMonday(_calendarFocusDate)
                                  : _dateOnly(_calendarFocusDate);
                              _calendarFocusDate = DateTime(
                                baseDate.year,
                                baseDate.month,
                                baseDate.day + intervalStep,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                          label: Text(
                            visibleDayCount > 1
                                ? 'Interval urmator'
                                : 'Ziua urmatoare',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.schedule, size: 16),
                          label: Text(
                            'Interval baza: ${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00',
                          ),
                          onPressed: _editPlannerBaseRange,
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Zile:',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            for (final option in _ProgramariPageState._calendarVisibleDayOptions)
                              ChoiceChip(
                                label:
                                    Text(option == 1 ? '1 zi' : '$option zile'),
                                selected: visibleDayCount == option,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) async {
                                  // ignore: invalid_use_of_protected_member
                                  setState(() {
                                    _calendarVisibleDays = option;
                                    if (_calendarUsesWeekAnchor(option)) {
                                      _calendarFocusDate = _startOfWeekMonday(
                                          _calendarFocusDate);
                                    }
                                  });
                                  await _persistCalendarDisplayPreferences();
                                },
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Zoom:',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            for (final option in _ProgramariPageState._calendarZoomOptions)
                              ChoiceChip(
                                label: Text(option.value),
                                selected: _calendarZoom == option.key,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) async {
                                  // ignore: invalid_use_of_protected_member
                                  setState(() {
                                    _calendarZoom = option.key;
                                  });
                                  await _persistCalendarDisplayPreferences();
                                },
                              ),
                          ],
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            if (allVisibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nu exista programari pentru ${_calendarRangeLabel(visibleDays)}. Apasa pe un slot din planner pentru creare rapida.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is OverscrollNotification) {
                    _calendarOverscrollAccum += notification.overscroll;
                    if (_calendarOverscrollAccum > _ProgramariPageState._calendarOverscrollThreshold) {
                      _calendarOverscrollAccum = 0.0;
                      _goToNextCalendarInterval();
                    } else if (_calendarOverscrollAccum <
                        -_ProgramariPageState._calendarOverscrollThreshold) {
                      _calendarOverscrollAccum = 0.0;
                      _goToPreviousCalendarInterval();
                    }
                  } else if (notification is ScrollEndNotification) {
                    _calendarOverscrollAccum = 0.0;
                  }
                  return false;
                },
                child: SingleChildScrollView(
                controller: _calendarHorizontalScrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSpacing),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: timeColumnWidth + plannerWidth,
                  child: SingleChildScrollView(
                    controller: _calendarVerticalScrollController,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomSpacing),
                      child: SizedBox(
                        height: totalHeight + 52,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: timeColumnWidth,
                              child: Column(
                                children: [
                                  const SizedBox(height: 52),
                                  for (var hour = startHour;
                                      hour < endHour;
                                      hour++)
                                    SizedBox(
                                      height: hourHeight,
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${hour.toString().padLeft(2, '0')}:00',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  for (final day in visibleDays)
                                    Expanded(
                                      child: _calendarDayColumn(
                                        day: day,
                                        startHour: startHour,
                                        endHour: endHour,
                                        hourHeight: hourHeight,
                                        totalHeight: totalHeight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Benzi colorate de fundal pentru sloturile orare (09-12, 12-15, 15-18,
  /// 18-21). DOAR vizual — sub programări, fără interacțiune. Fiecare slot e
  /// limitat la intervalul vizibil [startHour, endHour) al coloanei.
  List<Widget> _calendarSlotBackgrounds({
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final widgets = <Widget>[];
    for (final slot in kProgramareSloturi) {
      final topHour = slot.startHour < startHour ? startHour : slot.startHour;
      final bottomHour = slot.endHour > endHour ? endHour : slot.endHour;
      if (bottomHour <= topHour) continue; // slot în afara intervalului vizibil
      final top = (topHour - startHour) * hourHeight;
      final height = (bottomHour - topHour) * hourHeight;
      widgets.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: IgnorePointer(
            child: ColoredBox(
              color: slot.backgroundColor.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Marcaje vizuale pentru sloturi: linii orizontale mai groase la limitele
  /// sloturilor (9/12/15/18/21) + etichetă mică „09-12" în colțul fiecărei
  /// benzi. DOAR vizual — IgnorePointer, deasupra grilei normale, sub programări.
  List<Widget> _calendarSlotMarkers({
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final widgets = <Widget>[];
    // Linii de separare la limitele sloturilor
    for (final hour in kProgramareSlotBoundaries) {
      if (hour < startHour || hour > endHour) continue;
      widgets.add(
        Positioned(
          top: (hour - startHour) * hourHeight,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 2,
              color: const Color(0xFF757575).withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }
    // Etichetă slot în colțul de sus al fiecărei benzi vizibile
    for (final slot in kProgramareSloturi) {
      final topHour = slot.startHour < startHour ? startHour : slot.startHour;
      final bottomHour = slot.endHour > endHour ? endHour : slot.endHour;
      if (bottomHour <= topHour) continue;
      widgets.add(
        Positioned(
          top: (topHour - startHour) * hourHeight + 3,
          left: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: slot.backgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF757575).withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                slot.rangeLabel,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _calendarDayColumn({
    required DateTime day,
    required int startHour,
    required int endHour,
    required double hourHeight,
    required double totalHeight,
  }) {
    final placements = _cachedPlacementsForDay(day);
    final isToday = _isSameDate(day, DateTime.now());
    final dayType = RomanianHolidays.getDayType(day);
    final isHolidayOrSunday =
        dayType == DayType.holiday || dayType == DayType.sunday;
    final isSatDay = dayType == DayType.saturday;
    final holidayLabel = RomanianHolidays.holidayName(day);

    return Container(
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.22)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.45)
              : isHolidayOrSunday
                  ? HolidayColors.sundayHolidayBorder
                  : isSatDay
                      ? HolidayColors.saturdayBorder
                      : Theme.of(context).dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Tooltip(
            message: _dayTooltipMessage(day, dayType),
            triggerMode: TooltipTriggerMode.longPress,
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isToday
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.9)
                  : isHolidayOrSunday
                      ? HolidayColors.sundayHoliday
                      : isSatDay
                          ? HolidayColors.saturday
                          : Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowHeader = constraints.maxWidth < 170;
                final todayColor =
                    Theme.of(context).colorScheme.onPrimaryContainer;
                final defaultColor = Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.7);
                final badgeColor = isToday
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12)
                    : defaultColor;
                final Color? headerTextColor = isToday
                    ? todayColor
                    : isHolidayOrSunday
                        ? HolidayColors.sundayHolidayText
                        : isSatDay
                            ? HolidayColors.saturdayText
                            : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNarrowHeader) ...[
                      // Mobil: numărul zilei mare, ziua mică, badge compact
                      Text(
                        '${day.day}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: headerTextColor,
                            ),
                      ),
                      Text(
                        DateFormat('EEE', 'ro_RO').format(day),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                      ),
                    ] else ...[
                      // Desktop: "lun.\n26 mai"
                      Text(
                        _calendarDayHeaderLabel(day),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: headerTextColor,
                            ),
                      ),
                      if (holidayLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          holidayLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday
                                ? todayColor
                                : HolidayColors.sundayHolidayText,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrowHeader ? 6 : 8,
                          vertical: isNarrowHeader ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isNarrowHeader
                              ? '${placements.length}'
                              : '${placements.length} programari',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: isNarrowHeader ? 10 : null,
                              ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Fundal ușor colorat pentru weekend/sărbători
                    if (isHolidayOrSunday)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: const Color(0xFFFFEBEE).withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    else if (isSatDay)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: const Color(0xFFFFF8E1).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    // Benzi colorate per slot orar (sub programări, fără interacțiune)
                    ..._calendarSlotBackgrounds(
                      startHour: startHour,
                      endHour: endHour,
                      hourHeight: hourHeight,
                    ),
                    if (_canCreateOperationalAppointments)
                      for (var hour = startHour; hour < endHour; hour++)
                        Positioned(
                          top: (hour - startHour) * hourHeight,
                          left: 0,
                          right: 0,
                          child: _calendarCreateSlot(
                            day: day,
                            hour: hour,
                            height: hourHeight,
                          ),
                        ),
                    for (var hour = startHour; hour <= endHour; hour++)
                      Positioned(
                        top: (hour - startHour) * hourHeight,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: hourHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Linii de separare sloturi + etichete (deasupra grilei,
                    // sub programări)
                    ..._calendarSlotMarkers(
                      startHour: startHour,
                      endHour: endHour,
                      hourHeight: hourHeight,
                    ),
                    for (final placement in placements)
                      _calendarBlock(
                        placement,
                        day: day,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: hourHeight,
                        columnWidth: constraints.maxWidth,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarBlock(
    CalendarPlacement placement, {
    required DateTime day,
    required int startHour,
    required int endHour,
    required double hourHeight,
    required double columnWidth,
  }) {
    final item = placement.item;
    final geometry = CalendarBlockGeometry.compute(
      placement: placement,
      day: day,
      startHour: startHour,
      endHour: endHour,
    );
    final top = geometry.startMinutes / 60 * hourHeight;
    final rawHeight =
        (geometry.endMinutes - geometry.startMinutes) / 60 * hourHeight;
    final height = rawHeight < 48 ? 48.0 : rawHeight;
    final continuesBefore = geometry.continuesBefore;
    final continuesAfter = geometry.continuesAfter;
    // Textul afișat pe card FOLOSEȘTE intervalul real al programării
    // (effectiveStart/EndDateTime), NU placement.visualStart/visualEnd
    // (clipate pe ziua curentă — corecte DOAR pentru geometria de mai sus,
    // top/height). Altfel, pe zilele intermediare/parțiale ale unei
    // programări multi-zi, ora de final clipată cade la miezul nopții și
    // produce texte greșite (ex: "09:00 - 00:00 • 15h" în loc de
    // intervalul real — regresie confirmată vizual, build92).
    final timeLineText = CalendarBlockTimeLabel.build(
      continuesBefore: continuesBefore,
      continuesAfter: continuesAfter,
      effectiveStart: item.effectiveStartDateTime,
      effectiveEnd: item.effectiveEndDateTime,
      formatTime: _formatTime,
      formatDate: _formatDate,
      durationLabel: _durationLabel,
    );
    final compact = height < 82;
    final veryCompact = height < 64;
    final title = item.title.trim().isEmpty
        ? _resolvedClientName(item.clientId, item.clientName)
        : item.title.trim();
    final secondary = _jobCode(item.jobId) == '-'
        ? _resolvedClientName(item.clientId, item.clientName)
        : _jobLabel(item.jobId);
    final assignmentSummary = _plannerAssignmentSummary(item);
    final accent = _appointmentAccentColor(item);
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = Theme.of(context).colorScheme.onSurfaceVariant;
    final background = _appointmentSurfaceColor(item);
    final itemClient = _resolvedClientName(item.clientId, item.clientName);
    final isRecurring = item.recurrenceRule != 'none' &&
        item.recurrenceRule.trim().isNotEmpty;
    final avatarData = _avatarDataForAppointment(item);
    final laneSpacing = placement.laneCount > 1 ? 6.0 : 0.0;
    final laneWidth = placement.laneCount == 1
        ? columnWidth
        : (columnWidth - ((placement.laneCount - 1) * laneSpacing)) /
            placement.laneCount;
    final leftInset = placement.laneIndex * (laneWidth + laneSpacing);
    final rightInset = columnWidth - leftInset - laneWidth;

    final showMinimalCard = height < 52;
    final showTimeLine = !showMinimalCard;
    final showStatusChip = !compact && placement.laneCount == 1 && height >= 96;
    final showSecondaryLine = !compact && height >= 88;
    final showAssignmentSummary = showSecondaryLine &&
        assignmentSummary.isNotEmpty &&
        placement.laneCount == 1 &&
        height >= 128;
    final showClientLine =
        showSecondaryLine && placement.laneCount == 1 && height >= 140;
    final showAddressLine =
        showSecondaryLine && placement.laneCount == 1 && height >= 152;

    Widget continuationIndicator({required bool atTop}) {
      return Positioned(
        top: atTop ? 2 : null,
        bottom: atTop ? null : 2,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                atTop ? Icons.expand_less : Icons.expand_more,
                size: 12,
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: top,
      left: leftInset,
      right: rightInset,
      height: height,
      child: Stack(
        children: [
          AppCard(
            elevated: true,
            accentColor: accent,
            color: background,
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: EdgeInsets.all(veryCompact ? 7 : (compact ? 8 : 10)),
            onTap: () => _openDetails(item),
            onLongPress: _canCreateAdministrativeAppointments
                ? () => _openEditor(appointment: item)
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: compact || height < 136 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (showStatusChip)
                      AppStatusChip(
                        label: _statusLabel(item.status),
                        status: _appStatusKindFor(item),
                      ),
                  ],
                ),
                if (showTimeLine) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    timeLineText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: veryCompact ? 11.5 : null,
                    ),
                  ),
                ],
                if (showSecondaryLine) ...[
                  if (isRecurring || avatarData.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    CalendarCardMetaRow(
                      isRecurring: isRecurring,
                      avatars: avatarData,
                      accentColor: accent,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (showAssignmentSummary) ...[
                    const SizedBox(height: 3),
                    Text(
                      assignmentSummary,
                      maxLines: height >= 164 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (showClientLine) ...[
                    const SizedBox(height: 3),
                    Text(
                      itemClient,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (showAddressLine) ...[
                      const SizedBox(height: 3),
                      Text(
                        _detailAddress(item),
                        maxLines: height >= 176 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: mutedForeground),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
          if (continuesBefore) continuationIndicator(atTop: true),
          if (continuesAfter) continuationIndicator(atTop: false),
        ],
      ),
    );
  }

  Widget _calendarCreateSlot({
    required DateTime day,
    required int hour,
    required double height,
  }) {
    final start = DateTime(day.year, day.month, day.day, hour);
    return Tooltip(
      message:
          'Creeaza programare la ${_formatDate(start)} ${_formatTime(start)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditorForCalendarSlot(start),
          child: Container(
            height: height,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Icon(
              Icons.add_circle_outline,
              size: 16,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
