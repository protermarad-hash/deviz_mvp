import 'appointment_models.dart';
import '../master/master_local_store.dart';

/// Id de coloană rezervat pentru programările fără nicio echipă cunoscută
/// (câmp gol sau echipă ștearsă între timp).
const String kUnassignedTeamColumnId = '__neasignat__';

/// Clasificator pur pentru vizualizarea "Pe echipe" a calendarului de
/// programări (testat: `test/programari_echipe_grouping_test.dart`).
///
/// Grupează [items] după echipele asignate ([Appointment.resolvedAssignedTeamIds]).
/// O programare cu 2+ echipe apare DUPLICATĂ în coloanele acelor echipe —
/// consecvent cu restul aplicației, care tratează echipele asignate ca set
/// de membership (`.contains()`), nu ca valoare unică. Programările fără
/// nicio echipă cunoscută (id lipsă sau echipă ștearsă) intră în coloana
/// [kUnassignedTeamColumnId].
///
/// Cheile rezultatului includ toate id-urile din [teams] (chiar dacă o
/// echipă nu are nicio programare în [items]) plus [kUnassignedTeamColumnId].
/// Fiecare listă e sortată cronologic după `effectiveStartDateTime`.
Map<String, List<Appointment>> groupAppointmentsByTeam(
  List<Appointment> items,
  List<MasterTeam> teams,
) {
  final knownTeamIds = teams.map((t) => t.id.trim()).toSet();
  final grouped = <String, List<Appointment>>{
    for (final team in teams) team.id: <Appointment>[],
    kUnassignedTeamColumnId: <Appointment>[],
  };

  for (final item in items) {
    final teamIds = <String>[];
    for (final raw in item.resolvedAssignedTeamIds) {
      final id = raw.trim();
      if (id.isEmpty || teamIds.contains(id) || !knownTeamIds.contains(id)) {
        continue;
      }
      teamIds.add(id);
    }
    if (teamIds.isEmpty) {
      grouped[kUnassignedTeamColumnId]!.add(item);
      continue;
    }
    for (final teamId in teamIds) {
      grouped[teamId]!.add(item);
    }
  }

  for (final list in grouped.values) {
    list.sort(
      (a, b) => a.effectiveStartDateTime.compareTo(b.effectiveStartDateTime),
    );
  }
  return grouped;
}
