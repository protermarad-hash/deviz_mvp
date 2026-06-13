import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../smartbill_settings.dart';

class SmartBillService {
  SmartBillService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://ws.smartbill.ro/SBORO/api';

  final http.Client _client;

  Future<SmartBillConnectionResult> probeConfiguration(
    SmartBillSettings settings,
  ) async {
    final invoiceSeriesFuture =
        fetchSeries(settings, type: SmartBillSeriesType.invoice);
    final estimateSeriesFuture = fetchSeries(
      settings,
      type: SmartBillSeriesType.estimate,
    );
    final taxesFuture = fetchTaxes(settings);

    final results = await Future.wait<dynamic>([
      invoiceSeriesFuture,
      estimateSeriesFuture,
      taxesFuture,
    ]);

    return SmartBillConnectionResult(
      invoiceSeries: results[0] as List<SmartBillSeriesInfo>,
      estimateSeries: results[1] as List<SmartBillSeriesInfo>,
      taxes: results[2] as List<SmartBillTaxInfo>,
    );
  }

  Future<List<SmartBillSeriesInfo>> fetchSeries(
    SmartBillSettings settings, {
    SmartBillSeriesType? type,
  }) async {
    final response = await _get(
      '/series',
      settings,
      queryParameters: {
        'cif': settings.companyVatCode.trim(),
        if (type != null) 'type': type.apiValue,
      },
    );
    final root = _readMap(response, const ['sbcSeries']);
    _throwIfSmartBillFault(root);
    final list = root['list'];
    if (list is! List) {
      return const <SmartBillSeriesInfo>[];
    }
    return list
        .whereType<Map>()
        .map(
          (item) => SmartBillSeriesInfo.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => type == null || item.type == type)
        .toList(growable: false);
  }

