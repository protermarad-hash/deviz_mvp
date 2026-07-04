import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/cloud/firebase_bootstrap.dart';

/// Exceptie ridicata la operatiile de gestionare utilizatori (creare cont,
/// resetare parola). Mesajul este in romana, gata de afisat in UI.
class UserManagementException implements Exception {
  const UserManagementException({
    required this.code,
    required this.message,
    this.details = '',
  });

  final String code;
  final String message;
  final String details;

  @override
  String toString() => message;
}

/// Serviciu pentru gestionarea utilizatorilor prin Cloud Functions
/// (createTenantUser, adminSetUserPassword).
///
/// Dual-path, dupa acelasi tipar ca EmailServerService:
///  - pe mobil/web foloseste httpsCallable nativ (cloud_functions);
///  - pe desktop (Windows/Linux/macOS) canalul Pigeon nu este disponibil,
///    deci apeleaza endpoint-ul HTTP direct al functiei callable.
///
/// IMPORTANT: project ID-ul NU este hardcodat. Este citit dinamic din
/// Firebase.app().options.projectId, astfel incat pe orice build (PRO TERM
/// sau Costel) apelul HTTP loveste proiectul corect al clientului curent.
class UserManagementService {
  UserManagementService({FirebaseFunctions? functions})
      : _functions = functions ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseFunctions.instanceFor(region: _functionsRegion)
                : null);

  static const String _functionsRegion = 'europe-west1';

  final FirebaseFunctions? _functions;

  /// Pe Windows/Linux/macOS desktop canalul Pigeon pentru cloud_functions
  /// nu este disponibil — folosim endpoint-ul HTTP callable direct.
  static bool get _useHttpCallable =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Project ID dinamic din Firebase (NU hardcodat). Daca aplicatia nu e
  /// inca initializata, intoarce string gol, iar apelul HTTP va esua
  /// controlat cu mesaj clar.
  String get _projectId {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return '';
    }
  }

  /// Creeaza un utilizator nou (Firebase Auth + document users/{uid}).
  /// Intoarce map-ul de raspuns { ok, uid, email } sau arunca
  /// [UserManagementException] cu mesaj in romana.
  Future<Map<String, dynamic>> createTenantUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    return _callMap('createTenantUser', <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      'name': name.trim(),
      'role': role.trim(),
      'phone': phone.trim(),
    });
  }

  /// Schimba parola oricarui utilizator din proiectul curent (inclusiv a
  /// adminului insusi). Intoarce { ok: true } sau arunca exceptie.
  Future<Map<String, dynamic>> adminSetUserPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    return _callMap('adminSetUserPassword', <String, dynamic>{
      'targetUid': targetUid.trim(),
      'newPassword': newPassword,
    });
  }

  HttpsCallable _requireCallable(String name) {
    final functions = _functions;
    if (functions == null) {
      throw const UserManagementException(
        code: 'unavailable',
        message:
            'Firebase nu este disponibil pentru gestionarea utilizatorilor.',
      );
    }
    return functions.httpsCallable(name);
  }

  Future<Map<String, dynamic>> _callMap(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    debugPrint('[UserMgmt][service] call: $callableName '
        'payload=${_safePayloadForLogs(payload)}');
    if (_useHttpCallable) {
      return _callMapHttp(callableName, payload);
    }
    try {
      final result = await _requireCallable(callableName).call(payload);
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{'ok': true};
    } on FirebaseFunctionsException catch (error) {
      debugPrint('[UserMgmt][service] error: $callableName '
          'code=${error.code} message=${error.message}');
      throw _toException(callableName, error.code, error.message ?? '');
    }
  }

  /// Apel HTTP direct pentru desktop (Windows/Linux/macOS).
  Future<Map<String, dynamic>> _callMapHttp(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    final projectId = _projectId.trim();
    if (projectId.isEmpty) {
      throw const UserManagementException(
        code: 'failed-precondition',
        message:
            'Nu s-a putut determina proiectul Firebase. Reporneste aplicatia.',
      );
    }
    final uri = Uri.parse(
      'https://$_functionsRegion-$projectId.cloudfunctions.net/$callableName',
    );
    debugPrint('[UserMgmt][service][http] calling $callableName @ $uri');
    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{'data': payload}),
          )
          .timeout(const Duration(seconds: 60));
    } catch (networkError) {
      throw UserManagementException(
        code: 'unavailable',
        message:
            'Nu s-a putut contacta serverul. Verifica conexiunea la internet.',
        details: networkError.toString(),
      );
    }

    late Map<String, dynamic> responseBody;
    try {
      final decoded = jsonDecode(response.body);
      responseBody = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw UserManagementException(
        code: 'internal',
        message: 'Raspuns invalid de la server (HTTP ${response.statusCode}).',
        details: response.body,
      );
    }

    if (response.statusCode == 200) {
      final result = responseBody['result'];
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return <String, dynamic>{'ok': true};
    }

    // Format eroare callable Firebase: { error: { status, message, details } }
    final errorBlock = responseBody['error'] ?? <String, dynamic>{};
    final rawStatus =
        (errorBlock is Map ? errorBlock['status'] : null)?.toString() ??
            'internal';
    final rawMessage =
        (errorBlock is Map ? errorBlock['message'] : null)?.toString() ?? '';
    throw _toException(callableName, rawStatus, rawMessage);
  }

  /// Transforma codul/mesajul de eroare intr-o [UserManagementException] cu
  /// mesaj in romana. Trateaza specific cazul 'email-already-exists'.
  UserManagementException _toException(
    String callableName,
    String code,
    String remoteMessage,
  ) {
    final normalizedCode = code.trim().toLowerCase();
    final message = remoteMessage.trim();

    // Cont deja existent — backend arunca 'already-exists', dar tratam si
    // varianta bruta 'email-already-exists' din Firebase Auth.
    if (normalizedCode == 'already-exists' ||
        normalizedCode.contains('email-already-exists') ||
        message.toLowerCase().contains('already') ||
        message.toLowerCase().contains('exista deja')) {
      return UserManagementException(
        code: 'already-exists',
        message: message.isNotEmpty
            ? message
            : 'Exista deja un utilizator cu aceasta adresa de email.',
      );
    }

    if (normalizedCode == 'unauthenticated') {
      return UserManagementException(
        code: normalizedCode,
        message: message.isNotEmpty
            ? message
            : 'Trebuie sa fii autentificat ca administrator.',
      );
    }
    if (normalizedCode == 'permission-denied') {
      return UserManagementException(
        code: normalizedCode,
        message: message.isNotEmpty
            ? message
            : 'Doar administratorul poate gestiona utilizatorii.',
      );
    }

    return UserManagementException(
      code: normalizedCode.isEmpty ? 'internal' : normalizedCode,
      message: message.isNotEmpty
          ? message
          : 'A aparut o eroare la operatia $callableName.',
    );
  }

  Map<String, dynamic> _safePayloadForLogs(Map<String, dynamic> payload) {
    final safe = Map<String, dynamic>.from(payload);
    for (final key in const <String>['password', 'newPassword']) {
      if (safe.containsKey(key)) {
        final value = (safe[key] ?? '').toString();
        safe[key] = value.isEmpty ? '' : '***';
      }
    }
    return safe;
  }
}
