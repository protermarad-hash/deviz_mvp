// FAZA 1 / FAZA 1.1 / FAZA 2 — persistarea facturii in `supplier_invoices`
// + subcolectia `lines`, si actualizarea metadatei dupa import in
// lucrare. Colectii NOI, izolate — NU scrie niciodata in
// `jobs`/`materials`/catalog. Protejat de firestore.rules/storage.rules
// (STRICT ADMIN, vezi FAZA 1.1) — acest fisier NU e sursa de adevar a
// securitatii, doar respecta acelasi contract.

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
/// simultane — vezi FAZA 1.1 pct. 7). FAZA 2: fluxul normal NU mai
/// trateaza asta ca eroare fatala (vezi `loadExistingInvoiceByHash`),
/// dar tranzactia tot arunca aceasta exceptie daca apare o cursa reala.
class SupplierInvoiceDuplicateException implements Exception {
  const SupplierInvoiceDuplicateException(this.info);

  final SupplierInvoiceDuplicateInfo info;

  @override
  String toString() =>
      'Factura exista deja (id=${info.invoiceId}, numar=${info.invoiceNumber}).';
}

/// O factura complet incarcata din Firestore: antet + toate liniile, CU
/// `lineDocId` populat pe fiecare (necesar pentru import in lucrare si
/// pentru detectia "deja importata" — FAZA 2 pct. 9/14).
class SupplierInvoiceLoaded {
  const SupplierInvoiceLoaded({
    required this.invoiceId,
    required this.header,
    required this.lines,
    required this.linkedJobIds,
    required this.status,
  });

  final String invoiceId;
  final SupplierInvoiceParsedHeader header;
  final List<SupplierInvoicePreviewLine> lines;
  final List<String> linkedJobIds;
  final String status;
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
  /// continut de fisier NU pot exista niciodata ca documente separate.
  DocumentReference<Map<String, dynamic>> _invoiceRefForHash(String hash) =>
      _invoices.doc(hash);

  /// FAZA 2 pct. 14 — verifica daca factura exista deja (dupa hash) si,
  /// daca da, o incarca COMPLET (antet + toate liniile, cu lineDocId).
  /// Inlocuieste vechiul comportament "duplicat = eroare fatala": o
  /// factura poate fi reutilizata pentru orice lucrare, indiferent daca a
  /// mai fost asociata alteia. NU re-uploadeaza XML, NU creeaza document
  /// nou.
  Future<SupplierInvoiceLoaded?> loadExistingInvoiceByHash(
    String hash,
  ) async {
    if (hash.isEmpty) return null;
    final snap = await _invoiceRefForHash(hash).get();
    if (!snap.exists) return null;
    return _loadInvoice(snap);
  }

  Future<SupplierInvoiceLoaded> _loadInvoice(
    DocumentSnapshot<Map<String, dynamic>> invoiceSnap,
  ) async {
    final data = invoiceSnap.data() ?? const <String, dynamic>{};
    final linesSnap = await invoiceSnap.reference
        .collection(FirebaseCollections.supplierInvoiceLines)
        .orderBy('lineIndex')
        .get();
    final lines = linesSnap.docs
        .map(
          (d) => SupplierInvoicePreviewLine.fromMap(d.data(), lineDocId: d.id),
        )
        .toList(growable: false);
    final linkedJobIds = (data['linkedJobIds'] is List)
        ? (data['linkedJobIds'] as List).map((e) => e.toString()).toList()
        : <String>[];
    return SupplierInvoiceLoaded(
      invoiceId: invoiceSnap.id,
      header: SupplierInvoiceParsedHeader.fromMap(data),
      lines: lines,
      linkedJobIds: linkedJobIds,
      status: (data['status'] ?? '').toString(),
    );
  }

