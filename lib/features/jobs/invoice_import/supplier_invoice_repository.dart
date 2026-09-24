// FAZA 1 / FAZA 1.1 / FAZA 2 — persistarea facturii in `supplier_invoices`
// + subcolectia `lines`, si actualizarea metadatei dupa import in
// lucrare. Colectii NOI, izolate — NU scrie niciodata in
// `jobs`/`materials`/catalog. Protejat de firestore.rules/storage.rules
// (STRICT ADMIN, vezi FAZA 1.1) — acest fisier NU e sursa de adevar a
// securitatii, doar respecta acelasi contract.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/cloud/firebase_collections.dart';
import 'supplier_invoice_models.dart';

/// Limita de siguranta pentru o tranzactie Firestore (1 doc factura +
/// linii). Firestore permite maxim 500 operatii/tranzactie — pastram
/// marja.
const int kSupplierInvoiceMaxLinesPerBatch = 400;

/// Decodeaza bytes-ii unui fisier XML in text UTF-8, eliminand un eventual
/// BOM (U+FEFF) de la inceput — extras ca functie PURA, testabila
/// independent (fara Firebase), din `_pickAndParseFile` in
/// `supplier_invoice_import_page.dart`. Text-ul rezultat e EXACT ce se
/// trimite ca `xmlContent` catre `parseSupplierInvoiceXml` si ce serverul
/// foloseste pentru hash-ul canonic (`computeSourceFileHash`) — motiv
/// pentru care hash-ul pe bytes brute (`computeSha256`) poate diferi de
/// invoiceId-ul server pentru fisiere CU BOM (auditul hash/dedup FAZA
/// "reconcile prin server").
String decodeXmlBytesToUtf8Text(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: false);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    return text.substring(1);
  }
  return text;
}

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
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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

  /// FAZA 2 — persista o factura NOUA (invoiceId inexistent inca in
  /// Firestore), cu TOATE liniile parsate (nu doar cele selectate —
  /// pastram factura sursa completa, selectia afecteaza doar ce se
  /// importa in lucrare).
  ///
  /// FAZA A-E/1-13 (bug crash nativ firebase_storage pe Windows) — acest
  /// client NU mai face niciun upload catre Firebase Storage. XML-ul sursa
  /// e deja persistat SERVER-SIDE, in `parseSupplierInvoiceXml` (Admin
  /// SDK, idempotent — vezi functions_invoice_import/), INAINTE ca acest
  /// apel sa aiba loc. `invoiceId` primit aici e chiar hash-ul SHA-256
  /// canonic calculat de server (returnat de parser), NU un hash
  /// recalculat client-side — clientul e doar consumator al acestui id.
  ///
  /// Ordine: TRANZACTIE Firestore atomica: re-verifica existenta doc-ului
  /// (inchide fereastra de cursa) + scrie doc factura + toate liniile,
  /// all-or-nothing.
  ///
  /// Arunca [SupplierInvoiceDuplicateException] doar in cazul rar al unei
  /// curse reale (alt request a creat exact acelasi invoiceId intre timp)
  /// — apelantul trebuie sa reincerce cu `loadExistingInvoiceByHash`.
  Future<SupplierInvoiceLoaded> persistNewInvoice({
    required String invoiceId,
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
    if (invoiceId.isEmpty) {
      throw ArgumentError('ID-ul facturii (hash canonic server) este obligatoriu.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Trebuie sa fii autentificat.');
    }
    await authUser.getIdToken(true);

    final invoiceRef = _invoiceRefForHash(invoiceId);

    final existingBeforeWrite = await loadExistingInvoiceByHash(invoiceId);
    if (existingBeforeWrite != null) {
      return existingBeforeWrite;
    }

    // Path determinist — IDENTIC cu cel calculat server-side (acelasi uid +
    // invoiceId), doar pentru inregistrare/trasabilitate in documentul
    // Firestore. NU e folosit pentru niciun upload aici — fisierul exista
    // deja la acest path, scris de server.
    final storagePath =
        'supplier_invoices/${authUser.uid}/$invoiceId/source.xml';

    final lineRefs = <DocumentReference<Map<String, dynamic>>>[];
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
        'sourceFileHash': invoiceId,
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
