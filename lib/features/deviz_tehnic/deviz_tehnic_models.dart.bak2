import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ── Enumerare tip document ────────────────────────────────────────────────────

enum DevizTehnicTipDocument {
  devizTehnic,
  ofertaLucrari,
  situatieLucrari;

  String get value {
    switch (this) {
      case DevizTehnicTipDocument.devizTehnic:
        return 'deviz_tehnic';
      case DevizTehnicTipDocument.ofertaLucrari:
        return 'oferta_lucrari';
      case DevizTehnicTipDocument.situatieLucrari:
        return 'situatie_lucrari';
    }
  }

  String get label {
    switch (this) {
      case DevizTehnicTipDocument.devizTehnic:
        return 'Deviz tehnic';
      case DevizTehnicTipDocument.ofertaLucrari:
        return 'Ofertă de lucrări';
      case DevizTehnicTipDocument.situatieLucrari:
        return 'Situație de lucrări';
    }
  }

  String get pdfTitle {
    switch (this) {
      case DevizTehnicTipDocument.devizTehnic:
        return 'DEVIZ TEHNIC';
      case DevizTehnicTipDocument.ofertaLucrari:
        return 'OFERTĂ DE LUCRĂRI';
      case DevizTehnicTipDocument.situatieLucrari:
        return 'SITUAȚIE DE LUCRĂRI';
    }
  }

  static DevizTehnicTipDocument fromValue(String? raw) {
    switch (raw) {
      case 'oferta_lucrari':
        return DevizTehnicTipDocument.ofertaLucrari;
      case 'situatie_lucrari':
        return DevizTehnicTipDocument.situatieLucrari;
      default:
        return DevizTehnicTipDocument.devizTehnic;
    }
  }
}

// ── Enumerare status deviz ────────────────────────────────────────────────────

enum DevizTehnicStatus {
  draft,
  trimis,
  acceptat,
  respins,
  anulat;

  String get value {
    switch (this) {
      case DevizTehnicStatus.draft:
        return 'draft';
      case DevizTehnicStatus.trimis:
        return 'trimis';
      case DevizTehnicStatus.acceptat:
        return 'acceptat';
      case DevizTehnicStatus.respins:
        return 'respins';
      case DevizTehnicStatus.anulat:
        return 'anulat';
    }
  }

  String get label {
    switch (this) {
      case DevizTehnicStatus.draft:
        return 'Draft';
      case DevizTehnicStatus.trimis:
        return 'Trimis';
      case DevizTehnicStatus.acceptat:
        return 'Acceptat';
      case DevizTehnicStatus.respins:
        return 'Respins';
      case DevizTehnicStatus.anulat:
        return 'Anulat';
    }
  }

  Color get color {
    switch (this) {
      case DevizTehnicStatus.draft:
        return Colors.grey;
      case DevizTehnicStatus.trimis:
        return Colors.blue;
      case DevizTehnicStatus.acceptat:
        return Colors.green;
      case DevizTehnicStatus.respins:
        return Colors.red;
      case DevizTehnicStatus.anulat:
        return Colors.orange;
    }
  }

  static DevizTehnicStatus fromValue(String? raw) {
    switch (raw) {
      case 'trimis':
        return DevizTehnicStatus.trimis;
      case 'acceptat':
        return DevizTehnicStatus.acceptat;
      case 'respins':
        return DevizTehnicStatus.respins;
      case 'anulat':
        return DevizTehnicStatus.anulat;
      default:
        return DevizTehnicStatus.draft;
    }
  }
}

// ── Enumerare mod afișare prețuri ─────────────────────────────────────────────

enum DevizTehnicPriceDisplay {
  faraTva,
  cuTva,
  ambele;

  String get value {
    switch (this) {
      case DevizTehnicPriceDisplay.faraTva:
        return 'fara_tva';
      case DevizTehnicPriceDisplay.cuTva:
        return 'cu_tva';
      case DevizTehnicPriceDisplay.ambele:
        return 'ambele';
    }
  }