  /// FAZA 2 — persista o factura NOUA (hash inexistent inca), cu TOATE
  /// liniile parsate (nu doar cele selectate — pastram factura sursa
  /// completa, selectia afecteaza doar ce se importa in lucrare).
  ///
  /// Ordine: (1) upload XML in Storage, (2) TRANZACTIE Firestore atomica:
  /// re-verifica existenta doc-ului (inchide fereastra de cursa) + scrie
  /// doc factura + toate liniile, all-or-nothing. Daca tranzactia esueaza
  /// (inclusiv duplicat detectat in interior), fisierul din Storage e
  /// sters (best-effort) ca sa nu ramana orfan.
  ///
  /// Arunca [SupplierInvoiceDuplicateException] doar in cazul rar al unei
  /// curse reale (alt request a creat exact acelasi hash intre timp) —
  /// apelantul trebuie sa reincerce cu `loadExistingInvoiceByHash`.
  Future<SupplierInvoiceLoaded> persistNewInvoice({
    required Uint8List xmlBytes,
    required String sourceFileHash,
    required SupplierInvoiceParsedHeader header,
    required List<SupplierInvoicePreviewLine> allLines,
  }) async {
    if (allLines.isEmpty) {
      throw ArgumentError('Factura nu are nicio linie.');
    }
    if (allLines.length > kSupplierInvoiceMaxLinesPerBatch) {
      throw ArgumentError(
        'Prea multe linii (${allLines.length}) pentru un singur import '
        '(limita: $kSupplierInvoiceMaxLinesPerBatch).',
      );
    }
    if (sourceFileHash.isEmpty) {
      throw ArgumentError('Hash-ul fisierului sursa este obligatoriu.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Trebuie sa fii autentificat.');
    }
    await authUser.getIdToken(true);

    final invoiceRef = _invoiceRefForHash(sourceFileHash);
    final invoiceId = invoiceRef.id;

    final existingBeforeUpload =
        await loadExistingInvoiceByHash(sourceFileHash);
    if (existingBeforeUpload != null) {
      return existingBeforeUpload;
    }

    final storagePath =
        'supplier_invoices/${authUser.uid}/$invoiceId/source.xml';
    final storageRef = _storage.ref(storagePath);

    await storageRef.putData(
      xmlBytes,
      SettableMetadata(contentType: 'application/xml'),
    );

    final lineRefs = <DocumentReference<Map<String, dynamic>>>[];
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
          'status': supplierInvoiceStatusToString(SupplierInvoiceStatus.parsed),
          'linkedJobIds': <String>[],
        });

        final linesRef =
            invoiceRef.collection(FirebaseCollections.supplierInvoiceLines);
        for (final line in allLines) {
          final lineDoc = linesRef.doc();
          lineRefs.add(lineDoc);
          final map = line.toLineDocMap();
          map['id'] = lineDoc.id;
          transaction.set(lineDoc, map);
        }
      });
    } catch (error) {
      try {
        await storageRef.delete();
      } catch (_) {
        // best-effort — vezi nota FAZA 1.1 despre fisiere orfane izolate.
      }
      rethrow;
    }

    for (var i = 0; i < allLines.length; i++) {
      allLines[i].lineDocId = lineRefs[i].id;
    }

    return SupplierInvoiceLoaded(
      invoiceId: invoiceId,
      header: header,
      lines: allLines,
      linkedJobIds: const <String>[],
      status: supplierInvoiceStatusToString(SupplierInvoiceStatus.parsed),
    );
  }

  /// FAZA 2 pct. 13 — apelata DOAR dupa ce salvarea materialelor lucrarii
  /// a reusit (vezi pct. 11: o salvare esuata NU trebuie sa marcheze
  /// factura ca importata). Idempotenta: `arrayUnion` nu duplica jobId
  /// daca e apelata de mai multe ori. Status trece la `hasAllocations`
  /// (NU "applied" — o factura poate alimenta mai multe lucrari, nu e
  /// niciodata "consumata complet" din perspectiva acestui flux).
  Future<void> markInvoiceAllocated({
    required String invoiceId,
    required String jobId,
  }) async {
    await _invoices.doc(invoiceId).update(<String, dynamic>{
      'linkedJobIds': FieldValue.arrayUnion(<String>[jobId]),
      'status':
          supplierInvoiceStatusToString(SupplierInvoiceStatus.hasAllocations),
    });
  }
}