  Future<List<SmartBillTaxInfo>> fetchTaxes(SmartBillSettings settings) async {
    final response = await _get(
      '/tax',
      settings,
      queryParameters: {'cif': settings.companyVatCode.trim()},
    );
    final root = _readMap(response, const ['sbcTaxes']);
    _throwIfSmartBillFault(root);
    final list = root['taxes'];
    if (list is! List) {
      return const <SmartBillTaxInfo>[];
    }
    return list
        .whereType<Map>()
        .map(
          (item) => SmartBillTaxInfo.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<SmartBillIssueResponse> issueEstimate(
    SmartBillSettings settings,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/estimate', settings, payload: payload);
    final root = _readMap(response, const ['sbcResponse', 'response']);
    _throwIfSmartBillFault(root);
    return SmartBillIssueResponse.fromMap(root);
  }

  Future<SmartBillIssueResponse> issueInvoice(
    SmartBillSettings settings,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post('/invoice', settings, payload: payload);
    final root = _readMap(response, const ['sbcResponse', 'response']);
    _throwIfSmartBillFault(root);
    return SmartBillIssueResponse.fromMap(root);
  }

  /// Citește stocul curent dintr-o gestiune SmartBill.
  /// [warehouseName] — numele exact al gestiunii (ex: "MATERIALE-Cantitativ valorica")
  /// [date] — data pentru care se cere stocul (implicit azi)
  Future<List<SmartBillStockItem>> fetchStock(
    SmartBillSettings settings, {
    required String warehouseName,
    DateTime? date,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
    final response = await _get(
      '/stocks',
      settings,
      queryParameters: {
        'cif': settings.companyVatCode.trim(),
        'date': dateStr,
        'warehouseName': warehouseName.trim(),
      },
    );
    final root = _readMap(response, const ['list', 'stocks', 'sbcResponse']);
    // SmartBill returnează lista direct în 'list' sau în root
    final rawList = response['list'] ?? root['list'] ?? response['stocks'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((item) => SmartBillStockItem.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  }

  /// Creează un bon de consum în SmartBill.
  /// Scade materialele din gestiunea specificată.
  Future<SmartBillConsumptionNoteResponse> createConsumptionNote(
    SmartBillSettings settings, {
    required String warehouseName,
    required String seriesName,
    required DateTime date,
    required List<SmartBillConsumptionLine> lines,
  }) async {
    final payload = <String, dynamic>{
      'companyVatCode': settings.companyVatCode.trim(),
      'seriesName': seriesName.trim(),
      'date': DateFormat('yyyy-MM-dd').format(date),
      'warehouseName': warehouseName.trim(),
      'products': lines
          .map(
            (line) => <String, dynamic>{
              'name': line.name,
              if (line.code.isNotEmpty) 'code': line.code,
              'quantity': line.quantity,
              'measuringUnitName': line.unit.isNotEmpty ? line.unit : 'buc',
              if (line.unitPrice > 0) 'price': line.unitPrice,
            },
          )
          .toList(),
    };
    final response = await _post('/note/consumption', settings, payload: payload);
    final root = _readMap(response, const ['sbcResponse', 'response']);
    _throwIfSmartBillFault(root);
    return SmartBillConsumptionNoteResponse.fromMap(root.isNotEmpty ? root : response);
  }

  Future<SmartBillInvoicePaymentStatus> fetchInvoicePaymentStatus(
    SmartBillSettings settings, {
    required String seriesName,
    required String number,
  }) async {
    final response = await _get(
      '/invoice/paymentstatus',
      settings,
      queryParameters: {
        'cif': settings.companyVatCode.trim(),
        'seriesname': seriesName.trim(),
        'number': number.trim(),
      },
    );
    final root = _readMap(
      response,
      const ['sbcInvoicePaymentStatusResponse', 'sbcResponse', 'response'],
    );
    _throwIfSmartBillFault(root);
    return SmartBillInvoicePaymentStatus.fromMap(root);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    SmartBillSettings settings, {
    required Map<String, String> queryParameters,
  }) async {
    _validateSettings(settings);

    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );
    final response = await _client
        .get(uri, headers: _headers(settings))
        .timeout(const Duration(seconds: 20));

    final body = response.body.trim();
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw SmartBillApiException('Raspuns SmartBill invalid.');
      }
      payload = decoded;
    } catch (_) {
      throw SmartBillApiException(
        _httpErrorMessage(response.statusCode, body),
      );
    }

    if (response.statusCode >= 400) {
      throw SmartBillApiException(
        _extractError(payload) ?? _httpErrorMessage(response.statusCode, body),
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    SmartBillSettings settings, {
    required Map<String, dynamic> payload,
  }) async {
    _validateSettings(settings);

    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client
        .post(
          uri,
          headers: _headers(settings),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    final body = response.body.trim();
    Map<String, dynamic> decodedPayload;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw SmartBillApiException('Raspuns SmartBill invalid.');
      }
      decodedPayload = decoded;
    } catch (_) {
      throw SmartBillApiException(
        _httpErrorMessage(response.statusCode, body),
      );
    }

    if (response.statusCode >= 400) {
      throw SmartBillApiException(
        _extractError(decodedPayload) ??
            _httpErrorMessage(response.statusCode, body),
      );
    }
    return decodedPayload;
  }

  void _validateSettings(SmartBillSettings settings) {
    if (settings.username.trim().isEmpty) {
      throw SmartBillApiException('Completeaza email-ul SmartBill.');
    }
    if (settings.token.trim().isEmpty) {
      throw SmartBillApiException('Completeaza token-ul SmartBill.');
    }
    if (settings.companyVatCode.trim().isEmpty) {
      throw SmartBillApiException(
          'Completeaza CIF-ul firmei pentru SmartBill.');
    }
  }

  Map<String, String> _headers(SmartBillSettings settings) {
    final credentials = base64Encode(
      utf8.encode('${settings.username.trim()}:${settings.token.trim()}'),
    );
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Basic $credentials',
    };
  }

  Map<String, dynamic> _readMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return source;
  }

  void _throwIfSmartBillFault(Map<String, dynamic> payload) {
    final error = _extractError(payload);
    if (error != null && error.isNotEmpty) {
      throw SmartBillApiException(error);
    }
  }

  String? _extractError(Map<String, dynamic> payload) {
    final errorText = (payload['errorText'] ?? '').toString().trim();
    if (errorText.isNotEmpty) {
      return errorText;
    }
    final message = (payload['message'] ?? '').toString().trim();
    if (message.toLowerCase().contains('eroare')) {
      return message;
    }
    return null;
  }

  String _httpErrorMessage(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Autentificare SmartBill esuata. Verifica email, token si CIF.';
      case 403:
        return 'SmartBill a blocat temporar apelurile. Reincearca in cateva minute.';
      case 404:
        return 'Endpoint SmartBill indisponibil momentan.';
      default:
        if (body.isNotEmpty) {
          return body;
        }
        return 'SmartBill a raspuns cu status $statusCode.';
    }
  }
}

enum SmartBillSeriesType {
  invoice('f', 'Factura'),
  estimate('p', 'Proforma'),
  receipt('c', 'Chitanta');

  const SmartBillSeriesType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SmartBillSeriesType? fromApiValue(String value) {
    final normalized = value.trim().toLowerCase();
    for (final candidate in values) {
      if (candidate.apiValue == normalized) {
        return candidate;
      }
    }
    return null;
  }
}

class SmartBillSeriesInfo {
  const SmartBillSeriesInfo({
    required this.name,
    required this.nextNumber,
    required this.type,
  });

  final String name;
  final String nextNumber;
  final SmartBillSeriesType? type;

  factory SmartBillSeriesInfo.fromMap(Map<String, dynamic> map) {
    return SmartBillSeriesInfo(
      name: (map['name'] ?? '').toString().trim(),
      nextNumber: (map['nextNumber'] ?? '').toString().trim(),
      type: SmartBillSeriesType.fromApiValue((map['type'] ?? '').toString()),
    );
  }
}

