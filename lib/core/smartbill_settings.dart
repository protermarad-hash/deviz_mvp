class SmartBillSettings {
  const SmartBillSettings({
    this.enabled = false,
    this.username = '',
    this.token = '',
    this.companyVatCode = '',
    this.invoiceSeriesName = '',
    this.estimateSeriesName = '',
    this.useInvoiceDraft = false,
    this.useEstimateDraft = false,
    this.sendEmailOnIssue = false,
    this.consumptionWarehouseName = '',
    this.consumptionSeriesName = '',
  });

  final bool enabled;
  final String username;
  final String token;
  final String companyVatCode;
  final String invoiceSeriesName;
  final String estimateSeriesName;
  final bool useInvoiceDraft;
  final bool useEstimateDraft;
  final bool sendEmailOnIssue;
  // Gestiune implicită pentru bonuri de consum (ex: "MATERIALE-Cantitativ valorica")
  final String consumptionWarehouseName;
  // Serie bon consum în SmartBill (ex: "BC")
  final String consumptionSeriesName;

  bool get isConfigured =>
      username.trim().isNotEmpty &&
      token.trim().isNotEmpty &&
      companyVatCode.trim().isNotEmpty;

  bool get isConsumptionConfigured =>
      isConfigured && consumptionWarehouseName.trim().isNotEmpty;

  SmartBillSettings copyWith({
    bool? enabled,
    String? username,
    String? token,
    String? companyVatCode,
    String? invoiceSeriesName,
    String? estimateSeriesName,
    bool? useInvoiceDraft,
    bool? useEstimateDraft,
    bool? sendEmailOnIssue,
    String? consumptionWarehouseName,
    String? consumptionSeriesName,
  }) {
    return SmartBillSettings(
      enabled: enabled ?? this.enabled,
      username: username ?? this.username,
      token: token ?? this.token,
      companyVatCode: companyVatCode ?? this.companyVatCode,
      invoiceSeriesName: invoiceSeriesName ?? this.invoiceSeriesName,
      estimateSeriesName: estimateSeriesName ?? this.estimateSeriesName,
      useInvoiceDraft: useInvoiceDraft ?? this.useInvoiceDraft,
      useEstimateDraft: useEstimateDraft ?? this.useEstimateDraft,
      sendEmailOnIssue: sendEmailOnIssue ?? this.sendEmailOnIssue,
      consumptionWarehouseName:
          consumptionWarehouseName ?? this.consumptionWarehouseName,
      consumptionSeriesName:
          consumptionSeriesName ?? this.consumptionSeriesName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'username': username,
      'token': token,
      'company_vat_code': companyVatCode,
      'invoice_series_name': invoiceSeriesName,
      'estimate_series_name': estimateSeriesName,
      'use_invoice_draft': useInvoiceDraft,
      'use_estimate_draft': useEstimateDraft,
      'send_email_on_issue': sendEmailOnIssue,
      'consumption_warehouse_name': consumptionWarehouseName,
      'consumption_series_name': consumptionSeriesName,
    };
  }

  factory SmartBillSettings.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    bool pickBool(List<String> keys) {
      for (final key in keys) {
        final raw = map[key];
        if (raw is bool) return raw;
        final value = (raw ?? '').toString().trim().toLowerCase();
        if (value == 'true' || value == '1') return true;
        if (value == 'false' || value == '0') return false;
      }
      return false;
    }

    return SmartBillSettings(
      enabled: pickBool(const ['enabled', 'smartbill_enabled']),
      username: pick(const ['username', 'email', 'smartbill_username']),
      token: pick(const ['token', 'smartbill_token']),
      companyVatCode: pick(
        const ['company_vat_code', 'cif', 'companyVatCode', 'smartbill_cif'],
      ),
      invoiceSeriesName: pick(
        const ['invoice_series_name', 'invoiceSeriesName', 'smartbill_invoice_series'],
      ),
      estimateSeriesName: pick(
        const ['estimate_series_name', 'estimateSeriesName', 'smartbill_estimate_series'],
      ),
      useInvoiceDraft: pickBool(const ['use_invoice_draft', 'useInvoiceDraft']),
      useEstimateDraft: pickBool(const ['use_estimate_draft', 'useEstimateDraft']),
      sendEmailOnIssue: pickBool(const ['send_email_on_issue', 'sendEmailOnIssue']),
      consumptionWarehouseName: pick(
        const ['consumption_warehouse_name', 'consumptionWarehouseName'],
      ),
      consumptionSeriesName: pick(
        const ['consumption_series_name', 'consumptionSeriesName'],
      ),
    );
  }
}
