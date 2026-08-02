import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/programari_calendar_placement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testează `CalendarBlockGeometry.compute` — logica de poziționare
/// verticală a barelor din calendarul planner-ului, extrasă din
/// `_calendarBlock` pentru a fi testabilă independent de widget tree.
///
/// Reproduce manual clipping-ul făcut de `_calendarPlacementsForDay`
/// (visualStart/visualEnd = intersecția intervalului programării cu ziua
/// randată) pentru fiecare scenariu, la fel cum ar face-o codul real.
void main() {
  const startHour = 8;
  const endHour = 19; // planner: 08:00 - 19:00

  Appointment multiDayAppointment({
    required DateTime start,
    required DateTime end,
  }) {
    return Appointment(
      id: 'multi-day-appt',
      clientId: 'client-1',
      title: 'Interventie multi-zi',
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
      status: 'programata',
    );
  }

  CalendarPlacement placementClippedTo(Appointment item, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final clippedStart = item.effectiveStartDateTime.isBefore(dayStart)
        ? dayStart
        : item.effectiveStartDateTime;
    final clippedEnd = item.effectiveEndDateTime.isAfter(dayEnd)
        ? dayEnd
        : item.effectiveEndDateTime;
    return CalendarPlacement(
      item: item,
      laneIndex: 0,
      laneCount: 1,
      visualStart: clippedStart,
      visualEnd: clippedEnd.isBefore(clippedStart) ? clippedStart : clippedEnd,
    );
  }

  group('CalendarBlockGeometry.compute — programare pe 4 zile', () {
    // 21.08 14:00 -> 24.08 10:00: prima zi parțială, două zile intermediare
    // complet acoperite, ultima zi parțială.
    final start = DateTime(2026, 8, 21, 14, 0);
    final end = DateTime(2026, 8, 24, 10, 0);
    final item = multiDayAppointment(start: start, end: end);

    test('prima zi: bara începe la ora reală de start, se termină la endHour, continuă după', () {
      final day = DateTime(2026, 8, 21);
      final placement = placementClippedTo(item, day);
      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      // 14:00 -> (14-8)*60 = 360 minute de la începutul grilei.
      expect(geometry.startMinutes, 360);
      // Clipat la sfârșitul grilei: (19-8)*60 = 660.
      expect(geometry.endMinutes, 660);
      expect(geometry.continuesBefore, isFalse);
      expect(geometry.continuesAfter, isTrue);
    });

    test('zi intermediară completă (22.08): bara umple exact startHour-endHour', () {
      final day = DateTime(2026, 8, 22);
      final placement = placementClippedTo(item, day);
      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.startMinutes, 0);
      expect(geometry.endMinutes, (endHour - startHour) * 60);
      expect(geometry.continuesBefore, isTrue);
      expect(geometry.continuesAfter, isTrue);
    });

    test('a doua zi intermediară completă (23.08): tot intervalul grilei', () {
      final day = DateTime(2026, 8, 23);
      final placement = placementClippedTo(item, day);
      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.startMinutes, 0);
      expect(geometry.endMinutes, (endHour - startHour) * 60);
      expect(geometry.continuesBefore, isTrue);
      expect(geometry.continuesAfter, isTrue);
    });

    test('ultima zi (24.08): bara începe la startHour, se termină la ora reală de final', () {
      final day = DateTime(2026, 8, 24);
      final placement = placementClippedTo(item, day);
      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.startMinutes, 0);
      // 10:00 -> (10-8)*60 = 120 minute.
      expect(geometry.endMinutes, 120);
      expect(geometry.continuesBefore, isTrue);
      expect(geometry.continuesAfter, isFalse);
    });
  });

  group('CalendarBlockGeometry.compute — cazul limită miezul nopții', () {
    test('programare ce se termină exact la 00:00 (ziua următoare): fără indicator de continuare', () {
      // 23.08 08:00 -> 24.08 00:00 (exact miezul nopții).
      final start = DateTime(2026, 8, 23, 8, 0);
      final end = DateTime(2026, 8, 24, 0, 0);
      final item = multiDayAppointment(start: start, end: end);
      final day = DateTime(2026, 8, 23);
      final placement = placementClippedTo(item, day);

      // dayEnd (24.08 00:00) nu e strict "after" de effectiveEnd (24.08
      // 00:00), deci NU se clipează — visualEnd rămâne exact effectiveEnd.
      expect(placement.visualEnd, end);

      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.continuesAfter, isFalse);
      expect(geometry.startMinutes, 0);
      expect(geometry.endMinutes, (endHour - startHour) * 60);
    });

    test('programare ce se termină la 23:59 în aceeași zi: fără indicator de continuare', () {
      final start = DateTime(2026, 8, 23, 8, 0);
      final end = DateTime(2026, 8, 23, 23, 59);
      final item = multiDayAppointment(start: start, end: end);
      final day = DateTime(2026, 8, 23);
      final placement = placementClippedTo(item, day);

      expect(placement.visualEnd, end);

      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.continuesAfter, isFalse);
    });
  });

  group('CalendarBlockGeometry.compute — programare pe o singură zi', () {
    test('nu afișează niciun indicator de continuare', () {
      final start = DateTime(2026, 8, 21, 9, 0);
      final end = DateTime(2026, 8, 21, 11, 0);
      final item = multiDayAppointment(start: start, end: end);
      final day = DateTime(2026, 8, 21);
      final placement = placementClippedTo(item, day);

      final geometry = CalendarBlockGeometry.compute(
        placement: placement,
        day: day,
        startHour: startHour,
        endHour: endHour,
      );

      expect(geometry.continuesBefore, isFalse);
      expect(geometry.continuesAfter, isFalse);
      expect(geometry.startMinutes, 60); // (9-8)*60
      expect(geometry.endMinutes, 180); // (11-8)*60
    });
  });
}
