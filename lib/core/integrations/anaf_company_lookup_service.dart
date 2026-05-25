import 'dart:convert';
import 'dart:io';

enum AnafCompanyLookupStatus {
  success,
  invalidCui,
  notFound,
  serviceUnavailable,
}

class AnafCompanyData {
  const AnafCompanyData({
    required this.cui,
    required this.name,
    required this.address,
    required this.city,
    required this.county,
    this.tradeRegisterNumber = '',
    this.phone = '',
    this.iban = '',
    this.postalCode = '',
    this.registrationStatus = '',
    this.registrationDate = '',
    this.caenCode = '',
    this.vatRegistered,
    this.vatOnCash,
    this.inactive,
    this.splitVat,
    this.eFactura,
    this.ownershipForm = '',
    this.organizationForm = '',
    this.legalForm = '',
    this.fiscalAuthority = '',
  });

  final String cui;
  final String name;
  final String address;
  final String city;
  final String county;
  final String tradeRegisterNumber;
  final String phone;
  final String iban;
  final String postalCode;
  final String registrationStatus;
  final String registrationDate;
  final String caenCode;
  final bool? vatRegistered;
  final bool? vatOnCash;
  final bool? inactive;
  final bool? splitVat;
  final bool? eFactura;
  final String ownershipForm;
  final String organizationForm;
  final String legalForm;
  final String fiscalAuthority;
}

class AnafCompanyLookupResult {
  const AnafCompanyLookupResult({
    required this.status,
    required this.message,
    this.company,
  });

  final AnafCompanyLookupStatus status;
  final String message;
  final AnafCompanyData? company;

  bool get isSuccess => status == AnafCompanyLookupStatus.success;
}

class AnafCompanyLookupService {
  const AnafCompanyLookupService();

  static const String _endpoint =
      'https://webservicesp.anaf.ro/api/PlatitorTvaRest/v9/tva';

