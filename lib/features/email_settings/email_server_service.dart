import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'email_server_models.dart';

class EmailServerActionException implements Exception {
  const EmailServerActionException({
    required this.code,
    required this.message,
    this.details = '',
    this.technical = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final String details;
  final Map<String, dynamic> technical;

  @override
  String toString() => message;
}

class EmailServerService {
  EmailServerService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseFirestore.instance
                : null),
        _functions = functions ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseFunctions.instanceFor(region: 'europe-west1')
                : null);

  static const String _configsCacheKey = 'email_server_configs_cache_v1';
  static const String _logsCacheKey = 'email_delivery_logs_cache_v1';
  static const String _functionsRegion = 'europe-west1';
  static const String _firebaseProjectId = 'devizpro-ultra-pilot';

  /// On Windows/Linux/macOS desktop the cloud_functions Pigeon channel
  /// is not available — use direct HTTP callable endpoint instead.
  static bool get _useHttpCallable =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  bool get _isCloudAvailable =>
      FirebaseBootstrap.isInitialized && _firestore != null;

  CollectionReference<Map<String, dynamic>> get _configsCollection =>
      _firestore!.collection(FirebaseCollections.emailServerConfigs);

  CollectionReference<Map<String, dynamic>> get _logsCollection =>
      _firestore!.collection(FirebaseCollections.emailDeliveryLogs);

  Future<List<EmailServerConfigRecord>> listConfigs() async {
    final localItems = await _readLocalConfigsOnly();
    if (_functions != null) {
      try {
        final response =
            await _callMap('listEmailServerConfigs', <String, dynamic>{});
        final rawItems = response['items'];
        if (rawItems is List) {
          final cloudItems = rawItems
              .whereType<Map>()
              .map((item) => EmailServerConfigRecord.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false);
          await _writeConfigs(cloudItems);
          return cloudItems;
        }
      } catch (e) {
        debugPrint('[EmailServer] listEmailServerConfigs cloud eșuat, fallback: $e');
      }
    }

    if (!_isCloudAvailable) return localItems;
    try {
      final snapshot = await _configsCollection
          .orderBy('updated_at', descending: true)
          .get();
      final cloudItems = snapshot.docs
          .map((doc) => EmailServerConfigRecord.fromMap(doc.data()))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
      await _writeConfigs(cloudItems);
      return cloudItems;
    } catch (_) {
      return localItems;
    }
  }

  Future<List<EmailDeliveryLogRecord>> listDeliveryLogs(
      {int limit = 50}) async {
    final localItems = await _readLocalLogsOnly();
    if (_functions != null) {
      try {
        final response = await _callMap(
            'listEmailDeliveryLogs', <String, dynamic>{'limit': limit});
        final rawItems = response['items'];
        if (rawItems is List) {
          final cloudItems = rawItems
              .whereType<Map>()
              .map((item) => EmailDeliveryLogRecord.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false);
          await _writeLogs(cloudItems);
          return cloudItems;
        }
      } catch (e) {
        debugPrint('[EmailServer] listEmailDeliveryLogs cloud eșuat, fallback: $e');
      }
    }

    if (!_isCloudAvailable) {
      return localItems.take(limit).toList(growable: false);
    }
    try {
      final snapshot = await _logsCollection
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      final cloudItems = snapshot.docs
          .map((doc) => EmailDeliveryLogRecord.fromMap(doc.data()))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
      await _writeLogs(cloudItems);
      return cloudItems;
    } catch (_) {
      return localItems.take(limit).toList(growable: false);
    }
  }

  Future<Map<String, dynamic>> saveConfig({
    required String configId,
    required EmailServerProviderPreset provider,
    required String host,
    required int port,
    required bool secure,
    required String username,
    required String password,
    required String fromEmail,
    required String fromName,
    required String replyToEmail,
    required bool enabled,
  }) async {
    return _callMap('saveEmailServerConfig', <String, dynamic>{
      'configId': configId.trim(),
      'provider': provider.value,
      'host': host.trim(),
      'port': port,
      'secure': secure,
      'username': username.trim(),
      'password': password,
      'fromEmail': fromEmail.trim(),
      'fromName': fromName.trim(),
      'replyToEmail': replyToEmail.trim(),
      'enabled': enabled,
    });
  }

  Future<void> setActiveConfig(String configId) async {
    await _callVoid(
      'setActiveEmailServerConfig',
      <String, dynamic>{'configId': configId.trim()},
    );
  }

