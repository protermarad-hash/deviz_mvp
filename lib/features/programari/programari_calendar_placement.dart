import 'appointment_models.dart';

/// Plasarea unei programări în grila calendarului (zi cu mai multe programări
/// suprapuse). Calculează banda (lane) și intervalul vizual ocupat.
class CalendarPlacement {
  const CalendarPlacement({
    required this.item,
    required this.laneIndex,
    required this.laneCount,
    required this.visualStart,
    required this.visualEnd,
  });

  final Appointment item;
  final int laneIndex;
  final int laneCount;
  final DateTime visualStart;
  final DateTime visualEnd;

  /// Calculează plasamentele (bandă + interval vizual clipat pe zi) pentru
  /// toate programările unei zile. Funcție PURĂ — nu depinde de state-ul
  /// paginii — extrasă din `_ProgramariCalendarViewX._calendarPlacementsForDay`
  /// ca să poată fi testată direct fără a instanția widget-ul.
  ///
  /// Randează exact un [CalendarPlacement] per item din [items] (1:1, fără
  /// să elimine niciun item) — [items] trebuie să fie deja filtrat pentru
  /// ziua [day] (ex. rezultatul `_calendarItemsForDate(day)`).
  static List<CalendarPlacement> computeForDay(
    List<Appointment> items,
    DateTime day,
  ) {
    if (items.isEmpty) {
      return const <CalendarPlacement>[];
    }
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final placements = <CalendarPlacement>[];
    var index = 0;
    while (index < items.length) {
      final clusterItems = <Appointment>[items[index]];
      var clusterEnd = items[index].effectiveEndDateTime;
      var cursor = index + 1;
      while (cursor < items.length) {
        final next = items[cursor];
        if (!next.effectiveStartDateTime.isBefore(clusterEnd)) {
          break;
        }
        clusterItems.add(next);
        if (next.effectiveEndDateTime.isAfter(clusterEnd)) {
          clusterEnd = next.effectiveEndDateTime;
        }
        cursor++;
      }

      final laneEndTimes = <DateTime>[];
      final laneById = <String, int>{};
      for (final item in clusterItems) {
        var laneIndex = 0;
        while (laneIndex < laneEndTimes.length &&
            item.effectiveStartDateTime.isBefore(laneEndTimes[laneIndex])) {
          laneIndex++;
        }
        if (laneIndex == laneEndTimes.length) {
          laneEndTimes.add(item.effectiveEndDateTime);
        } else {
          laneEndTimes[laneIndex] = item.effectiveEndDateTime;
        }
        laneById[item.id] = laneIndex;
      }

      final laneCount = laneEndTimes.length.clamp(1, 12);
      for (final item in clusterItems) {
        final clippedStart = item.effectiveStartDateTime.isBefore(dayStart)
            ? dayStart
            : item.effectiveStartDateTime;
        final clippedEnd = item.effectiveEndDateTime.isAfter(dayEnd)
            ? dayEnd
            : item.effectiveEndDateTime;
        placements.add(
          CalendarPlacement(
            item: item,
            laneIndex: laneById[item.id] ?? 0,
            laneCount: laneCount,
            visualStart: clippedStart,
            visualEnd:
                clippedEnd.isBefore(clippedStart) ? clippedStart : clippedEnd,
          ),
        );
      }

      index = cursor;
    }
    return placements;
  }
}

/// Calculează offset-ul vertical (în pixeli logici) la care trebuie
/// scrollat automat planner-ul, astfel încât prima programare a
/// intervalului vizibil să fie imediat vizibilă, fără scroll manual.
/// Funcție PURĂ, extrasă pentru testare directă.
int calendarVerticalAutoScrollOffsetMinutes({
  required int startHour,
  required int earliestHour,
}) {
  return (earliestHour - startHour) * 60;
}

