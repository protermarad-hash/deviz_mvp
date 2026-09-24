// FAZA 1 — persistarea facturii de verificare in `supplier_invoices` +
// subcolectia `lines`. Colectii NOI, izolate — NU scrie niciodata in
// `jobs`/`materials`/catalog. Protejat de firestore.rules/storage.rules
// (doar admin/office) — acest fisier NU e sursa de adevar a securitatii,
// doar respecta acelasi contract.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/cloud/firebase_collections.dart';
import 'supplier_invoice_models.dart';

/// Limita de siguranta pentru un batch Firestore (1 doc factura + linii).
/// Firestore permite maxim 500 operatii/batch — pastram marja.
const int kSupplierInvoiceMaxLinesPerBatch = 400;

class SupplierInvoiceDuplicateInfo {
  const SupplierInvoiceDuplicateInfo({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.supplierName,
  });

  final String invoiceId;
  final String invoiceNumber;
  final String supplierName;
}

class SupplierInvoiceRepository {
  SupplierInvoiceRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _db.collection(FirebaseCollections.supplierInvoices);

  String computeSha256(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Verifica daca exista deja o factura importata cu ACELASI hash de
  /// fisier — semnalul PRINCIPAL de duplicat (cerinta FAZA 1 pct. 5).
  Future<SupplierInvoiceDuplicateInfo?> findByFileHash(String hash) async {
    if (hash.isEmpty) return null;
    final snap =
        await _invoices.where('sourceFileHash', isEqualTo: hash).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    return SupplierInvoiceDuplicateInfo(
      invoiceId: snap.docs.first.id,
      invoiceNumber: (data['invoiceNumber'] ?? '').toString(),
      supplierName: (data['supplierName'] ?? '').toString(),
    );
  }

  /// Salveaza factura + liniile SELECTATE pentru verificare ulterioara.
  /// NU scrie in JobRecord.materials — doar in colectiile noi, izolate.
  ///
  /// Ordine: (1) upload XML in Storage, (2) batch Firestore atomic
  /// (doc factura + toate liniile). Daca (2) esueaza dupa ce (1) a
  /// reusit, se sterge fisierul din Storage (best-effort) ca sa nu ramana
  /// orfan greu de curatat.
  Future<String> saveForReview({
    required Uint8List xmlBytes,
    required String sourceFileHash,
    required SupplierInvoiceParsedHeader header,
    required List<SupplierInvoicePreviewLine> selectedLines,
    required String jobId,
  }) async {
    if (selectedLines.isEmpty) {
      throw ArgumentError('Nicio linie selectata pentru salvare.');
    }
    if (selectedLines.length > kSupplierInvoiceMaxLinesPerBatch) {
      throw ArgumentError(
        'Prea multe linii selectate (${selectedLines.length}) pentru un singur '
        'import (limita FAZA 1: $kSupplierInvoiceMaxLinesPerBatch).',
      );
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Trebuie sa fii autentificat.');
    }
    // Refresh token inainte de upload — previne 'unauthorized' la token
    // expirat, acelasi pattern ca field_photo_capture_service.dart.
    await authUser.getIdToken(true);

    final invoiceRef = _invoices.doc();
    final invoiceId = invoiceRef.id;
    final storagePath =
        'supplier_invoices/${authUser.uid}/$invoiceId/source.xml';
    final storageRef = _storage.ref(storagePath);

    await storageRef.putData(
      xmlBytes,
      SettableMetadata(contentType: 'application/xml'),
    );

    final batch = _db.batch();
    batch.set(invoiceRef, <String, dynamic>{
      'id': invoiceId,
      'supplierName': header.supplierName,
      'supplierTaxId': header.supplierTaxId,
      'invoiceNumber': header.invoiceNumber,
      'invoiceDate': header.invoiceDate,
      'sourceType': 'xmlEInvoice',
      'sourceFileStoragePath': storagePath,
      'sourceFileHash': sourceFileHash,
      'importedByUserId': authUser.uid,
      'importedAt': FieldValue.serverTimestamp(),
      'currency': header.currency,
      'totalWithoutVat': header.totalWithoutVat,
      'totalVat': header.totalVat,
      'status':
          supplierInvoiceStatusToString(SupplierInvoiceStatus.pendingReview),
      'linkedJobIds': <String>[jobId],
    });

    final linesRef =
        invoiceRef.collection(FirebaseCollections.supplierInvoiceLines);
    for (final line in selectedLines) {
      final lineDoc = linesRef.doc();
      final map = line.toLineDocMap();
      map['id'] = lineDoc.id;
      batch.set(lineDoc, map);
    }

    try {
      await batch.commit();
    } catch (error) {
      try {
        await storageRef.delete();
      } catch (_) {
        // best-effort — daca nici stergerea nu reuseste, fisierul orfan
        // ramane in supplier_invoices/{uid}/{invoiceId}/, izolat, fara
        // niciun document Firestore care sa-l refere.
      }
      rethrow;
    }

    return invoiceId;
  }

  /// Facturile legate de o lucrare — interogare pe legatura inversa
  /// (linkedJobIds array-contains jobId). Sortare facuta client-side
  /// (dupa importedAt) ca sa NU fie nevoie de niciun index Firestore nou
  /// (array-contains simplu e auto-indexat; array-contains + orderBy pe
  /// alt camp ar necesita index compus).
  Future<List<Map<String, dynamic>>> getInvoicesForJob(String jobId) async {
    final snap =
        await _invoices.where('linkedJobIds', arrayContains: jobId).get();
    final docs = snap.docs
        .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
        .toList();
    docs.sort((a, b) {
      final ta = a['importedAt'];
      final tb = b['importedAt'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return docs;
  }
}
