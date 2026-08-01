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
}
