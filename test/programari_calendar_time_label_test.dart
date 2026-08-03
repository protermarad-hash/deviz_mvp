import 'package:devizpro_ultra/features/programari/programari_calendar_placement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testează `CalendarBlockTimeLabel.build` — textul de interval/durată
/// afișat pe cardul din planner (linia de sub titlu).
///
/// Regresie (build92): textul folosea `placement.visualStart`/`visualEnd`
/// (clipate pe ziua randată) în loc de intervalul REAL al programării —
/// pe zilele intermediare/parțiale ale unei programări multi-zi, ora de
/// final clipată cădea la miezul nopții și producea texte greșite
/// (ex. "09:00 - 00:00 • 15h" în loc de intervalul real). Testele de mai
/// jos verifică explicit că prima zi/zi intermediară/ultima zi ale unei
/// programări multi-zi (3 săptămâni) arată intervalul real (sau varianta
/// îmbunătățită pentru zilele intermediare), și că o programare pe o
/// singură zi rămâne neschimbată.
void main() {
  String formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  String durationLabel(Duration duration) {
    if (duration.inMinutes <= 0) return '0 min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  group('CalendarBlockTimeLabel.build — programare multi-zi (3 săptămâni)', () {
    // 03.08.2026 09:00 -> 24.08.2026 12:00 (~3 săptămâni).
    final effectiveStart = DateTime(2026, 8, 3, 9, 0);
    final effectiveEnd = DateTime(2026, 8, 24, 12, 0);
    final totalDuration = effectiveEnd.difference(effectiveStart);

    test('prima zi: ora reală de start + data/ora reală de final, NU miezul nopții', () {
      final text = CalendarBlockTimeLabel.build(
        continuesBefore: false,
        continuesAfter: true,
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        formatTime: formatTime,
        formatDate: formatDate,
        durationLabel: durationLabel,
      );

      // NU trebuie să conțină "00:00" (ora clipată greșit) sau "15h".
      expect(text, isNot(contains('00:00')));
      expect(text, isNot(contains('15h')));
      expect(text, contains('09:00'));
      expect(text, contains('24.08.2026'));
      expect(text, contains('12:00'));
    });

    test('zi intermediară completă: NU repetă "00:00 - 00:00", arată durata totală', () {
      final text = CalendarBlockTimeLabel.build(
        continuesBefore: true,
        continuesAfter: true,
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        formatTime: formatTime,
        formatDate: formatDate,
        durationLabel: durationLabel,
      );

      // NU trebuie să conțină textul greșit "00:00 - 00:00 • 24h".
      expect(text, isNot(contains('00:00 - 00:00')));
      expect(text, isNot(contains('24h')));
      expect(text, contains('Continuă'));
      expect(text, contains(durationLabel(totalDuration)));
    });

    test('ultima zi: data/ora reală de start + ora reală de final', () {
      final text = CalendarBlockTimeLabel.build(
        continuesBefore: true,
        continuesAfter: false,
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        formatTime: formatTime,
        formatDate: formatDate,
        durationLabel: durationLabel,
      );

      expect(text, contains('03.08.2026'));
      expect(text, contains('09:00'));
      expect(text, contains('12:00'));
    });
  });

  group('CalendarBlockTimeLabel.build — programare pe o singură zi', () {
    test('text neschimbat: ora start - ora final • durată', () {
      final effectiveStart = DateTime(2026, 8, 4, 9, 0);
      final effectiveEnd = DateTime(2026, 8, 4, 12, 0);

      final text = CalendarBlockTimeLabel.build(
        continuesBefore: false,
        continuesAfter: false,
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        formatTime: formatTime,
        formatDate: formatDate,
        durationLabel: durationLabel,
      );

      expect(text, '09:00 - 12:00 • 3h');
    });

    test('nu suferă regresie chiar dacă durata e scurtă (30 min)', () {
      final effectiveStart = DateTime(2026, 8, 4, 9, 0);
      final effectiveEnd = DateTime(2026, 8, 4, 9, 30);

      final text = CalendarBlockTimeLabel.build(
        continuesBefore: false,
        continuesAfter: false,
        effectiveStart: effectiveStart,
        effectiveEnd: effectiveEnd,
        formatTime: formatTime,
        formatDate: formatDate,
        durationLabel: durationLabel,
      );

      expect(text, '09:00 - 09:30 • 30m');
    });
  });
}
