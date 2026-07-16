import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_requeue_policy.dart';

Appointment _appt(String id) => Appointment.fromMap({
      'id': id,
      'scheduled_date': '2026-07-16T00:00:00.000',
      'start_time': '08:00',
      'end_time': '10:00',
    });

void main() {
  group('planLocalOnlyRequeue — fix anti-resurecție', () {
    test('item confirmat (fără intrare în registru, fără pending) → verificare, NU re-queue', () {
      final plan = planLocalOnlyRequeue(
        localOnlyItems: [_appt('vechi-confirmat')],
        unconfirmedIds: <String>{},
        pendingUpsertIds: <String>{},
      );
      expect(plan.requeueNow, isEmpty);
      expect(plan.verifyExistence.map((a) => a.id), ['vechi-confirmat']);
    });

    test('item neconfirmat (creat offline) → re-queue, NU verificare', () {
      final plan = planLocalOnlyRequeue(
        localOnlyItems: [_appt('nou-offline')],
        unconfirmedIds: {'nou-offline'},
        pendingUpsertIds: <String>{},
      );
      expect(plan.requeueNow.map((a) => a.id), ['nou-offline']);
      expect(plan.verifyExistence, isEmpty);
    });

    test('item confirmat DAR cu upsert pending (editat offline) → re-queue', () {
      final plan = planLocalOnlyRequeue(
        localOnlyItems: [_appt('editat-offline')],
        unconfirmedIds: <String>{},
        pendingUpsertIds: {'editat-offline'},
      );
      expect(plan.requeueNow.map((a) => a.id), ['editat-offline']);
      expect(plan.verifyExistence, isEmpty);
    });

    test('mix realist → partiționare corectă', () {
      final plan = planLocalOnlyRequeue(
        localOnlyItems: [
          _appt('sters-remote'), // confirmat, fără pending → verificare
          _appt('nou-offline'), // neconfirmat → re-queue
          _appt('editat-offline'), // confirmat + pending → re-queue
          _appt('vechi-in-cloud'), // confirmat, fără pending → verificare
        ],
        unconfirmedIds: {'nou-offline'},
        pendingUpsertIds: {'editat-offline'},
      );
      expect(
        plan.requeueNow.map((a) => a.id).toSet(),
        {'nou-offline', 'editat-offline'},
      );
      expect(
        plan.verifyExistence.map((a) => a.id).toSet(),
        {'sters-remote', 'vechi-in-cloud'},
      );
    });

    test('lista goală → ambele goale', () {
      final plan = planLocalOnlyRequeue(
        localOnlyItems: const [],
        unconfirmedIds: {'x'},
        pendingUpsertIds: {'y'},
      );
      expect(plan.requeueNow, isEmpty);
      expect(plan.verifyExistence, isEmpty);
    });

    test('un item șters remote NU ajunge în re-queue (nucleul fix-ului)', () {
      // Scenariul central: programare ștearsă pe alt device, tombstone neajuns.
      // Este local-only (absentă din cloud), confirmată cândva, fără pending.
      // NU trebuie re-cozată (asta cauza resurecția), ci trimisă la verificare.
      final plan = planLocalOnlyRequeue(
        localOnlyItems: [_appt('programare-stearsa')],
        unconfirmedIds: <String>{}, // absent = confirmat implicit
        pendingUpsertIds: <String>{},
      );
      expect(
        plan.requeueNow.any((a) => a.id == 'programare-stearsa'),
        isFalse,
      );
      expect(plan.verifyExistence.map((a) => a.id), ['programare-stearsa']);
    });
  });
}