  Future<Map<String, dynamic>> testConnection({
    String configId = '',
    required EmailServerProviderPreset provider,
    required String host,
    required int port,
    required bool secure,
    required String username,
    required String password,
    required String fromEmail,
    required String fromName,
    required String replyToEmail,
  }) async {
    return _callMap('testEmailServerConfig', <String, dynamic>{
      'configId': configId.trim(),
      'provider': provider.value,
      'host': host.trim(),
      'port': port,
      'secure': secure,
      'username': username.trim(),
      'password': password,
      'fromEmail': fromEmail.trim(),
      'fromName': fromName.trim(),
      'replyToEmail': replyToEmail.trim(),
    });
  }

  Future<Map<String, dynamic>> sendTestEmail({
    String configId = '',
    required String toEmail,
    required EmailServerProviderPreset provider,
    required String host,
    required int port,
    required bool secure,
    required String username,
    required String password,
    required String fromEmail,
    required String fromName,
    required String replyToEmail,
  }) async {
    return _callMap('sendEmailServerTestEmail', <String, dynamic>{
      'configId': configId.trim(),
      'toEmail': toEmail.trim(),
      'provider': provider.value,
      'host': host.trim(),
      'port': port,
      'secure': secure,
      'username': username.trim(),
      'password': password,
      'fromEmail': fromEmail.trim(),
      'fromName': fromName.trim(),
      'replyToEmail': replyToEmail.trim(),
    });
  }

  HttpsCallable _requireCallable(String name) {
    final functions = _functions;
    if (functions == null) {
      throw StateError(
          'Firebase cloud nu este disponibil pentru configurarea serverului de email.');
    }
    return functions.httpsCallable(name);
  }

