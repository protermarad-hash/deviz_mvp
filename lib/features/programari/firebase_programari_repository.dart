import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'appointment_models.dart';
import 'programari_cloud_repository.dart';

class FirebaseProgramariRepository implements ProgramariCloudRepository {
  FirebaseProgramariRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.appointments);

  @override
  Future<void> deleteAppointment(String appointmentId) async {
    final id = appointmentId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
    // Write server-side tombstone so all devices (including old app versions)
    // will filter this appointment out on their next listAppointments() call.
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
    final docs = snapshot.docs;
    return docs
        .map((doc) => Appointment.fromMap(_normalizeAppointmentMap(doc.data())))
        .toList(growable: false);
  }

  @override
  Future<void> upsertAppointment(Appointment appointment) async {
    await _collection
        .doc(appointment.id)
        .set(_appointmentToCloudMap(appointment), SetOptions(merge: true));
  }

  @override
  Stream<List<Appointment>> watchAppointments() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              Appointment.fromMap(_normalizeAppointmentMap(doc.data())))
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _appointmentToCloudMap(Appointment item) {
    final payload = Map<String, dynamic>.from(item.toMap());
    payload['updated_at'] = DateTime.now().toIso8601String();
    return payload;
  }

  Map<String, dynamic> _normalizeAppointmentMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      ...raw,
      'id': (raw['id'] ?? '').toString(),
      'client_id': (raw['client_id'] ?? raw['clientId'] ?? '').toString(),
      'client_name': (raw['client_name'] ?? raw['clientName'] ?? '').toString(),
      'contracting_client_id':
          (raw['contracting_client_id'] ?? raw['contractingClientId'] ?? '')
              .toString(),
      'contracting_client_name':
          (raw['contracting_client_name'] ?? raw['contractingClientName'] ?? '')
              .toString(),
      'scheduled_date':
          (raw['scheduled_date'] ?? raw['scheduledDate'] ?? '').toString(),
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
      'intervention_price_currency':
          (raw['intervention_price_currency'] ??
                  raw['interventionPriceCurrency'] ??
                  'RON')
              .toString(),
      'admin_collected_amount':
          raw['admin_collected_amount'] ?? raw['adminCollectedAmount'] ?? 0,
      'admin_collected_currency':
          (raw['admin_collected_currency'] ??
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
      'material_usage': raw['material_usage'] ?? raw['materialUsage'] ?? const {},
    };
  }
}