  Future<AnafCompanyLookupResult> lookupByCui(
    String rawCui, {
    DateTime? atDate,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final normalizedCui = _normalizeCui(rawCui);
    if (normalizedCui.isEmpty) {
      return const AnafCompanyLookupResult(
        status: AnafCompanyLookupStatus.invalidCui,
        message: 'Introdu un CUI valid pentru persoana juridica.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'cui': int.parse(normalizedCui),
            'data': _formatDate(atDate ?? DateTime.now()),
          },
        ]),
      );

      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const AnafCompanyLookupResult(
          status: AnafCompanyLookupStatus.serviceUnavailable,
          message:
              'Serviciul ANAF nu este disponibil acum. Poti continua completarea manuala.',
        );
      }

      final body = await utf8.decodeStream(response);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const AnafCompanyLookupResult(
          status: AnafCompanyLookupStatus.serviceUnavailable,
          message:
              'Raspunsul primit de la ANAF nu a putut fi interpretat. Poti continua completarea manuala.',
        );
      }

      final found = decoded['found'];
      if (found is List && found.isNotEmpty && found.first is Map) {
        final company = _parseCompany(
          Map<String, dynamic>.from(found.first as Map),
          normalizedCui,
        );
        if (company != null) {
          return AnafCompanyLookupResult(
            status: AnafCompanyLookupStatus.success,
            message:
                'Datele ANAF au fost preluate. Verifica si ajusteaza manual campurile daca este nevoie.',
            company: company,
          );
        }
      }

      final notFound = decoded['notFound'];
      if (notFound is List &&
          notFound.any((item) => _normalizeCui(item.toString()) == normalizedCui)) {
        return const AnafCompanyLookupResult(
          status: AnafCompanyLookupStatus.notFound,
          message:
              'Nu au fost gasite date ANAF pentru CUI-ul introdus. Poti continua completarea manuala.',
        );
      }

      return const AnafCompanyLookupResult(
        status: AnafCompanyLookupStatus.serviceUnavailable,
        message:
            'ANAF nu a returnat un rezultat utilizabil. Poti continua completarea manuala.',
      );
    } catch (_) {
      return const AnafCompanyLookupResult(
        status: AnafCompanyLookupStatus.serviceUnavailable,
        message:
            'Serviciul ANAF nu a raspuns. Poti continua completarea manuala.',
      );
    } finally {
      client?.close(force: true);
    }
  }

  AnafCompanyData? _parseCompany(
    Map<String, dynamic> raw,
    String normalizedCui,
  ) {
    final general = _asMap(raw['date_generale']);
    if (general.isEmpty) return null;

    final registeredAddress = _asMap(raw['adresa_sediu_social']);
    final fiscalAddress = _asMap(raw['adresa_domiciliu_fiscal']);
    final vat = _asMap(raw['inregistrare_scop_Tva']);
    final vatCash = _asMap(raw['inregistrare_RTVAI']);
    final inactive = _asMap(raw['stare_inactiv']);
    final splitVat = _asMap(raw['inregistrare_SplitTVA']);

    final companyName = _readString(general, const <String>['denumire']);
    final companyCui = _normalizeCui(
      _readString(general, const <String>['cui']).isNotEmpty
          ? _readString(general, const <String>['cui'])
          : normalizedCui,
    );
    final city = _firstNonEmpty(<String>[
      _readString(
        registeredAddress,
        const <String>['sdenumire_Localitate'],
      ),
      _readString(fiscalAddress, const <String>['ddenumire_Localitate']),
    ]);
    final county = _firstNonEmpty(<String>[
      _readString(registeredAddress, const <String>['sdenumire_Judet']),
      _readString(fiscalAddress, const <String>['ddenumire_Judet']),
    ]);

    return AnafCompanyData(
      cui: companyCui,
      name: companyName,
      address: _buildAddress(registeredAddress, fiscalAddress, general),
      city: city,
      county: county,
      tradeRegisterNumber: _readString(general, const <String>['nrRegCom']),
      phone: _readString(general, const <String>['telefon']),
      iban: _readString(general, const <String>['iban']),
      postalCode: _firstNonEmpty(<String>[
        _readString(registeredAddress, const <String>['scod_Postal']),
        _readString(fiscalAddress, const <String>['dcod_Postal']),
        _readString(general, const <String>['codPostal']),
      ]),
      registrationStatus: _readString(
        general,
        const <String>['stare_inregistrare'],
      ),
      registrationDate: _readString(
        general,
        const <String>['data_inregistrare'],
      ),
      caenCode: _readString(general, const <String>['cod_CAEN']),
      vatRegistered: _readBool(vat, const <String>['scpTVA']),
      vatOnCash: _readBool(vatCash, const <String>['statusTvaIncasare']),
      inactive: _readBool(inactive, const <String>['statusInactivi']),
      splitVat: _readBool(splitVat, const <String>['statusSplitTVA']),
      eFactura: _readBool(general, const <String>['statusRO_e_Factura']),
      ownershipForm: _readString(
        general,
        const <String>['forma_de_proprietate'],
      ),
      organizationForm: _readString(
        general,
        const <String>['forma_organizare'],
      ),
      legalForm: _readString(general, const <String>['forma_juridica']),
      fiscalAuthority: _readString(
        general,
        const <String>['organFiscalCompetent'],
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  String _buildAddress(
    Map<String, dynamic> registeredAddress,
    Map<String, dynamic> fiscalAddress,
    Map<String, dynamic> general,
  ) {
    final registered = _joinAddressParts(<String>[
      _composeStreet(
        street: _readString(
          registeredAddress,
          const <String>['sdenumire_Strada'],
        ),
        number: _readString(registeredAddress, const <String>['snumar_Strada']),
      ),
      _readString(registeredAddress, const <String>['sdetalii_Adresa']),
      _readString(
        registeredAddress,
        const <String>['sdenumire_Localitate'],
      ),
      _readString(registeredAddress, const <String>['sdenumire_Judet']),
      _readString(registeredAddress, const <String>['stara']),
      _readString(registeredAddress, const <String>['scod_Postal']),
    ]);
    if (registered.isNotEmpty) return registered;

    final fiscal = _joinAddressParts(<String>[
      _composeStreet(
        street: _readString(fiscalAddress, const <String>['ddenumire_Strada']),
        number: _readString(fiscalAddress, const <String>['dnumar_Strada']),
      ),
      _readString(fiscalAddress, const <String>['ddetalii_Adresa']),
      _readString(fiscalAddress, const <String>['ddenumire_Localitate']),
      _readString(fiscalAddress, const <String>['ddenumire_Judet']),
      _readString(fiscalAddress, const <String>['dtara']),
      _readString(fiscalAddress, const <String>['dcod_Postal']),
    ]);
    if (fiscal.isNotEmpty) return fiscal;

    return _readString(general, const <String>['adresa']);
  }

  String _composeStreet({
    required String street,
    required String number,
  }) {
    if (street.isEmpty) return '';
    if (number.isEmpty) return street;
    return '$street nr. $number';
  }

  String _joinAddressParts(List<String> parts) {
    final values = parts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return values.join(', ');
  }

  String _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = (raw[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  bool? _readBool(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is bool) return value;
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String _normalizeCui(String raw) {
    final normalized = raw.trim().toUpperCase().replaceFirst('RO', '');
    return normalized.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
