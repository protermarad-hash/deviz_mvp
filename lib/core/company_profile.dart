import 'pdf_export_settings.dart';
import 'app_theme_preset.dart';
import 'smartbill_settings.dart';

class CompanyProfile {
  const CompanyProfile({
    this.companyName = '',
    this.phone = '',
    this.email = '',
    this.contactEmail = '',
    this.website = '',
    this.cui = '',
    this.tradeRegister = '',
    this.bank = '',
    this.iban = '',
    this.contactName = '',
    this.address = '',
    this.city = '',
    this.county = '',
    this.logoBase64 = '',
    this.appThemePreset = AppThemePreset.proTerm,
    this.pdfExportSettings = const PdfExportSettings(),
    this.smartBillSettings = const SmartBillSettings(),
    this.currency = 'RON',
    this.language = 'RO',
    this.defaultVatPercent = 21.0,
    this.defaultProfitPercent = 15.0,
    this.defaultOverheadPercent = 0.0,
    this.agfrTechnicianName = '',
    this.agfrTechnicianCertificateNumber = '',
    this.agfrCompanyAuthorizationNumber = '',
    this.corporateTaxType = 'profit_16',
    this.corporateTaxPercent = 16.0,
  });

  final String companyName;
  final String phone;
  final String email;
  final String contactEmail;
  final String website;
  final String cui;
  final String tradeRegister;
  final String bank;
  final String iban;
  final String contactName;
  final String address;
  final String city;
  final String county;
  final String logoBase64;
  final String currency;
  final String language;
  final AppThemePreset appThemePreset;
  final PdfExportSettings pdfExportSettings;
  final SmartBillSettings smartBillSettings;
  final double defaultVatPercent;
  final double defaultProfitPercent;
  final double defaultOverheadPercent;
  final String agfrTechnicianName;
  final String agfrTechnicianCertificateNumber;
  final String agfrCompanyAuthorizationNumber;

  /// Tax type: 'profit_16' | 'micro_1' | 'micro_3' | 'custom'
  final String corporateTaxType;

  /// Effective corporate tax percent (used in profit calculations)
  final double corporateTaxPercent;

