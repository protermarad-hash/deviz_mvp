import 'package:flutter/material.dart';

enum CrmStadiu {
  lead,
  calificat,
  ofertaTrimisa,
  negociere,
  castigat,
  pierdut,
  inactiv;

  String get label => switch (this) {
        lead => 'Lead nou',
        calificat => 'Calificat',
        ofertaTrimisa => 'Oferta trimisa',
        negociere => 'Negociere',
        castigat => 'Castigat',
        pierdut => 'Pierdut',
        inactiv => 'Inactiv',
      };

  Color get color => switch (this) {
        lead => Colors.blue,
        calificat => Colors.purple,
        ofertaTrimisa => Colors.orange,
        negociere => Colors.amber,
        castigat => Colors.green,
        pierdut => Colors.red,
        inactiv => Colors.grey,
      };

  static CrmStadiu fromValue(String? v) {
    return CrmStadiu.values.firstWhere(
      (s) => s.name == (v ?? '').trim(),
      orElse: () => CrmStadiu.lead,
    );
  }
}

class CrmInteractiune {
  const CrmInteractiune({
    required this.id,
    required this.tip,
    required this.descriere,
    required this.data,
    required this.createdBy,
  });

  final String id;
  /// 'apel' | 'email' | 'whatsapp' | 'vizita' | 'oferta' | 'note'
  final String tip;
  final String descriere;
  final DateTime data;
  final String createdBy;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'tip': tip,
        'descriere': descriere,
        'data': data.toIso8601String(),
        'created_by': createdBy,
      };

  factory CrmInteractiune.fromMap(Map<String, dynamic> m) => CrmInteractiune(
        id: (m['id'] ?? '').toString(),
        tip: (m['tip'] ?? 'note').toString(),
        descriere: (m['descriere'] ?? '').toString(),
        data: DateTime.tryParse((m['data'] ?? '').toString()) ?? DateTime.now(),
        createdBy: (m['created_by'] ?? '').toString(),
      );
}

class CrmRecord {
  const CrmRecord({
    required this.id,
    required this.titlu,
    required this.clientId,
    required this.clientName,
    required this.stadiu,
    required this.dataContact,
    required this.createdAt,
    required this.updatedAt,
    this.contactPerson = '',
    this.phoneNumbers = const [],
    this.email = '',
    this.tipLucrare = '',
    this.valoareEstimata = 0,
    this.valoareFinala,
    this.sursa = 'Direct',
    this.ofertaId = '',
    this.jobId = '',
    this.dataUrmatoareActiune,
    this.urmatoareActiune = '',
    this.interactiuni = const [],
    this.note = '',
    this.assignedTo = '',
  });

  final String id;
  final String titlu;
  final String clientId;
  final String clientName;
  final String contactPerson;
  final List<String> phoneNumbers;
  final String email;
  final CrmStadiu stadiu;
  final String tipLucrare;
  final double valoareEstimata;
  final double? valoareFinala;
  final String sursa;
  final String ofertaId;
  final String jobId;
  final DateTime dataContact;
  final DateTime? dataUrmatoareActiune;
  final String urmatoareActiune;
  final List<CrmInteractiune> interactiuni;
  final String note;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get necesitaActiune {
    final d = dataUrmatoareActiune;
    if (d == null) return false;
    return !d.isAfter(DateTime.now());
  }

  bool get esteActiv =>
      stadiu != CrmStadiu.pierdut && stadiu != CrmStadiu.inactiv;