  String get label {
    switch (this) {
      case DevizTehnicPriceDisplay.faraTva:
        return 'Fără TVA';
      case DevizTehnicPriceDisplay.cuTva:
        return 'Cu TVA';
      case DevizTehnicPriceDisplay.ambele:
        return 'Ambele';
    }
  }

  bool get showFaraTva =>
      this == DevizTehnicPriceDisplay.faraTva ||
      this == DevizTehnicPriceDisplay.ambele;
  bool get showCuTva =>
      this == DevizTehnicPriceDisplay.cuTva ||
      this == DevizTehnicPriceDisplay.ambele;

  static DevizTehnicPriceDisplay fromValue(String? raw) {
    switch (raw) {
      case 'cu_tva':
        return DevizTehnicPriceDisplay.cuTva;
      case 'ambele':
        return DevizTehnicPriceDisplay.ambele;
      default:
        return DevizTehnicPriceDisplay.faraTva;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Un articol din devizul tehnic.
/// Fiecare articol are 4 componente de cost: Material, Manoperă, Utilaj, Transport.
class DevizTehnicArticol {
  DevizTehnicArticol({
    String? id,
    required this.denumire,
    required this.um,
    required this.cantitate,
    this.pretMat = 0,
    this.pretMan = 0,
    this.pretUtilaj = 0,
    this.pretTransport = 0,
  }) : id = id?.isNotEmpty == true ? id! : const Uuid().v4();

  /// ID unic per articol — generat automat dacă nu e furnizat.
  final String id;
  final String denumire;
  final String um;
  final double cantitate;
  final double pretMat;
  final double pretMan;
  final double pretUtilaj;
  final double pretTransport;

  double get valoareMat => cantitate * pretMat;
  double get valoareMan => cantitate * pretMan;
  double get valoareUtilaj => cantitate * pretUtilaj;
  double get valoareTransport => cantitate * pretTransport;
  double get totalArticol =>
      valoareMat + valoareMan + valoareUtilaj + valoareTransport;

  DevizTehnicArticol copyWith({
    String? id,
    String? denumire,
    String? um,
    double? cantitate,
    double? pretMat,
    double? pretMan,
    double? pretUtilaj,
    double? pretTransport,
  }) {
    return DevizTehnicArticol(
      id: id ?? this.id,
      denumire: denumire ?? this.denumire,
      um: um ?? this.um,
      cantitate: cantitate ?? this.cantitate,
      pretMat: pretMat ?? this.pretMat,
      pretMan: pretMan ?? this.pretMan,
      pretUtilaj: pretUtilaj ?? this.pretUtilaj,
      pretTransport: pretTransport ?? this.pretTransport,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'denumire': denumire,
        'um': um,
        'cantitate': cantitate,
        'pret_mat': pretMat,
        'pret_man': pretMan,
        'pret_utilaj': pretUtilaj,
        'pret_transport': pretTransport,
      };

  factory DevizTehnicArticol.fromMap(Map<String, dynamic> m) =>
      DevizTehnicArticol(
        // Backward compat: date vechi fără 'id' → UUID generat în constructor
        id: (m['id'] ?? '').toString(),
        denumire: (m['denumire'] ?? '').toString(),
        um: (m['um'] ?? 'buc').toString(),
        cantitate: _d(m['cantitate']),
        pretMat: _d(m['pret_mat']),
        pretMan: _d(m['pret_man']),
        pretUtilaj: _d(m['pret_utilaj']),
        pretTransport: _d(m['pret_transport']),
      );

  static double _d(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;
}

/// Documentul principal — deviz tehnic / ofertă tehnică / situație de lucrări.
class DevizTehnicRecord {
  const DevizTehnicRecord({
    required this.id,
    this.numar = '',
    this.titlu = '',
    this.obiectiv = '',
    this.clientId = '',
    this.clientName = '',
    this.clientCui = '',
    this.clientAddress = '',
    this.clientPhone = '',
    this.clientEmail = '',
    this.contactPerson = '',
    this.contactDepartment = '',
    required this.dataEmiterii,
    this.zileValabilitate = 30,
    this.articole = const [],
    this.regiePercent = 9,
    this.profitPercent = 10,
    this.tvaPercent = 21,
    this.intocmitDe = '',
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdByUserId = '',
    // Câmpuri noi (backward-compatible — au valori default)
    this.tipDocument = DevizTehnicTipDocument.devizTehnic,
    this.status = DevizTehnicStatus.draft,
    this.priceDisplay = DevizTehnicPriceDisplay.faraTva,
    this.registryEntryId = '',
    this.registryNumber = '',
    this.registeredAt,
  });

  final String id;
  final String numar;
  final String titlu;
  final String obiectiv;
  final String clientId;
  final String clientName;
  final String clientCui;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String contactPerson;
  final String contactDepartment;
  final DateTime dataEmiterii;
  final int zileValabilitate;
  final List<DevizTehnicArticol> articole;
  final double regiePercent;
  final double profitPercent;
  final double tvaPercent;
  final String intocmitDe;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUserId;
  // Câmpuri noi
  final DevizTehnicTipDocument tipDocument;
  final DevizTehnicStatus status;
  final DevizTehnicPriceDisplay priceDisplay;
  final String registryEntryId;
  final String registryNumber;
  final DateTime? registeredAt;

  // ── Totaluri calculate ──────────────────────────────────────────
  double get totalMat =>
      articole.fold(0, (s, a) => s + a.valoareMat);
  double get totalMan =>
      articole.fold(0, (s, a) => s + a.valoareMan);
  double get totalUtilaj =>
      articole.fold(0, (s, a) => s + a.valoareUtilaj);
  double get totalTransport =>
      articole.fold(0, (s, a) => s + a.valoareTransport);
  double get totalDirect => totalMat + totalMan + totalUtilaj + totalTransport;
  double get regie => totalDirect * regiePercent / 100;
  double get profit => (totalDirect + regie) * profitPercent / 100;
  double get totalFaraTva => totalDirect + regie + profit;
  double get tva => totalFaraTva * tvaPercent / 100;
  double get totalCuTva => totalFaraTva + tva;

  DevizTehnicRecord copyWith({
    String? numar,
    String? titlu,
    String? obiectiv,
    String? clientId,
    String? clientName,
    String? clientCui,
    String? clientAddress,
    String? clientPhone,
    String? clientEmail,
    String? contactPerson,
    String? contactDepartment,
    DateTime? dataEmiterii,
    int? zileValabilitate,
    List<DevizTehnicArticol>? articole,
    double? regiePercent,
    double? profitPercent,
    double? tvaPercent,
    String? intocmitDe,
    String? note,
    DateTime? updatedAt,
    DevizTehnicTipDocument? tipDocument,
    DevizTehnicStatus? status,
    DevizTehnicPriceDisplay? priceDisplay,
    String? registryEntryId,
    String? registryNumber,
    DateTime? registeredAt,
  }) {
    return DevizTehnicRecord(
      id: id,
      numar: numar ?? this.numar,
      titlu: titlu ?? this.titlu,
      obiectiv: obiectiv ?? this.obiectiv,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientCui: clientCui ?? this.clientCui,
      clientAddress: clientAddress ?? this.clientAddress,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      contactPerson: contactPerson ?? this.contactPerson,
      contactDepartment: contactDepartment ?? this.contactDepartment,
      dataEmiterii: dataEmiterii ?? this.dataEmiterii,
      zileValabilitate: zileValabilitate ?? this.zileValabilitate,
      articole: articole ?? this.articole,
      regiePercent: regiePercent ?? this.regiePercent,
      profitPercent: profitPercent ?? this.profitPercent,
      tvaPercent: tvaPercent ?? this.tvaPercent,
      intocmitDe: intocmitDe ?? this.intocmitDe,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUserId: createdByUserId,
      tipDocument: tipDocument ?? this.tipDocument,
      status: status ?? this.status,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      registryNumber: registryNumber ?? this.registryNumber,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'numar': numar,
        'titlu': titlu,
        'obiectiv': obiectiv,
        'client_id': clientId,
        'client_name': clientName,
        'client_cui': clientCui,
        'client_address': clientAddress,
        'client_phone': clientPhone,
        'client_email': clientEmail,
        'contact_person': contactPerson,
        'contact_department': contactDepartment,
        'data_emiterii': dataEmiterii.toIso8601String(),
        'zile_valabilitate': zileValabilitate,
        'articole': articole.map((a) => a.toMap()).toList(),
        'regie_percent': regiePercent,
        'profit_percent': profitPercent,
        'tva_percent': tvaPercent,
        'intocmit_de': intocmitDe,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by_user_id': createdByUserId,
        // Câmpuri noi
        'tip_document': tipDocument.value,
        'status': status.value,
        'price_display': priceDisplay.value,
        'registry_entry_id': registryEntryId,
        'registry_number': registryNumber,
        'registered_at': registeredAt?.toIso8601String(),
      };

  factory DevizTehnicRecord.fromMap(Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final artList = (m['articole'] as List?)
            ?.map((e) =>
                DevizTehnicArticol.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return DevizTehnicRecord(
      id: (m['id'] ?? '').toString(),
      numar: (m['numar'] ?? '').toString(),
      titlu: (m['titlu'] ?? '').toString(),
      obiectiv: (m['obiectiv'] ?? '').toString(),
      clientId: (m['client_id'] ?? '').toString(),
      clientName: (m['client_name'] ?? '').toString(),
      clientCui: (m['client_cui'] ?? '').toString(),
      clientAddress: (m['client_address'] ?? '').toString(),
      clientPhone: (m['client_phone'] ?? '').toString(),
      clientEmail: (m['client_email'] ?? '').toString(),
      contactPerson: (m['contact_person'] ?? '').toString(),
      contactDepartment: (m['contact_department'] ?? '').toString(),
      dataEmiterii: parseDate(m['data_emiterii']),
      zileValabilitate: int.tryParse((m['zile_valabilitate'] ?? 30).toString()) ?? 30,
      articole: artList,
      regiePercent: double.tryParse((m['regie_percent'] ?? 9).toString()) ?? 9,
      profitPercent: double.tryParse((m['profit_percent'] ?? 10).toString()) ?? 10,
      tvaPercent: double.tryParse((m['tva_percent'] ?? 21).toString()) ?? 21,
      intocmitDe: (m['intocmit_de'] ?? '').toString(),
      note: (m['note'] ?? '').toString(),
      createdAt: parseDate(m['created_at']),
      updatedAt: parseDate(m['updated_at']),
      createdByUserId: (m['created_by_user_id'] ?? '').toString(),
      // Câmpuri noi — backward-compatible (valori default dacă lipsesc)
      tipDocument: DevizTehnicTipDocument.fromValue(m['tip_document']?.toString()),
      status: DevizTehnicStatus.fromValue(m['status']?.toString()),
      priceDisplay: DevizTehnicPriceDisplay.fromValue(m['price_display']?.toString()),
      registryEntryId: (m['registry_entry_id'] ?? '').toString(),
      registryNumber: (m['registry_number'] ?? '').toString(),
      registeredAt: m['registered_at'] != null
          ? (m['registered_at'] is Timestamp
              ? (m['registered_at'] as Timestamp).toDate()
              : DateTime.tryParse(m['registered_at'].toString()))
          : null,
    );
  }
}