  CompanyProfile copyWith({
    String? companyName,
    String? phone,
    String? email,
    String? contactEmail,
    String? website,
    String? cui,
    String? tradeRegister,
    String? bank,
    String? iban,
    String? contactName,
    String? address,
    String? city,
    String? county,
    String? logoBase64,
    AppThemePreset? appThemePreset,
    PdfExportSettings? pdfExportSettings,
    SmartBillSettings? smartBillSettings,
    String? currency,
    String? language,
    double? defaultVatPercent,
    double? defaultProfitPercent,
    double? defaultOverheadPercent,
    String? agfrTechnicianName,
    String? agfrTechnicianCertificateNumber,
    String? agfrCompanyAuthorizationNumber,
    String? corporateTaxType,
    double? corporateTaxPercent,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      cui: cui ?? this.cui,
      tradeRegister: tradeRegister ?? this.tradeRegister,
      bank: bank ?? this.bank,
      iban: iban ?? this.iban,
      contactName: contactName ?? this.contactName,
      address: address ?? this.address,
      city: city ?? this.city,
      county: county ?? this.county,
      logoBase64: logoBase64 ?? this.logoBase64,
      appThemePreset: appThemePreset ?? this.appThemePreset,
      pdfExportSettings: pdfExportSettings ?? this.pdfExportSettings,
      smartBillSettings: smartBillSettings ?? this.smartBillSettings,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      defaultVatPercent: defaultVatPercent ?? this.defaultVatPercent,
      defaultProfitPercent: defaultProfitPercent ?? this.defaultProfitPercent,
      defaultOverheadPercent:
          defaultOverheadPercent ?? this.defaultOverheadPercent,
      agfrTechnicianName: agfrTechnicianName ?? this.agfrTechnicianName,
      agfrTechnicianCertificateNumber: agfrTechnicianCertificateNumber ??
          this.agfrTechnicianCertificateNumber,
      agfrCompanyAuthorizationNumber:
          agfrCompanyAuthorizationNumber ?? this.agfrCompanyAuthorizationNumber,
      corporateTaxType: corporateTaxType ?? this.corporateTaxType,
      corporateTaxPercent: corporateTaxPercent ?? this.corporateTaxPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_name': companyName,
      'company_phone': phone,
      'company_email': email,
      'company_contact_email': contactEmail,
      'company_website': website,
      'company_cui': cui,
      'company_trade_register': tradeRegister,
      'company_bank': bank,
      'company_iban': iban,
      'company_contact_name': contactName,
      'company_address': address,
      'company_city': city,
      'company_county': county,
      'company_logo_base64': logoBase64,
      'app_theme': appThemePreset.value,
      'pdf_export_settings': pdfExportSettings.toMap(),
      'smartbill_settings': smartBillSettings.toMap(),
      'company_currency': currency,
      'company_language': language,
      'default_vat_percent': defaultVatPercent,
      'default_profit_percent': defaultProfitPercent,
      'default_overhead_percent': defaultOverheadPercent,
      'agfr_technician_name': agfrTechnicianName,
      'agfr_technician_certificate_number': agfrTechnicianCertificateNumber,
      'agfr_company_authorization_number': agfrCompanyAuthorizationNumber,
      'corporate_tax_type': corporateTaxType,
      'corporate_tax_percent': corporateTaxPercent,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    PdfExportSettings readPdfExportSettings() {
      final raw = map['pdf_export_settings'];
      if (raw is Map<String, dynamic>) {
        return PdfExportSettings.fromMap(raw);
      }
      if (raw is Map) {
        return PdfExportSettings.fromMap(Map<String, dynamic>.from(raw));
      }
      return PdfExportSettings.fromMap(map);
    }

    SmartBillSettings readSmartBillSettings() {
      final raw = map['smartbill_settings'];
      if (raw is Map<String, dynamic>) {
        return SmartBillSettings.fromMap(raw);
      }
      if (raw is Map) {
        return SmartBillSettings.fromMap(Map<String, dynamic>.from(raw));
      }
      return SmartBillSettings.fromMap(map);
    }

    String pickWithDefault(List<String> keys, String defaultValue) {
      final value = pick(keys);
      return value.isEmpty ? defaultValue : value;
    }

    return CompanyProfile(
      companyName: pick(const ['company_name', 'name', 'firma']),
      phone: pick(const ['company_phone', 'phone']),
      email: pick(const ['company_email', 'email']),
      contactEmail: pick(const ['company_contact_email']),
      website: pick(const ['company_website']),
      cui: pick(const ['company_cui', 'cui']),
      tradeRegister: pick(const ['company_trade_register', 'trade_register']),
      bank: pick(const ['company_bank', 'bank']),
      iban: pick(const ['company_iban', 'iban']),
      contactName: pick(const ['company_contact_name', 'contact_name']),
      address: pick(const ['company_address', 'address']),
      city: pick(const ['company_city']),
      county: pick(const ['company_county']),
      logoBase64: pick(const ['company_logo_base64', 'logo_base64']),
      appThemePreset: AppThemePresetX.fromValue(
        pick(const ['app_theme', 'theme_preset', 'themePreset']),
      ),
      pdfExportSettings: readPdfExportSettings(),
      smartBillSettings: readSmartBillSettings(),
      currency: pickWithDefault(const ['company_currency'], 'RON'),
      language: pickWithDefault(const ['company_language'], 'RO'),
      defaultVatPercent: _parseDouble(map['default_vat_percent'], 19.0),
      defaultProfitPercent: _parseDouble(map['default_profit_percent'], 15.0),
      defaultOverheadPercent:
          _parseDouble(map['default_overhead_percent'], 0.0),
      agfrTechnicianName: pick(const ['agfr_technician_name']),
      agfrTechnicianCertificateNumber:
          pick(const ['agfr_technician_certificate_number']),
      agfrCompanyAuthorizationNumber:
          pick(const ['agfr_company_authorization_number']),
      corporateTaxType:
          (map['corporate_tax_type'] ?? 'profit_16').toString().trim().isEmpty
              ? 'profit_16'
              : (map['corporate_tax_type'] ?? 'profit_16').toString().trim(),
      corporateTaxPercent: _parseDouble(map['corporate_tax_percent'], 16.0),
    );
  }

  bool get isConfigured =>
      companyName.trim().isNotEmpty && cui.trim().isNotEmpty;

  String get fullAddress {
    final parts = [address, city, county]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return parts.join(', ');
  }
}

double _parseDouble(Object? value, double fallback) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
}
