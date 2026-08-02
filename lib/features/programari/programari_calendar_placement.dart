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