class SmartBillTaxInfo {
  const SmartBillTaxInfo({
    required this.name,
    required this.percentage,
  });

  final String name;
  final double percentage;

  factory SmartBillTaxInfo.fromMap(Map<String, dynamic> map) {
    final rawPercentage = map['percentage'];
    final percentage = rawPercentage is num
        ? rawPercentage.toDouble()
        : double.tryParse((rawPercentage ?? '').toString()) ?? 0;
    return SmartBillTaxInfo(
      name: (map['name'] ?? '').toString().trim(),
      percentage: percentage,
    );
  }
}

class SmartBillConnectionResult {
  const SmartBillConnectionResult({
    required this.invoiceSeries,
    required this.estimateSeries,
    required this.taxes,
  });

  final List<SmartBillSeriesInfo> invoiceSeries;
  final List<SmartBillSeriesInfo> estimateSeries;
  final List<SmartBillTaxInfo> taxes;
}

class SmartBillIssueResponse {
  const SmartBillIssueResponse({
    required this.series,
    required this.number,
    this.documentUrl = '',
    this.documentViewUrl = '',
    this.publicUrl = '',
    this.documentId = '',
    this.message = '',
  });

  final String series;
  final String number;
  final String documentUrl;
  final String documentViewUrl;
  final String publicUrl;
  final String documentId;
  final String message;

  factory SmartBillIssueResponse.fromMap(Map<String, dynamic> map) {
    return SmartBillIssueResponse(
      series: (map['series'] ?? '').toString().trim(),
      number: (map['number'] ?? '').toString().trim(),
      documentUrl:
          (map['documentUrl'] ?? map['document_url'] ?? '').toString().trim(),
      documentViewUrl:
          (map['documentViewUrl'] ?? map['document_view_url'] ?? '')
              .toString()
              .trim(),
      publicUrl: (map['url'] ?? map['public_url'] ?? '').toString().trim(),
      documentId:
          (map['documentId'] ?? map['document_id'] ?? '').toString().trim(),
      message: (map['message'] ?? '').toString().trim(),
    );
  }
}

class SmartBillInvoicePaymentStatus {
  const SmartBillInvoicePaymentStatus({
    required this.invoiceTotalAmount,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  final double invoiceTotalAmount;
  final double paidAmount;
  final double unpaidAmount;

  factory SmartBillInvoicePaymentStatus.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw, [double fallback = 0]) {
      if (raw == null) return fallback;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ??
          fallback;
    }

    return SmartBillInvoicePaymentStatus(
      invoiceTotalAmount: asDouble(
        map['invoiceTotalAmount'] ?? map['invoice_total_amount'],
      ),
      paidAmount: asDouble(map['paidAmount'] ?? map['paid_amount']),
      unpaidAmount: asDouble(map['unpaidAmount'] ?? map['unpaid_amount']),
    );
  }
}

class SmartBillApiException implements Exception {
  SmartBillApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Modele stoc
// ---------------------------------------------------------------------------

class SmartBillStockItem {
  const SmartBillStockItem({
    required this.name,
    this.code = '',
    this.unit = '',
    this.quantity = 0,
    this.unitPrice = 0,
  });

  final String name;
  final String code;
  final String unit;
  final double quantity;
  final double unitPrice;

  double get totalValue => quantity * unitPrice;

  factory SmartBillStockItem.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
    }

    return SmartBillStockItem(
      name: (map['name'] ?? map['productName'] ?? '').toString().trim(),
      code: (map['code'] ?? map['productCode'] ?? '').toString().trim(),
      unit: (map['measuringUnitName'] ?? map['um'] ?? map['unit'] ?? '').toString().trim(),
      quantity: asDouble(map['quantity'] ?? map['qty']),
      unitPrice: asDouble(map['price'] ?? map['unitPrice'] ?? map['pricePerUnit']),
    );
  }
}

// ---------------------------------------------------------------------------
// Bon de consum
// ---------------------------------------------------------------------------

class SmartBillConsumptionLine {
  const SmartBillConsumptionLine({
    required this.name,
    required this.quantity,
    required this.unit,
    this.code = '',
    this.unitPrice = 0,
  });

  final String name;
  final String code;
  final double quantity;
  final String unit;
  final double unitPrice;
}

class SmartBillConsumptionNoteResponse {
  const SmartBillConsumptionNoteResponse({
    required this.series,
    required this.number,
    this.message = '',
  });

  final String series;
  final String number;
  final String message;

  String get documentLabel =>
      series.isNotEmpty && number.isNotEmpty ? '$series $number' : '';

  factory SmartBillConsumptionNoteResponse.fromMap(Map<String, dynamic> map) {
    return SmartBillConsumptionNoteResponse(
      series: (map['series'] ?? map['seriesName'] ?? '').toString().trim(),
      number: (map['number'] ?? map['documentNumber'] ?? '').toString().trim(),
      message: (map['message'] ?? '').toString().trim(),
    );
  }
}