/// Geometria (poziție verticală + indicatori de continuare) unui bloc de
/// programare randat pe o coloană de zi a planner-ului. Calculul e făcut în
/// minute față de miezul nopții zilei randate (`day`), NU față de `.hour`
/// brut al `visualStart`/`visualEnd` — pentru zilele intermediare complet
/// acoperite de o programare multi-zi, `visualEnd` este miezul nopții zilei
/// URMĂTOARE (`.hour == 0`), ceea ce ar produce o înălțime greșită dacă am
/// folosi `.hour` direct în loc de diferența față de `dayStart`.
class CalendarBlockGeometry {
  const CalendarBlockGeometry({
    required this.startMinutes,
    required this.endMinutes,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  /// Minute de la începutul grilei (startHour) până la începutul barei,
  /// clampate la intervalul vizibil al planner-ului [0, endHour-startHour].
  final int startMinutes;

  /// Minute de la începutul grilei până la sfârșitul barei, clampate la fel.
  final int endMinutes;

  /// Bara e tăiată la început (programarea a început înainte de această zi).
  final bool continuesBefore;

  /// Bara e tăiată la final (programarea continuă și în ziua următoare).
  final bool continuesAfter;

  static CalendarBlockGeometry compute({
    required CalendarPlacement placement,
    required DateTime day,
    required int startHour,
    required int endHour,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final gridStartMinutes = startHour * 60;
    final gridEndMinutes = endHour * 60;
    final gridSpan = gridEndMinutes - gridStartMinutes;
    final rawStartMinutes =
        placement.visualStart.difference(dayStart).inMinutes -
            gridStartMinutes;
    final rawEndMinutes =
        placement.visualEnd.difference(dayStart).inMinutes - gridStartMinutes;
    return CalendarBlockGeometry(
      startMinutes: rawStartMinutes.clamp(0, gridSpan),
      endMinutes: rawEndMinutes.clamp(0, gridSpan),
      continuesBefore:
          placement.visualStart != placement.item.effectiveStartDateTime,
      continuesAfter:
          placement.visualEnd != placement.item.effectiveEndDateTime,
    );
  }
}

/// Textul de interval/durată afișat pe cardul din planner (linia de sub
/// titlu). FOLOSEȘTE intervalul REAL al programării
/// (`effectiveStart`/`effectiveEnd`), NU `placement.visualStart`/
/// `visualEnd` (clipate pe ziua randată — corecte doar pentru geometria
/// verticală din [CalendarBlockGeometry], nu pentru text). Pe zilele
/// intermediare/parțiale ale unei programări multi-zi, folosirea valorilor
/// clipate producea texte greșite (ex. "09:00 - 00:00 • 15h" în loc de
/// intervalul real — regresie confirmată vizual, build92).
class CalendarBlockTimeLabel {
  const CalendarBlockTimeLabel._();

  static String build({
    required bool continuesBefore,
    required bool continuesAfter,
    required DateTime effectiveStart,
    required DateTime effectiveEnd,
    required String Function(DateTime value) formatTime,
    required String Function(DateTime value) formatDate,
    required String Function(Duration duration) durationLabel,
  }) {
    if (!continuesBefore && !continuesAfter) {
      // Programare pe o singură zi — neschimbat.
      final totalDuration = effectiveEnd.difference(effectiveStart);
      return '${formatTime(effectiveStart)} - ${formatTime(effectiveEnd)} • '
          '${durationLabel(totalDuration)}';
    }
    if (continuesBefore && continuesAfter) {
      // Zi intermediară, complet acoperită de bară: o durată brută în ore
      // (ex. "504h 03m") nu e utilă pentru lucrări de săptămâni — orientăm
      // afișarea pe DATA reală de final, mult mai citibilă instant.
      return 'Continuă până ${formatDate(effectiveEnd)}';
    }
    if (!continuesBefore && continuesAfter) {
      // Prima zi: ora reală de start + data/ora reală unde se termină
      // programarea (nu "până la miezul nopții").
      return '${formatTime(effectiveStart)} → '
          '${formatDate(effectiveEnd)} ${formatTime(effectiveEnd)}';
    }
    // Ultima zi: data/ora reală de start + ora reală de final.
    return '${formatDate(effectiveStart)} ${formatTime(effectiveStart)} → '
        '${formatTime(effectiveEnd)}';
  }
}
