import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/programari_calendar_placement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test de regresie pentru bug-ul "programări existente, vizibile corect în
/// modul Listă, nu apar în modul Calendar" (investigat 2026-08-21).
///
/// Cauza reală confirmată vizual: NU lipsea nicio programare din datele
/// randate — `CalendarPlacement.computeForDay` produce exact un placement
/// per programare filtrată pentru ziua respectivă (fără nicio eliminare
/// silențioasă), la fel ca sursa comună `_filteredItems` folosită și de
/// Listă. Problema reală era vizuală: grila orară (poate acoperi până la
/// 16-20 ore, ex. 05:00-21:00) pornea mereu de la `startHour`, iar
/// programările de după-amiază/seară rămâneau sub fold, în afara zonei
/// vizibile fără scroll manual — ușor de confundat cu "nu apar".
///
/// Acest test verifică cele două invarianți care garantează comportamentul
/// corect, ca o regresie viitoare (ex. un filtru introdus greșit în
/// algoritmul de plasare, sau un auto-scroll care sare peste prima
/// programare) să pice testul, nu să fie descoperită iar în teren.
void main() {
  Appointment appointment({
    required String id,
    required DateTime start,
    required DateTime end,
  }) {
    return Appointment(
      id: id,
      clientId: 'client-1',
      title: 'Programare $id',
      location: 'Locatie test',
      scheduledDate: DateTime(start.year, start.month, start.day),
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      startDateTime: start,
      endDateTime: end,
      type: 'interventie',
      priority: 'normala',
      status: 'planificata',
    );
  }

  group('CalendarPlacement.computeForDay — nicio programare nu e eliminată',
      () {
    test('N programări filtrate pentru o zi -> exact N placements', () {
      final day = DateTime(2026, 8, 27);
      // Reproduce scenariul confirmat vizual: o programare la prânz și una
      // seara, în aceeași zi, fără suprapunere.
      final items = <Appointment>[
        appointment(
          id: 'a',
          start: DateTime(2026, 8, 27, 12, 0),
          end: DateTime(2026, 8, 27, 15, 0),
        ),
        appointment(
          id: 'b',
          start: DateTime(2026, 8, 27, 21, 0),
          end: DateTime(2026, 8, 28, 0, 0),
        ),
      ];

      final placements = CalendarPlacement.computeForDay(items, day);

      expect(placements.length, items.length,
          reason: 'fiecare programare filtrată pentru zi trebuie să '
              'producă exact un placement — nicio eliminare silențioasă');
      expect(placements.map((p) => p.item.id).toSet(), {'a', 'b'});
    });

    test('programări suprapuse -> tot N placements, doar benzi diferite',
        () {
      final day = DateTime(2026, 8, 27);
      final items = <Appointment>[
        appointment(
          id: 'x',
          start: DateTime(2026, 8, 27, 9, 0),
          end: DateTime(2026, 8, 27, 11, 0),
        ),
        appointment(
          id: 'y',
          start: DateTime(2026, 8, 27, 10, 0),
          end: DateTime(2026, 8, 27, 12, 0),
        ),
        appointment(
          id: 'z',
          start: DateTime(2026, 8, 27, 10, 30),
          end: DateTime(2026, 8, 27, 11, 30),
        ),
      ];

      final placements = CalendarPlacement.computeForDay(items, day);

      expect(placements.length, 3);
      expect(placements.map((p) => p.item.id).toSet(), {'x', 'y', 'z'});
      // Cel puțin 2 benzi distincte, pentru că cele 3 se suprapun parțial.
      expect(placements.first.laneCount, greaterThanOrEqualTo(2));
    });

    test('listă goală -> listă goală, fără erori', () {
      final placements =
          CalendarPlacement.computeForDay(const [], DateTime(2026, 8, 27));
      expect(placements, isEmpty);
    });
  });

  group('calendarVerticalAutoScrollOffsetMinutes — auto-scroll la prima '
      'programare a intervalului vizibil', () {
    test('earliestHour == startHour -> offset 0 (deja la vârf)', () {
      final minutes = calendarVerticalAutoScrollOffsetMinutes(
        startHour: 8,
        earliestHour: 8,
      );
      expect(minutes, 0);
    });

    test(
        'earliestHour > startHour (grid extins peste plannerBase) -> offset '
        'pozitiv care sare direct la prima programare', () {
      // Reproduce exact scenariul confirmat vizual: interval bază 05:00,
      // prima programare a zilei la 12:00 -> fără fix, utilizatorul vedea
      // doar 05:00-12:00 gol și trebuia să descopere singur scroll-ul.
      final minutes = calendarVerticalAutoScrollOffsetMinutes(
        startHour: 5,
        earliestHour: 12,
      );
      expect(minutes, 7 * 60);
    });

    test('earliestHour < startHour nu ar trebui să apară în practică '
        '(startHour = min(earliestHour, plannerBase)), dar formula rămâne '
        'coerentă dacă s-ar întâmpla', () {
      final minutes = calendarVerticalAutoScrollOffsetMinutes(
        startHour: 10,
        earliestHour: 8,
      );
      expect(minutes, -2 * 60);
    });
  });
}
