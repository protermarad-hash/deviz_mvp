// FAZA 1 — client Dart pentru callable-ul Cloud Function
// `parseSupplierInvoiceXml` (functions/supplier_invoice_parse.js).
//
// Tipar dual-path IDENTIC cu UserManagementService (vezi
// lib/features/user_management/user_management_service.dart):
//  - mobil/web: httpsCallable nativ (cloud_functions);
//  - desktop (Windows/Linux/macOS): canalul Pigeon nu e disponibil, deci
//    apel HTTP direct catre endpoint-ul callable, CU antet Authorization
//    (ID token curent) — necesar ca `request.auth` sa fie populat pe
//    server (requireAdminOrOfficeForInvoices arunca 'unauthenticated'
//    altfel). Acesta e un fix local, izolat in acest fisier nou — NU
//    modifica UserManagementService/EmailServerService existente.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/cloud/firebase_bootstrap.dart';
import 'supplier_invoice_models.dart';

class SupplierInvoiceParseException implements Exception {
  const SupplierInvoiceParseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class SupplierInvoiceParseResult {
  const SupplierInvoiceParseResult({
    required this.header,
    required this.lines,
    required this.invoiceId,
    required this.sourcePersisted,
  });

  final SupplierInvoiceParsedHeader header;
  final List<SupplierInvoicePreviewLine> lines;

  /// ID canonic al facturii — SHA-256(xmlContent), calculat SERVER-SIDE de
  /// `parseSupplierInvoiceXml` (vezi functions_invoice_import/). Acelasi
  /// id e folosit atat ca document Firestore `supplier_invoices/{id}`
  /// (SupplierInvoiceRepository), cat si ca segment de path in Storage
  /// (calculat identic pe server). Autoritar — nu se recalculeaza client-side.
  final String invoiceId;

  /// true daca XML-ul sursa a fost deja persistat in Firebase Storage de
  /// server (Admin SDK) in cadrul acestui apel — clientul NU mai face
  /// niciun upload propriu catre Storage pentru acest feature (elimina
  /// crash-ul nativ firebase_storage confirmat pe Windows).
  final bool sourcePersisted;
}

class SupplierInvoiceParserClient {
  SupplierInvoiceParserClient({FirebaseFunctions? functions})
      : _functions = functions ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseFunctions.instanceFor(region: _region)
                : null);

  static const String _region = 'europe-west1';
  static const String _callableName = 'parseSupplierInvoiceXml';

  final FirebaseFunctions? _functions;

  static bool get _useHttpCallable =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  String get _projectId {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return '';
    }
  }

  Future<SupplierInvoiceParseResult> parseXml(String xmlContent) async {
    final Map<String, dynamic> data = _useHttpCallable
        ? await _callHttp(xmlContent)
        : await _callNative(xmlContent);

    final header = SupplierInvoiceParsedHeader.fromMap(
      (data['header'] is Map)
          ? Map<String, dynamic>.from(data['header'] as Map)
          : const <String, dynamic>{},
    );
    final rawLines = (data['lines'] is List) ? data['lines'] as List : const [];
    final lines = rawLines
        .whereType<Map>()
        .map((m) =>
            SupplierInvoicePreviewLine.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    return SupplierInvoiceParseResult(
      header: header,
      lines: lines,
      invoiceId: (data['invoiceId'] ?? '').toString(),
      sourcePersisted: data['sourcePersisted'] == true,
    );
  }

  Future<Map<String, dynamic>> _callNative(String xmlContent) async {
    final functions = _functions;
    if (functions == null) {
      throw const SupplierInvoiceParseException(
        'unavailable',
        'Firebase nu este disponibil pentru parsarea facturii.',
      );
    }
    try {
      final result = await functions.httpsCallable(_callableName).call(
        <String, dynamic>{'xmlContent': xmlContent},
      );
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const SupplierInvoiceParseException(
        'internal',
        'Raspuns neasteptat de la server.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw SupplierInvoiceParseException(
        error.code,
        (error.message ?? '').trim().isNotEmpty
            ? error.message!.trim()
            : 'Eroare la parsarea facturii.',
      );
    }
  }

  Future<Map<String, dynamic>> _callHttp(String xmlContent) async {
    final projectId = _projectId.trim();
    if (projectId.isEmpty) {
      throw const SupplierInvoiceParseException(
        'failed-precondition',
        'Nu s-a putut determina proiectul Firebase. Reporneste aplicatia.',
      );
    }
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const SupplierInvoiceParseException(
        'unauthenticated',
        'Trebuie sa fii autentificat pentru a importa facturi.',
      );
    }

    final uri = Uri.parse(
      'https://$_region-$projectId.cloudfunctions.net/$_callableName',
    );

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{'xmlContent': xmlContent},
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (networkError) {
      throw SupplierInvoiceParseException(
        'unavailable',
        'Nu s-a putut contacta serverul. Verifica conexiunea la internet.',
      );
    }

    late Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw SupplierInvoiceParseException(
        'internal',
        'Raspuns invalid de la server (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode == 200) {
      final result = body['result'];
      if (result is Map) return Map<String, dynamic>.from(result);
      throw const SupplierInvoiceParseException(
        'internal',
        'Raspuns neasteptat de la server.',
      );
    }

    final errorBlock = body['error'];
    final code =
        (errorBlock is Map ? errorBlock['status'] : null)?.toString() ??
            'internal';
    final message =
        (errorBlock is Map ? errorBlock['message'] : null)?.toString() ?? '';
    throw SupplierInvoiceParseException(
      code,
      message.isNotEmpty ? message : 'Eroare la parsarea facturii.',
    );
  }
}
