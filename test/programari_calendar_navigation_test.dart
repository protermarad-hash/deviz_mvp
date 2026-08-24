import 'package:devizpro_ultra/features/programari/programari_calendar_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresie pentru bug-ul: pasul de navigare "interval anterior"/"următor"
/// din calendarul Programări era hardcodat la 7 zile, indiferent de câte
/// zile sunt afișate curent (`_calendarVisibleDays`). Cu vizualizarea pe
/// 1 zi (implicit pe telefon din commit 82b572c), butonul "următor" sărea
/// 7 zile în loc de 1. Fixul: pasul = numărul de zile afișate curent,
/// pentru fiecare valoare din `_calendarVisibleDayOptions` (1/3/5/7).
void main() {
  group('CalendarIntervalNavigation — pasul de navigare == zile vizibile', () {
    // Miercuri, în interiorul unei săptămâni — alege intenționat o zi care
    // NU e luni, ca să nu mascheze accidental un bug de ancorare la luni.
    final focusDate = DateTime(2026, 8, 19);

    for (final visibleDayCount in [1, 3, 5, 7]) {
      test('$visibleDayCount zi(le) — "următor" mută cu exact $visibleDayCount zile', () {
        final next = CalendarIntervalNavigation.nextFocusDate(
          currentFocusDate: focusDate,
          visibleDayCount: visibleDayCount,
        );
        final baseDate = CalendarIntervalNavigation.usesWeekAnchor(visibleDayCount)
            ? CalendarIntervalNavigation.startOfWeekMonday(focusDate)
            : CalendarIntervalNavigation.dateOnly(focusDate);
        final expected = baseDate.add(Duration(days: visibleDayCount));
        expect(next, expected);
      });

      test('$visibleDayCount zi(le) — "anterior" mută cu exact $visibleDayCount zile', () {
        final previous = CalendarIntervalNavigation.previousFocusDate(
          currentFocusDate: focusDate,
          visibleDayCount: visibleDayCount,
        );
        final baseDate = CalendarIntervalNavigation.usesWeekAnchor(visibleDayCount)
            ? CalendarIntervalNavigation.startOfWeekMonday(focusDate)
            : CalendarIntervalNavigation.dateOnly(focusDate);
        final expected = baseDate.subtract(Duration(days: visibleDayCount));
        expect(previous, expected);
      });
    }

    test('vizualizare 1 zi: "următor" NU sare 7 zile (reproducerea exactă a bug-ului raportat)', () {
      final next = CalendarIntervalNavigation.nextFocusDate(
        currentFocusDate: focusDate,
        visibleDayCount: 1,
      );
      expect(next, DateTime(2026, 8, 20));
      expect(next, isNot(DateTime(2026, 8, 26)));
    });

    test('vizualizare 5 zile: "următor" avansează fereastra cu 5 zile, nu rămâne blocată în aceeași săptămână', () {
      // Cu ancorare la luni pentru orice dayCount > 1 (comportamentul VECHI,
      // greșit), pasul de 5 zile de la luni ar ateriza tot în aceeași
      // săptămână ISO (sâmbătă), iar la următorul render s-ar re-ancora la
      // ACEEAȘI luni -> navigarea ar părea "blocată". Fixul elimină
      // ancorarea la luni pentru 5 zile, deci fereastra chiar avansează.
      final next = CalendarIntervalNavigation.nextFocusDate(
        currentFocusDate: focusDate,
        visibleDayCount: 5,
      );
      expect(next, DateTime(2026, 8, 24));
      expect(CalendarIntervalNavigation.usesWeekAnchor(5), isFalse);
    });

    test('vizualizare 7 zile rămâne ancorată la luni (comportament neschimbat)', () {
      expect(CalendarIntervalNavigation.usesWeekAnchor(7), isTrue);
      final next = CalendarIntervalNavigation.nextFocusDate(
        currentFocusDate: focusDate,
        visibleDayCount: 7,
      );
      // Luni săptămâna curentă (17 aug 2026) + 7 zile = luni următoare.
      expect(next, DateTime(2026, 8, 24));
    });
  });
}
