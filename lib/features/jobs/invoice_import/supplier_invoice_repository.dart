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

import '../../../core/cloud/firebase_collections.dart';
import 'supplier_invoice_models.dart';

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

  /// FAZA "persist invoice metadata server-side" — `persistNewInvoice` a
  /// fost ELIMINAT complet din acest fisier. Motiv: rula o tranzactie
  /// Firestore atomica pentru scrierea `supplier_invoices/{id}` +
  /// liniile — apel confirmat (inspectie sursa plugin + harness izolat de
  /// reproducere) ca declanseaza acelasi tip de crash nativ Windows ca
  /// upload-ul Storage eliminat la FAZA A-E, de data asta in pluginul
  /// `cloud_firestore`. Persistarea metadatei + liniilor facturii s-a
  /// mutat COMPLET server-side, in `parseSupplierInvoiceXml` (Admin SDK,
  /// idempotent — vezi functions_invoice_import/supplier_invoice_parse.js,
  /// functia `persistInvoiceMetadataIfNeeded`). Clientul primeste direct,
  /// in raspunsul parserului, factura + liniile CU `lineDocId` deja
  /// populat (`SupplierInvoiceParseResult.invoicePersisted == true`) —
  /// nu mai are nimic de scris in Firestore pentru acest feature.

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
