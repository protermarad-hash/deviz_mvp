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
    final totalDuration = effectiveEnd.difference(effectiveStart);
    if (!continuesBefore && !continuesAfter) {
      // Programare pe o singură zi — neschimbat.
      return '${formatTime(effectiveStart)} - ${formatTime(effectiveEnd)} • '
          '${durationLabel(totalDuration)}';
    }
    if (continuesBefore && continuesAfter) {
      // Zi intermediară, complet acoperită de bară: orele exacte sunt deja
      // vizibile pe prima/ultima zi + indicatorul "continuă" (▸/▾) —
      // repetarea lor identică pe fiecare zi intermediară nu adaugă
      // informație, doar durata totală.
      return 'Continuă • ${durationLabel(totalDuration)} total';
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
