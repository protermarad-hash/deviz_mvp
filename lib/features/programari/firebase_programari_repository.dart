import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/cloud/revision_sync.dart';
import 'appointment_models.dart';
import 'programari_cloud_repository.dart';

class FirebaseProgramariRepository implements ProgramariCloudRepository {
  FirebaseProgramariRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.appointments);

  /// Ștergere condiționată (RC 121): se șterge doar dacă serverul este încă
  /// versiunea văzută de acest dispozitiv; altfel `RevisionConflictException`
  /// (`delete_vs_remote_edit`) și NU se scrie markerul de ștergere.
  @override
  Future<void> deleteAppointment(String appointmentId) async {
    final id = appointmentId.trim();
    if (id.isEmpty) return;
    await RevisionWriter.standard(firestore: _firestore).delete(
      type: CloudEntityType.appointments,
      collection: FirebaseCollections.appointments,
      id: id,
      keysFor: writerKeysFor,
    );
    // Marker pentru celelalte dispozitive (inclusiv versiunile vechi), DOAR după
    // o ștergere acceptată de server.
    try {
      await _firestore
          .collection(FirebaseCollections.deletedAppointments)
          .doc(id)
          .set({'deletedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Best-effort — the primary delete already succeeded.
    }
  }

  @override
  Future<List<Appointment>> listAppointments() async {
    final snapshot = await _collection.get();
    await recordServerBases(snapshot.docs, isFromCache: snapshot.metadata.isFromCache);
    final docs = snapshot.docs;
    return docs
        .map((doc) => Appointment.fromMap(
              _normalizeAppointmentMap(doc.data(), documentId: doc.id),
            ))
        .toList(growable: false);
  }

  /// Scriere condiționată de revizie (RC 121): la conflict nu se scrie nimic,
  /// ambele variante se păstrează (`RevisionConflictException`).
  @override
  Future<void> upsertAppointment(Appointment appointment) async {
    final id = appointment.id.trim();
    if (id.isEmpty) return;
    await RevisionWriter.standard(firestore: _firestore).upsert(
      type: CloudEntityType.appointments,
      collection: FirebaseCollections.appointments,
      id: id,
      data: _appointmentToCloudMap(appointment),
      startRev: appointment.syncRev,
    );
  }

  /// Cheile scrise de versiunea curentă (aceleași pentru bază și pentru decizie).
  static Iterable<String> writerKeysFor(Map<String, dynamic> serverData) =>
      cloudMapFor(Appointment.fromMap(<String, dynamic>{
        ...serverData,
        'id': (serverData['id'] ?? '').toString(),
      })).keys;

  /// Bazele de revizie din citiri confirmate de server (nu din cache și nu din
  /// scrieri locale în așteptare); programările protejate nu sunt atinse. Se
  /// folosește și de interogările din `LocalAppDataRepository`.
  static Future<void> recordServerBases(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool isFromCache,
    FirebaseFirestore? firestore,
  }) async {
    try {
      if (isFromCache) return;
      final byId = <String, Map<String, dynamic>>{
        for (final doc in docs)
          if (doc.exists && !doc.metadata.hasPendingWrites && doc.data() != null)
            doc.id: doc.data()!,
      };
      if (byId.isEmpty) return;
      await runEntitySyncLocked(CloudEntityType.appointments, () async =>
          RevisionWriter.standard(firestore: firestore).recordServerBases(
            type: CloudEntityType.appointments,
            serverDocs: byId,
            keysFor: writerKeysFor,
            protectedIds: await OfflineSyncRuntime.instance
                .protectedEntityIds(CloudEntityType.appointments),
          ));
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    }
  }

  @override
  Stream<List<Appointment>> watchAppointments() {
    return _collection.snapshots().asyncMap((snapshot) async {
      await recordServerBases(snapshot.docs, isFromCache: snapshot.metadata.isFromCache);
      return snapshot.docs
          .map((doc) => Appointment.fromMap(
                _normalizeAppointmentMap(doc.data(), documentId: doc.id),
              ))
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _appointmentToCloudMap(Appointment item) => cloudMapFor(item);

  /// Payload-ul scris în cloud (aceeași funcție pentru scriere, bază și teste).
  @visibleForTesting
  static Map<String, dynamic> cloudMapFor(Appointment item) {
    final payload = Map<String, dynamic>.from(item.toMap());
    // `_rev` îl scrie RevisionWriter (revizia nouă), nu payload-ul.
    payload.remove(kRevField);
    payload['updated_at'] = DateTime.now().toIso8601String();
    return payload;
  }

  Map<String, dynamic> _normalizeAppointmentMap(
    Map<String, dynamic> raw, {
    required String documentId,
  }) {
    return <String, dynamic>{
      ...raw,
      'id': (raw['id'] ?? documentId).toString(),
      'client_id': (raw['client_id'] ?? raw['clientId'] ?? '').toString(),
      'client_name': (raw['client_name'] ?? raw['clientName'] ?? '').toString(),
      'contracting_client_id':
          (raw['contracting_client_id'] ?? raw['contractingClientId'] ?? '')
              .toString(),
      'contracting_client_name':
          (raw['contracting_client_name'] ?? raw['contractingClientName'] ?? '')
              .toString(),
      'scheduled_date':
          raw['scheduled_date'] ?? raw['scheduledDate'] ?? raw['date'] ?? '',
      'start_time': (raw['start_time'] ?? raw['startTime'] ?? '').toString(),
      'end_time': (raw['end_time'] ?? raw['endTime'] ?? '').toString(),
      'start_date_time':
          (raw['start_date_time'] ?? raw['startDateTime'] ?? '').toString(),
      'end_date_time':
          (raw['end_date_time'] ?? raw['endDateTime'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'assigned_team_ids': raw['assigned_team_ids'] ??
          raw['assignedTeamIds'] ??
          const <String>[],
      'assigned_user_id':
          (raw['assigned_user_id'] ?? raw['assignedUserId'] ?? '').toString(),
      'assigned_user_email':
          (raw['assigned_user_email'] ?? raw['assignedUserEmail'] ?? '')
              .toString(),
      'assigned_employee_ids': raw['assigned_employee_ids'] ??
          raw['assignedEmployeeIds'] ??
          const <String>[],
      'vehicle_id': (raw['vehicle_id'] ?? raw['vehicleId'] ?? '').toString(),
      'job_id': (raw['job_id'] ?? raw['jobId'] ?? '').toString(),
      'complaint_id':
          (raw['complaint_id'] ?? raw['complaintId'] ?? '').toString(),
      'complaint_number':
          (raw['complaint_number'] ?? raw['complaintNumber'] ?? '').toString(),
      'for_partner_id':
          (raw['for_partner_id'] ?? raw['forPartnerId'] ?? '').toString(),
      'for_partner_name':
          (raw['for_partner_name'] ?? raw['forPartnerName'] ?? '').toString(),
      'executing_partner_id':
          (raw['executing_partner_id'] ?? raw['executingPartnerId'] ?? '')
              .toString(),
      'executing_partner_name':
          (raw['executing_partner_name'] ?? raw['executingPartnerName'] ?? '')
              .toString(),
      'equipment_description':
          (raw['equipment_description'] ?? raw['equipmentDescription'] ?? '')
              .toString(),
      'intervention_price':
          raw['intervention_price'] ?? raw['interventionPrice'] ?? 0,
      'intervention_price_currency': (raw['intervention_price_currency'] ??
              raw['interventionPriceCurrency'] ??
              'RON')
          .toString(),
      'admin_collected_amount':
          raw['admin_collected_amount'] ?? raw['adminCollectedAmount'] ?? 0,
      'admin_collected_currency': (raw['admin_collected_currency'] ??
              raw['adminCollectedCurrency'] ??
              'RON')
          .toString(),
      'admin_financial_status':
          (raw['admin_financial_status'] ?? raw['adminFinancialStatus'] ?? '')
              .toString(),
      'admin_due_date':
          (raw['admin_due_date'] ?? raw['adminDueDate'] ?? '').toString(),
      'admin_financial_notes':
          (raw['admin_financial_notes'] ?? raw['adminFinancialNotes'] ?? '')
              .toString(),
      'material_usage':
          raw['material_usage'] ?? raw['materialUsage'] ?? const {},
    };
  }
}
