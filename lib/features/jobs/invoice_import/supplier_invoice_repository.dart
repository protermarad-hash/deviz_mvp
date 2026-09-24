// FAZA 1 / FAZA 1.1 — persistarea facturii de verificare in
// `supplier_invoices` + subcolectia `lines`. Colectii NOI, izolate — NU
// scrie niciodata in `jobs`/`materials`/catalog. Protejat de
// firestore.rules/storage.rules (STRICT ADMIN, vezi FAZA 1.1) — acest
// fisier NU e sursa de adevar a securitatii, doar respecta acelasi
// contract.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/cloud/firebase_collections.dart';
import 'supplier_invoice_models.dart';

/// Limita de siguranta pentru o tranzactie Firestore (1 doc factura +
/// linii). Firestore permite maxim 500 operatii/tranzactie — pastram
/// marja.
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

/// Aruncata cand tranzactia atomica de salvare detecteaza ca hash-ul
/// exista deja (inclusiv in cazul unei curse intre doua request-uri
/// simultane — vezi FAZA 1.1 pct. 7).
class SupplierInvoiceDuplicateException implements Exception {
  const SupplierInvoiceDuplicateException(this.info);

  final SupplierInvoiceDuplicateInfo info;

  @override
  String toString() =>
      'Factura exista deja (id=${info.invoiceId}, numar=${info.invoiceNumber}).';
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

  /// FAZA 1.1 — deduplicare ATOMICA si Firestore-nativa: ID-ul
  /// documentului `supplier_invoices/{id}` este chiar hash-ul SHA-256 al
  /// fisierului sursa (nu un ID generat aleator). Doua facturi cu acelasi
  /// continut de fisier NU pot exista niciodata ca documente separate —
  /// garantie STRUCTURALA, nu doar o verificare "check-then-create" care
  /// ar lasa o fereastra de cursa intre doua request-uri simultane.
  DocumentReference<Map<String, dynamic>> _invoiceRefForHash(String hash) =>
      _invoices.doc(hash);

  /// Verificare rapida, NEATOMICA, folosita doar pentru UX (mesaj clar
  /// inainte de upload, ca sa nu incarcam inutil fisierul in Storage daca
  /// factura exista deja). Protectia REALA impotriva curselor este in
  /// `saveForReview` (tranzactie Firestore pe doc ID determinist).
  Future<SupplierInvoiceDuplicateInfo?> findByFileHash(String hash) async {
    if (hash.isEmpty) return null;
    final snap = await _invoiceRefForHash(hash).get();
    if (!snap.exists) return null;
    final data = snap.data() ?? const <String, dynamic>{};
    return SupplierInvoiceDuplicateInfo(
      invoiceId: snap.id,
      invoiceNumber: (data['invoiceNumber'] ?? '').toString(),
      supplierName: (data['supplierName'] ?? '').toString(),
    );
  }

  /// Salveaza factura + liniile SELECTATE pentru verificare ulterioara.
  /// NU scrie in JobRecord.materials — doar in colectiile noi, izolate.
  ///
  /// Ordine: (1) verificare rapida (UX) — evita upload inutil daca hash-ul
  /// exista deja; (2) upload XML in Storage (path deterministic, bazat pe
  /// hash — reincarcarea aceluiasi fisier e idempotenta); (3) TRANZACTIE
  /// Firestore atomica: re-verifica existenta doc-ului (inchide fereastra
  /// de cursa) + scrie doc factura + toate liniile, all-or-nothing. Daca
  /// tranzactia esueaza (inclusiv din cauza unui duplicat detectat in
  /// interior), fisierul din Storage e sters (best-effort) ca sa nu ramana
  /// orfan.
  ///
  /// Arunca [SupplierInvoiceDuplicateException] daca factura exista deja
  /// (detectat fie la pasul 1, fie atomic in tranzactia de la pasul 3).
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
    if (sourceFileHash.isEmpty) {
      throw ArgumentError('Hash-ul fisierului sursa este obligatoriu.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Trebuie sa fii autentificat.');
    }
    // Refresh token inainte de upload — previne 'unauthorized' la token
    // expirat, acelasi pattern ca field_photo_capture_service.dart.
    await authUser.getIdToken(true);

    final invoiceRef = _invoiceRefForHash(sourceFileHash);
    final invoiceId = invoiceRef.id;

    final existingBeforeUpload = await findByFileHash(sourceFileHash);
    if (existingBeforeUpload != null) {
      throw SupplierInvoiceDuplicateException(existingBeforeUpload);
    }

    final storagePath =
        'supplier_invoices/${authUser.uid}/$invoiceId/source.xml';
    final storageRef = _storage.ref(storagePath);

    await storageRef.putData(
      xmlBytes,
      SettableMetadata(contentType: 'application/xml'),
    );

    try {
      await _db.runTransaction((transaction) async {
        final existingSnap = await transaction.get(invoiceRef);
        if (existingSnap.exists) {
          final data = existingSnap.data() ?? const <String, dynamic>{};
          throw SupplierInvoiceDuplicateException(
            SupplierInvoiceDuplicateInfo(
              invoiceId: existingSnap.id,
              invoiceNumber: (data['invoiceNumber'] ?? '').toString(),
              supplierName: (data['supplierName'] ?? '').toString(),
            ),
          );
        }

        transaction.set(invoiceRef, <String, dynamic>{
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
          'status': supplierInvoiceStatusToString(
            SupplierInvoiceStatus.pendingReview,
          ),
          'linkedJobIds': <String>[jobId],
        });

        final linesRef =
            invoiceRef.collection(FirebaseCollections.supplierInvoiceLines);
        for (final line in selectedLines) {
          final lineDoc = linesRef.doc();
          final map = line.toLineDocMap();
          map['id'] = lineDoc.id;
          transaction.set(lineDoc, map);
        }
      });
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
