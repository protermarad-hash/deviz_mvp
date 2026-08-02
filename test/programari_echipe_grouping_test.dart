import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/master/master_local_store.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/programari_echipe_grouping.dart';

Appointment _appt(
  String id, {
  String? teamId,
  List<String>? assignedTeamIds,
  String startTime = '08:00',
}) =>
    Appointment.fromMap({
      'id': id,
      'scheduled_date': '2026-07-16T00:00:00.000',
      'start_time': startTime,
      'end_time': '10:00',
      if (teamId != null) 'team_id': teamId,
      if (assignedTeamIds != null) 'assigned_team_ids': assignedTeamIds,
    });

const _echipaRosie = MasterTeam(
  id: 'echipa-rosie',
  name: 'Echipa Roșie',
  notes: '',
  memberIds: <String>[],
  colorValue: 0xFFD32F2F,
);

const _echipaAlbastra = MasterTeam(
  id: 'echipa-albastra',
  name: 'Echipa Albastră',
  notes: '',
  memberIds: <String>[],
);

void main() {
  group('groupAppointmentsByTeam — vizualizare Pe echipe', () {
    test('programare fără nicio echipă → coloana Neasignat', () {
      final grouped = groupAppointmentsByTeam(
        [_appt('fara-echipa')],
        [_echipaRosie, _echipaAlbastra],
      );
      expect(
        grouped[kUnassignedTeamColumnId]!.map((a) => a.id),
        ['fara-echipa'],
      );
      expect(grouped['echipa-rosie'], isEmpty);
      expect(grouped['echipa-albastra'], isEmpty);
    });

    test('programare cu o singură echipă cunoscută → apare doar în acea coloană', () {
      final grouped = groupAppointmentsByTeam(
        [_appt('prog-1', teamId: 'echipa-rosie')],
        [_echipaRosie, _echipaAlbastra],
      );
      expect(grouped['echipa-rosie']!.map((a) => a.id), ['prog-1']);
      expect(grouped['echipa-albastra'], isEmpty);
      expect(grouped[kUnassignedTeamColumnId], isEmpty);
    });

    test(
        'programare cu 2+ echipe (assignedTeamIds) → apare duplicată în ambele coloane',
        () {
      final grouped = groupAppointmentsByTeam(
        [
          _appt(
            'prog-multi',
            assignedTeamIds: ['echipa-rosie', 'echipa-albastra'],
          ),
        ],
        [_echipaRosie, _echipaAlbastra],
      );
      expect(grouped['echipa-rosie']!.map((a) => a.id), ['prog-multi']);
      expect(grouped['echipa-albastra']!.map((a) => a.id), ['prog-multi']);
      expect(grouped[kUnassignedTeamColumnId], isEmpty);
    });

    test('echipă ștearsă (id necunoscut) → tratată ca Neasignat, nu creează coloană nouă', () {
      final grouped = groupAppointmentsByTeam(
        [_appt('prog-orfan', teamId: 'echipa-stearsa')],
        [_echipaRosie],
      );
      expect(
        grouped[kUnassignedTeamColumnId]!.map((a) => a.id),
        ['prog-orfan'],
      );
      expect(grouped.containsKey('echipa-stearsa'), isFalse);
      expect(grouped.keys, containsAll(['echipa-rosie', kUnassignedTeamColumnId]));
    });

    test('rezultatul include toate echipele chiar dacă nu au programări', () {
      final grouped = groupAppointmentsByTeam([], [_echipaRosie, _echipaAlbastra]);
      expect(grouped.keys, {
        'echipa-rosie',
        'echipa-albastra',
        kUnassignedTeamColumnId,
      });
      expect(grouped.values.every((list) => list.isEmpty), isTrue);
    });

    test('programările din aceeași coloană sunt sortate cronologic', () {
      final grouped = groupAppointmentsByTeam(
        [
          _appt('tarziu', teamId: 'echipa-rosie', startTime: '15:00'),
          _appt('devreme', teamId: 'echipa-rosie', startTime: '08:00'),
        ],
        [_echipaRosie],
      );
      expect(
        grouped['echipa-rosie']!.map((a) => a.id),
        ['devreme', 'tarziu'],
      );
    });
  });

  group('reassignTeamOnDrop — drag & drop între coloane de echipă', () {
    test('A+C, tragi din A în B → rezultat B+C (restul echipelor neatinse)', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const ['echipa-a', 'echipa-c'],
        sourceColumnId: 'echipa-a',
        targetColumnId: 'echipa-b',
      );
      expect(result, containsAll(['echipa-b', 'echipa-c']));
      expect(result, isNot(contains('echipa-a')));
      expect(result.length, 2);
    });

    test('drag din coloană echipă → Neasignat: elimină doar echipa sursă, nu adaugă nimic', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const ['echipa-a'],
        sourceColumnId: 'echipa-a',
        targetColumnId: kUnassignedTeamColumnId,
      );
      expect(result, isEmpty);
    });

    test('drag din Neasignat → echipă B: lista era goală, doar adaugă B', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const [],
        sourceColumnId: kUnassignedTeamColumnId,
        targetColumnId: 'echipa-b',
      );
      expect(result, ['echipa-b']);
    });

    test('source == target: no-op explicit, întoarce lista neschimbată', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const ['echipa-a', 'echipa-c'],
        sourceColumnId: 'echipa-a',
        targetColumnId: 'echipa-a',
      );
      expect(result, ['echipa-a', 'echipa-c']);
    });

    test('source == target == Neasignat: no-op explicit', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const [],
        sourceColumnId: kUnassignedTeamColumnId,
        targetColumnId: kUnassignedTeamColumnId,
      );
      expect(result, isEmpty);
    });

    test('listă goală, drag dintr-o echipă (caz defensiv) → target adăugat, fără crash', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const [],
        sourceColumnId: 'echipa-a',
        targetColumnId: 'echipa-b',
      );
      expect(result, ['echipa-b']);
    });

    test('drop pe o echipă deja prezentă în listă (A+B, tragi din A în B) → doar B rămâne', () {
      final result = reassignTeamOnDrop(
        currentTeamIds: const ['echipa-a', 'echipa-b'],
        sourceColumnId: 'echipa-a',
        targetColumnId: 'echipa-b',
      );
      expect(result, ['echipa-b']);
    });
  });
}