  CrmRecord copyWith({
    String? id,
    String? titlu,
    String? clientId,
    String? clientName,
    String? contactPerson,
    List<String>? phoneNumbers,
    String? email,
    CrmStadiu? stadiu,
    String? tipLucrare,
    double? valoareEstimata,
    double? valoareFinala,
    String? sursa,
    String? ofertaId,
    String? jobId,
    DateTime? dataContact,
    DateTime? dataUrmatoareActiune,
    String? urmatoareActiune,
    List<CrmInteractiune>? interactiuni,
    String? note,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CrmRecord(
        id: id ?? this.id,
        titlu: titlu ?? this.titlu,
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        contactPerson: contactPerson ?? this.contactPerson,
        phoneNumbers: phoneNumbers ?? this.phoneNumbers,
        email: email ?? this.email,
        stadiu: stadiu ?? this.stadiu,
        tipLucrare: tipLucrare ?? this.tipLucrare,
        valoareEstimata: valoareEstimata ?? this.valoareEstimata,
        valoareFinala: valoareFinala ?? this.valoareFinala,
        sursa: sursa ?? this.sursa,
        ofertaId: ofertaId ?? this.ofertaId,
        jobId: jobId ?? this.jobId,
        dataContact: dataContact ?? this.dataContact,
        dataUrmatoareActiune: dataUrmatoareActiune ?? this.dataUrmatoareActiune,
        urmatoareActiune: urmatoareActiune ?? this.urmatoareActiune,
        interactiuni: interactiuni ?? this.interactiuni,
        note: note ?? this.note,
        assignedTo: assignedTo ?? this.assignedTo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'titlu': titlu,
        'client_id': clientId,
        'client_name': clientName,
        'contact_person': contactPerson,
        'phone_numbers': phoneNumbers,
        'email': email,
        'stadiu': stadiu.name,
        'tip_lucrare': tipLucrare,
        'valoare_estimata': valoareEstimata,
        'valoare_finala': valoareFinala,
        'sursa': sursa,
        'oferta_id': ofertaId,
        'job_id': jobId,
        'data_contact': dataContact.toIso8601String(),
        'data_urmatoare_actiune': dataUrmatoareActiune?.toIso8601String(),
        'urmatoare_actiune': urmatoareActiune,
        'interactiuni':
            interactiuni.map((i) => i.toMap()).toList(),
        'note': note,
        'assigned_to': assignedTo,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CrmRecord.fromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return CrmRecord(
      id: (m['id'] ?? '').toString(),
      titlu: (m['titlu'] ?? '').toString(),
      clientId: (m['client_id'] ?? '').toString(),
      clientName: (m['client_name'] ?? '').toString(),
      contactPerson: (m['contact_person'] ?? '').toString(),
      phoneNumbers:
          List<String>.from((m['phone_numbers'] as List? ?? [])),
      email: (m['email'] ?? '').toString(),
      stadiu: CrmStadiu.fromValue(m['stadiu'] as String?),
      tipLucrare: (m['tip_lucrare'] ?? '').toString(),
      valoareEstimata: (m['valoare_estimata'] as num? ?? 0).toDouble(),
      valoareFinala: (m['valoare_finala'] as num?)?.toDouble(),
      sursa: (m['sursa'] ?? 'Direct').toString(),
      ofertaId: (m['oferta_id'] ?? '').toString(),
      jobId: (m['job_id'] ?? '').toString(),
      dataContact:
          DateTime.tryParse((m['data_contact'] ?? '').toString()) ?? now,
      dataUrmatoareActiune: DateTime.tryParse(
          (m['data_urmatoare_actiune'] ?? '').toString()),
      urmatoareActiune: (m['urmatoare_actiune'] ?? '').toString(),
      interactiuni: (m['interactiuni'] as List? ?? [])
          .whereType<Map>()
          .map((e) =>
              CrmInteractiune.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      note: (m['note'] ?? '').toString(),
      assignedTo: (m['assigned_to'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((m['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

class CrmStats {
  const CrmStats({
    required this.totalLeaduri,
    required this.castigate,
    required this.pierdute,
    required this.rataConversie,
    required this.valoareTotalaCastigata,
    required this.valoareTotalaPipeline,
    required this.perSursa,
    required this.perTipLucrare,
  });

  final int totalLeaduri;
  final int castigate;
  final int pierdute;
  final double rataConversie;
  final double valoareTotalaCastigata;
  final double valoareTotalaPipeline;
  final Map<String, int> perSursa;
  final Map<String, double> perTipLucrare;
}
