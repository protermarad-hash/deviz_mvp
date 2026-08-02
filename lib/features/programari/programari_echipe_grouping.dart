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

/// Clasificator pur pentru drag & drop între coloane de echipă (etapa 3,
/// testat: `test/programari_echipe_grouping_test.dart`). Primește lista
/// curentă de echipe asignate ale programării trase (`currentTeamIds`,
/// ordinea rezultată din [Appointment.resolvedAssignedTeamIds]) și
/// coloana sursă/țintă a drag-ului, apoi întoarce noua listă de echipe.
///
/// Reguli (decizie de produs, etapa 3):
/// - `sourceColumnId == targetColumnId` → no-op, întoarce `currentTeamIds`
///   neschimbat (evită scrieri inutile în coada offline).
/// - Drop pe coloana unei echipe reale: elimină [sourceColumnId] din listă
///   (dacă era o echipă reală, nu [kUnassignedTeamColumnId]) și adaugă
///   [targetColumnId] dacă nu era deja prezent. Restul echipelor rămân
///   neatinse (ex: A+C, tragi din A în B → rezultat B+C).
/// - Drop pe [kUnassignedTeamColumnId]: elimină doar [sourceColumnId] din
///   listă, fără să adauge nimic (coloana Neasignat nu e o echipă reală).
/// - Drag din [kUnassignedTeamColumnId] către o echipă: lista sursă era
///   goală, doar adaugă [targetColumnId].
List<String> reassignTeamOnDrop({
  required List<String> currentTeamIds,
  required String sourceColumnId,
  required String targetColumnId,
}) {
  if (sourceColumnId == targetColumnId) {
    return currentTeamIds;
  }

  final result = <String>[
    for (final id in currentTeamIds)
      if (id != sourceColumnId) id,
  ];

  if (targetColumnId != kUnassignedTeamColumnId &&
      !result.contains(targetColumnId)) {
    result.add(targetColumnId);
  }

  return result;
}