  Future<void> _callVoid(
      String callableName, Map<String, dynamic> payload) async {
    debugPrint(
      '[SMTP][service] call void: $callableName payload=${_safePayloadForLogs(payload)}',
    );
    if (_useHttpCallable) {
      await _callMapHttp(callableName, payload);
      return;
    }
    try {
      await _requireCallable(callableName).call(payload);
      debugPrint('[SMTP][service] call void success: $callableName');
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
          '[SMTP][service] call void error: $callableName code=${error.code} message=${error.message} details=${error.details}');
      throw _toActionException(callableName, error);
    }
  }

  Future<Map<String, dynamic>> _callMap(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    debugPrint(
      '[SMTP][service] call map: $callableName payload=${_safePayloadForLogs(payload)}',
    );
    if (_useHttpCallable) {
      return _callMapHttp(callableName, payload);
    }
    try {
      final result = await _requireCallable(callableName).call(payload);
      final data = result.data;
      if (data is Map) {
        debugPrint(
            '[SMTP][service] call map success: $callableName data=$data');
        return Map<String, dynamic>.from(data);
      }
      debugPrint(
          '[SMTP][service] call map success: $callableName dataType=${data.runtimeType}');
      return <String, dynamic>{'ok': true};
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
          '[SMTP][service] call map error: $callableName code=${error.code} message=${error.message} details=${error.details}');
      throw _toActionException(callableName, error);
    }
  }

  /// HTTP-based callable for Windows/Linux/macOS where the Pigeon channel
  /// for cloud_functions is not available.
  Future<Map<String, dynamic>> _callMapHttp(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    debugPrint('[SMTP][service][http] calling $callableName via HTTP');
    final uri = Uri.parse(
      'https://$_functionsRegion-$_firebaseProjectId.cloudfunctions.net/$callableName',
    );
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
      debugPrint('[SMTP][service][http] network error: $networkError');
      throw EmailServerActionException(
        code: 'unavailable',
        message:
            'Nu s-a putut contacta serverul. Verificati conexiunea la internet.',
        details: networkError.toString(),
      );
    }

    debugPrint(
        '[SMTP][service][http] status=${response.statusCode} body=${response.body.substring(0, response.body.length.clamp(0, 400))}');

    late Map<String, dynamic> responseBody;
    try {
      final decoded = jsonDecode(response.body);
      responseBody = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw EmailServerActionException(
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

    // Firebase callable error format
    final errorBlock = responseBody['error'] ?? <String, dynamic>{};
    final rawMessage = (errorBlock['message'] ?? '').toString().trim();
    final rawStatus =
        (errorBlock['status'] ?? 'internal').toString().toLowerCase();
    final rawDetails = errorBlock['details'];
    final detailsMap = rawDetails is Map
        ? Map<String, dynamic>.from(rawDetails)
        : <String, dynamic>{};
    final displayMessage =
        (detailsMap['message'] ?? rawMessage).toString().trim();
    final displayDetails = (detailsMap['details'] ?? '').toString().trim();
    throw EmailServerActionException(
      code: rawStatus,
      message: displayMessage.isNotEmpty
          ? displayMessage
          : 'Eroare server la $callableName (HTTP ${response.statusCode}).',
      details: displayDetails,
      technical: detailsMap,
    );
  }

  Map<String, dynamic> _safePayloadForLogs(Map<String, dynamic> payload) {
    final safe = Map<String, dynamic>.from(payload);
    for (final key in const <String>[
      'password',
      'pass',
      'password_encrypted'
    ]) {
      if (safe.containsKey(key)) {
        final value = (safe[key] ?? '').toString();
        safe[key] = value.trim().isEmpty ? '' : '***';
      }
    }
    return safe;
  }

  EmailServerActionException _toActionException(
    String callableName,
    FirebaseFunctionsException error,
  ) {
    final code = error.code;
    final dynamicDetails = error.details;
    final detailsMap = dynamicDetails is Map
        ? Map<String, dynamic>.from(dynamicDetails)
        : const <String, dynamic>{};
    final remoteMessage = (detailsMap['message'] ?? '').toString().trim();
    final remoteDetails = (detailsMap['details'] ?? '').toString().trim();
    final fallbackMessage = (error.message ?? '').toString().trim();
    final message = remoteMessage.isNotEmpty
        ? remoteMessage
        : (fallbackMessage.isNotEmpty
            ? fallbackMessage
            : 'A aparut o eroare la apelul $callableName.');
    final detailParts = <String>[];
    if (remoteDetails.isNotEmpty) {
      detailParts.add(remoteDetails);
    }
    final smtpDetails = detailsMap['smtp'];
    if (smtpDetails is Map) {
      final safeSmtp = Map<String, dynamic>.from(smtpDetails)
        ..remove('password')
        ..remove('pass');
      detailParts.add('SMTP: ${jsonEncode(safeSmtp)}');
    }
    final smtpErrorCode = (detailsMap['smtpErrorCode'] ?? '').toString().trim();
    if (smtpErrorCode.isNotEmpty) {
      detailParts.add('smtpErrorCode: $smtpErrorCode');
    }
    final responseCode = (detailsMap['responseCode'] ?? '').toString().trim();
    if (responseCode.isNotEmpty && responseCode != '0') {
      detailParts.add('responseCode: $responseCode');
    }
    final technicalMessage =
        (detailsMap['technicalMessage'] ?? fallbackMessage).toString().trim();
    if (technicalMessage.isNotEmpty &&
        !detailParts.contains(technicalMessage)) {
      detailParts.add(technicalMessage);
    }

    return EmailServerActionException(
      code: code,
      message: message,
      details: detailParts.join('\n'),
      technical: detailsMap,
    );
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<EmailServerConfigRecord>> _readLocalConfigsOnly() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_configsCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <EmailServerConfigRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <EmailServerConfigRecord>[];
    }
    return decoded
        .whereType<Map>()
        .map((item) =>
            EmailServerConfigRecord.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> _writeConfigs(List<EmailServerConfigRecord> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _configsCacheKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<EmailDeliveryLogRecord>> _readLocalLogsOnly() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_logsCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <EmailDeliveryLogRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <EmailDeliveryLogRecord>[];
    }
    return decoded
        .whereType<Map>()
        .map((item) =>
            EmailDeliveryLogRecord.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> _writeLogs(List<EmailDeliveryLogRecord> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _logsCacheKey,
      jsonEncode(
        items
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'source_module': item.sourceModule,
                'source_entity_id': item.sourceEntityId,
                'to': item.to,
                'subject': item.subject,
                'status': item.status.value,
                'attempt_count': item.attemptCount,
                'error_message': item.errorMessage,
                'provider_message_id': item.providerMessageId,
                'created_at': item.createdAt.toIso8601String(),
                'sent_at': item.sentAt?.toIso8601String(),
              },
            )
            .toList(growable: false),
      ),
    );
  }
}
