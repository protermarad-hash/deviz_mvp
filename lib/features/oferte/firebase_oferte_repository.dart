import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/cloud/revision_sync.dart';
import 'offer_models.dart';
import 'oferte_cloud_repository.dart';

class FirebaseOferteRepository implements OferteCloudRepository {
  FirebaseOferteRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.offers);

  @override
  Future<void> deleteOffer(String offerId) async {
    final id = offerId.trim();
    if (id.isEmpty) return;
    // Ștergere condiționată: nu se șterge o versiune modificată între timp de alt dispozitiv.
    await RevisionWriter.standard(firestore: _firestore).delete(
        type: CloudEntityType.offers, collection: FirebaseCollections.offers, id: id,
        keysFor: (data) => _offerToCloudMap(OfferRecord.fromMap(_normalizeOfferMap(data))).keys);
  }

  @override
  Future<List<OfferRecord>> listOffers() async {
    final snapshot = await _collection.get();
    await _recordBases(snapshot);
    return snapshot.docs
        .map((doc) => OfferRecord.fromMap(_normalizeOfferMap(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertOffer(OfferRecord offer) async {
    final id = offer.id.trim();
    if (id.isEmpty) return;
    // Scriere condiționată de revizie (tranzacție): la conflict nu se scrie nimic
    // și ambele variante se păstrează (RevisionConflictException).
    await RevisionWriter.standard(firestore: _firestore).upsert(
      type: CloudEntityType.offers,
      collection: FirebaseCollections.offers,
      id: id,
      data: _offerToCloudMap(offer),
      startRev: offer.syncRev,
    );
  }

  @override
  Stream<List<OfferRecord>> watchOffers() {
    return _collection.snapshots().asyncMap((snapshot) async {
      await _recordBases(snapshot);
      return snapshot.docs
          .map((doc) => OfferRecord.fromMap(_normalizeOfferMap(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  /// Baza de revizie din citiri confirmate de server (nu din cache și nu din
  /// scrieri locale în așteptare); entitățile protejate nu sunt atinse.
  Future<void> _recordBases(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    try {
      if (snapshot.metadata.isFromCache) return;
      final docs = <String, Map<String, dynamic>>{
        for (final doc in snapshot.docs)
          if (!doc.metadata.hasPendingWrites) doc.id: doc.data(),
      };
      if (docs.isEmpty) return;
      // Sub blocarea entității: o salvare + coadă nu se poate intercala între
      // calculul entităților protejate și scrierea bazelor (RC 120).
      await runEntitySyncLocked(CloudEntityType.offers, () async =>
          RevisionWriter.standard(firestore: _firestore).recordServerBases(
          type: CloudEntityType.offers,
          serverDocs: docs,
          keysFor: (data) => _offerToCloudMap(OfferRecord.fromMap(_normalizeOfferMap(data))).keys,
          protectedIds: await OfflineSyncRuntime.instance.protectedEntityIds(CloudEntityType.offers),
        ));
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    }
  }

  Map<String, dynamic> _offerToCloudMap(OfferRecord item) {
    return <String, dynamic>{
      'id': item.id,
      'offer_number': item.offerNumber,
      'title': item.title,
      'client_id': item.clientId,
      'client_name': item.clientName,
      'department_id': item.departmentId,
      'department_name': item.departmentName,
      'contact_person_id': item.contactPersonId,
      'contact_person_name': item.contactPersonName,
      'contact_person_email': item.contactPersonEmail,
      'contact_person_phone': item.contactPersonPhone,
      'client_signature_base64': item.clientSignatureBase64,
      'issuer_signature_base64': item.issuerSignatureBase64,
      'pdf_path': item.pdfPath,
      'beneficiary_client_id': item.beneficiaryClientId,
      'beneficiary_name': item.beneficiaryName,
      'commercial_recipient_client_id': item.commercialRecipientClientId,
      'commercial_recipient_name': item.commercialRecipientName,
      'complaint_id': item.complaintId,
      'complaint_number': item.complaintNumber,
      'appointment_id': item.appointmentId,
      'equipment_type': item.equipmentType,
      'equipment_brand': item.equipmentBrand,
      'equipment_model': item.equipmentModel,
      'outdoor_unit_serial': item.outdoorUnitSerial,
      'indoor_unit_serials': item.indoorUnitSerials,
      'equipment_details': item.equipmentDetails,
      'agreement_accepted_at': item.agreementAcceptedAt?.toIso8601String(),
      'job_id': item.jobId,
      'job_code': item.jobCode,
      'job_title': item.jobTitle,
      'status': item.status.value,
      'issue_date': item.issueDate.toIso8601String(),
      'valid_until': item.validUntil?.toIso8601String(),
      'currency': item.currency,
      'price_display_mode': item.priceDisplayMode.value,
      'exchange_rate_source': item.exchangeRateSource.value,
      'bnr_rate': item.bnrRate,
      'manual_rate': item.manualRate,
      'exchange_commission_percent': item.exchangeCommissionPercent,
      'effective_exchange_rate': item.effectiveExchangeRate,
      'notes': item.notes,
      'material_subtotal': item.materialSubtotal,
      'labor_subtotal': item.laborSubtotal,
      'subtotal_direct': item.subtotalDirect,
      'regie_percent': item.regiePercent,
      'regie_value': item.regieValue,
      'profit_percent': item.profitPercent,
      'profit_value': item.profitValue,
      'subtotal_comercial': item.subtotalComercial,
      'subtotal': item.subtotal,
      'vat_percent': item.vatPercent,
      'vat_value': item.vatValue,
      'total_value': item.totalValue,
      'lines': item.lines.map((line) => line.toMap()).toList(growable: false),
      'partners': item.partners.map((partner) => partner.toMap()).toList(
            growable: false,
          ),
      'partner_workers': item.partnerWorkers
          .map((worker) => worker.toMap())
          .toList(growable: false),
      'partner_vehicles': item.partnerVehicles
          .map((vehicle) => vehicle.toMap())
          .toList(growable: false),
      'commercial_clauses': item.commercialClauses
          .map((item) => item.toMap())
          .toList(growable: false),
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
      'created_by_user_id': item.createdByUserId,
      'created_by_user_email': item.createdByUserEmail,
      'registry_entry_id': item.registryEntryId,
      'registry_number': item.registryNumber,
      'registered_at': item.registeredAt?.toIso8601String(),
      'converted_to_job_id': item.convertedToJobId,
      'converted_at': item.convertedAt?.toIso8601String(),
      'converted_by_user_id': item.convertedByUserId,
      'smartbill_estimate': item.smartBillEstimate.toMap(),
      'smartbill_invoice': item.smartBillInvoice.toMap(),
      // Câmpuri formular acceptare
      'acceptance_clauses':
          item.acceptanceClauses.map((c) => c.toMap()).toList(growable: false),
      'acceptance_form_signature_base64': item.acceptanceFormSignatureBase64,
      'acceptance_form_signed_at':
          item.acceptanceFormSignedAt?.toIso8601String(),
      'has_acceptance_page': item.hasAcceptancePage,
    };
  }

  Map<String, dynamic> _normalizeOfferMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      // Revizia de server (RC 120): baza editării pornite din această versiune.
      if (raw['_rev'] is num) '_rev': raw['_rev'],
      'id': (raw['id'] ?? '').toString(),
      'offer_number':
          (raw['offer_number'] ?? raw['offerNumber'] ?? raw['number'] ?? '')
              .toString(),
      'title': (raw['title'] ?? raw['offer_title'] ?? '').toString(),
      'client_id': (raw['client_id'] ?? raw['clientId'] ?? '').toString(),
      'client_name': (raw['client_name'] ?? raw['clientName'] ?? '').toString(),
      'department_id':
          (raw['department_id'] ?? raw['departmentId'] ?? '').toString(),
      'department_name':
          (raw['department_name'] ?? raw['departmentName'] ?? '').toString(),
      'contact_person_id':
          (raw['contact_person_id'] ?? raw['contactPersonId'] ?? '').toString(),
      'contact_person_name': (raw['contact_person_name'] ??
              raw['contactPersonName'] ??
              raw['contact_name'] ??
              '')
          .toString(),
      'contact_person_email':
          (raw['contact_person_email'] ?? raw['contactPersonEmail'] ?? '')
              .toString(),
      'contact_person_phone':
          (raw['contact_person_phone'] ?? raw['contactPersonPhone'] ?? '')
              .toString(),
      'client_signature_base64':
          (raw['client_signature_base64'] ?? raw['clientSignatureBase64'] ?? '')
              .toString(),
      'issuer_signature_base64':
          (raw['issuer_signature_base64'] ?? raw['issuerSignatureBase64'] ?? '')
              .toString(),
      'pdf_path': (raw['pdf_path'] ?? raw['pdfPath'] ?? '').toString(),
      'beneficiary_client_id':
          (raw['beneficiary_client_id'] ?? raw['beneficiaryClientId'] ?? '')
              .toString(),
      'beneficiary_name':
          (raw['beneficiary_name'] ?? raw['beneficiaryName'] ?? '').toString(),
      'commercial_recipient_client_id':
          (raw['commercial_recipient_client_id'] ??
                  raw['commercialRecipientClientId'] ??
                  raw['payer_client_id'] ??
                  raw['payerClientId'] ??
                  '')
              .toString(),
      'commercial_recipient_name': (raw['commercial_recipient_name'] ??
              raw['commercialRecipientName'] ??
              raw['payer_name'] ??
              raw['payerName'] ??
              '')
          .toString(),
      'complaint_id':
          (raw['complaint_id'] ?? raw['complaintId'] ?? '').toString(),
      'complaint_number':
          (raw['complaint_number'] ?? raw['complaintNumber'] ?? '').toString(),
      'appointment_id':
          (raw['appointment_id'] ?? raw['appointmentId'] ?? '').toString(),
      'equipment_type':
          (raw['equipment_type'] ?? raw['equipmentType'] ?? '').toString(),
      'equipment_brand':
          (raw['equipment_brand'] ?? raw['equipmentBrand'] ?? '').toString(),
      'equipment_model':
          (raw['equipment_model'] ?? raw['equipmentModel'] ?? '').toString(),
      'outdoor_unit_serial':
          (raw['outdoor_unit_serial'] ?? raw['outdoorUnitSerial'] ?? '')
              .toString(),
      'indoor_unit_serials':
          (raw['indoor_unit_serials'] ?? raw['indoorUnitSerials'] ?? '')
              .toString(),
      'equipment_details':
          (raw['equipment_details'] ?? raw['equipmentDetails'] ?? '')
              .toString(),
      'agreement_accepted_at':
          (raw['agreement_accepted_at'] ?? raw['agreementAcceptedAt'] ?? '')
              .toString(),
      'job_id': (raw['job_id'] ?? raw['jobId'] ?? '').toString(),
      'job_code': (raw['job_code'] ?? raw['jobCode'] ?? '').toString(),
      'job_title': (raw['job_title'] ?? raw['jobTitle'] ?? '').toString(),
      'status': (raw['status'] ?? '').toString(),
      'issue_date': (raw['issue_date'] ?? raw['issueDate'] ?? '').toString(),
      'valid_until': (raw['valid_until'] ?? raw['validUntil'] ?? '').toString(),
      'currency': (raw['currency'] ?? '').toString(),
      'price_display_mode':
          (raw['price_display_mode'] ?? raw['priceDisplayMode'] ?? '')
              .toString(),
      'exchange_rate_source':
          (raw['exchange_rate_source'] ?? raw['exchangeRateSource'] ?? '')
              .toString(),
      'bnr_rate': raw['bnr_rate'] ?? raw['bnrRate'],
      'manual_rate': raw['manual_rate'] ?? raw['manualRate'],
      'exchange_commission_percent': raw['exchange_commission_percent'] ??
          raw['exchangeCommissionPercent'],
      'effective_exchange_rate':
          raw['effective_exchange_rate'] ?? raw['effectiveExchangeRate'],
      'notes': (raw['notes'] ?? '').toString(),
      'material_subtotal': raw['material_subtotal'] ?? raw['materialSubtotal'],
      'labor_subtotal': raw['labor_subtotal'] ?? raw['laborSubtotal'],
      'subtotal_direct': raw['subtotal_direct'] ?? raw['subtotalDirect'],
      'regie_percent': raw['regie_percent'] ?? raw['regiePercent'],
      'regie_value': raw['regie_value'] ?? raw['regieValue'],
      'profit_percent': raw['profit_percent'] ?? raw['profitPercent'],
      'profit_value': raw['profit_value'] ?? raw['profitValue'],
      'subtotal_comercial':
          raw['subtotal_comercial'] ?? raw['subtotalComercial'],
      'subtotal': raw['subtotal'],
      'vat_percent': raw['vat_percent'] ?? raw['vatPercent'],
      'vat_value': raw['vat_value'] ?? raw['vatValue'],
      'total_value': raw['total_value'] ?? raw['totalValue'],
      'lines': raw['lines'],
      'partners': raw['partners'],
      'partner_workers': raw['partner_workers'] ?? raw['partnerWorkers'],
      'partner_vehicles': raw['partner_vehicles'] ?? raw['partnerVehicles'],
      'commercial_clauses':
          raw['commercial_clauses'] ?? raw['commercialClauses'],
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '')
              .toString(),
      'created_by_user_email':
          (raw['created_by_user_email'] ?? raw['createdByUserEmail'] ?? '')
              .toString(),
      'registry_entry_id':
          (raw['registry_entry_id'] ?? raw['registryEntryId'] ?? '').toString(),
      'registry_number':
          (raw['registry_number'] ?? raw['registryNumber'] ?? '').toString(),
      'registered_at':
          (raw['registered_at'] ?? raw['registeredAt'] ?? '').toString(),
      'converted_to_job_id':
          (raw['converted_to_job_id'] ?? raw['convertedToJobId'] ?? '')
              .toString(),
      'converted_at':
          (raw['converted_at'] ?? raw['convertedAt'] ?? '').toString(),
      'converted_by_user_id':
          (raw['converted_by_user_id'] ?? raw['convertedByUserId'] ?? '')
              .toString(),
      'smartbill_estimate':
          raw['smartbill_estimate'] ?? raw['smartBillEstimate'],
      'smartbill_invoice': raw['smartbill_invoice'] ?? raw['smartBillInvoice'],
      // Câmpuri formular acceptare
      'acceptance_clauses':
          raw['acceptance_clauses'] ?? raw['acceptanceClauses'],
      'acceptance_form_signature_base64':
          (raw['acceptance_form_signature_base64'] ??
                  raw['acceptanceFormSignatureBase64'] ??
                  '')
              .toString(),
      'acceptance_form_signed_at': (raw['acceptance_form_signed_at'] ??
              raw['acceptanceFormSignedAt'] ??
              '')
          .toString(),
      'has_acceptance_page':
          raw['has_acceptance_page'] ?? raw['hasAcceptancePage'] ?? false,
    };
  }
}
