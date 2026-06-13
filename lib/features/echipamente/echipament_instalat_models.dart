class EchipamentInstalat {
  const EchipamentInstalat({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.adresaInstalare,
    required this.tipEchipament,
    required this.marca,
    required this.model,
    required this.dataInstalare,
    required this.garantieLuni,
    required this.createdAt,
    required this.updatedAt,
    this.serieUnitateExterna = '',
    this.seriiUnitatiInterne = const [],
    this.agentFrigorific = '',
    this.capacitateBTU = 0,
    this.numarPVMontaj = '',
    this.jobId = '',
    this.technicianInstalare = '',
    this.ultimaInterventieData,
    this.ultimaInterventieId,
    this.intervalServiceRecomandat,
    this.stare = 'functional',
    this.note = '',
  });

  final String id;
  final String clientId;
  final String clientName;
  final String adresaInstalare;
  final String tipEchipament;
  final String marca;
  final String model;
  final String serieUnitateExterna;
  final List<String> seriiUnitatiInterne;
  final String agentFrigorific;
  final double capacitateBTU;
  final DateTime dataInstalare;
  final String numarPVMontaj;
  final String jobId;
  final String technicianInstalare;
  final int garantieLuni;
  final DateTime? ultimaInterventieData;
  final String? ultimaInterventieId;
  final int? intervalServiceRecomandat;
  /// 'functional' | 'defect' | 'in_service' | 'casat'
  final String stare;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get dataExpirariiGarantiei =>
      DateTime(dataInstalare.year, dataInstalare.month + garantieLuni,
          dataInstalare.day);

  bool get garantieActiva =>
      garantieLuni > 0 && DateTime.now().isBefore(dataExpirariiGarantiei);

  bool get necesitaService {
    final interval = intervalServiceRecomandat;
    if (interval == null || interval <= 0) return false;
    final ultima = ultimaInterventieData ?? dataInstalare;
    final luniDeLaUltima =
        DateTime.now().difference(ultima).inDays ~/ 30;
    return luniDeLaUltima >= interval;
  }

  int get zileRamasGarantie =>
      dataExpirariiGarantiei.difference(DateTime.now()).inDays;

  String get descriere => '$marca $model'.trim();

  EchipamentInstalat copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? adresaInstalare,
    String? tipEchipament,
    String? marca,
    String? model,
    String? serieUnitateExterna,
    List<String>? seriiUnitatiInterne,
    String? agentFrigorific,
    double? capacitateBTU,
    DateTime? dataInstalare,
    String? numarPVMontaj,
    String? jobId,
    String? technicianInstalare,
    int? garantieLuni,
    DateTime? ultimaInterventieData,
    String? ultimaInterventieId,
    int? intervalServiceRecomandat,
    String? stare,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      EchipamentInstalat(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        adresaInstalare: adresaInstalare ?? this.adresaInstalare,
        tipEchipament: tipEchipament ?? this.tipEchipament,
        marca: marca ?? this.marca,
        model: model ?? this.model,
        serieUnitateExterna: serieUnitateExterna ?? this.serieUnitateExterna,
        seriiUnitatiInterne: seriiUnitatiInterne ?? this.seriiUnitatiInterne,
        agentFrigorific: agentFrigorific ?? this.agentFrigorific,
        capacitateBTU: capacitateBTU ?? this.capacitateBTU,
        dataInstalare: dataInstalare ?? this.dataInstalare,
        numarPVMontaj: numarPVMontaj ?? this.numarPVMontaj,
        jobId: jobId ?? this.jobId,
        technicianInstalare: technicianInstalare ?? this.technicianInstalare,
        garantieLuni: garantieLuni ?? this.garantieLuni,
        ultimaInterventieData:
            ultimaInterventieData ?? this.ultimaInterventieData,
        ultimaInterventieId: ultimaInterventieId ?? this.ultimaInterventieId,
        intervalServiceRecomandat:
            intervalServiceRecomandat ?? this.intervalServiceRecomandat,
        stare: stare ?? this.stare,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'client_id': clientId,
        'client_name': clientName,
        'adresa_instalare': adresaInstalare,
        'tip_echipament': tipEchipament,
        'marca': marca,
        'model': model,
        'serie_unitate_externa': serieUnitateExterna,
        'serii_unitati_interne': seriiUnitatiInterne,
        'agent_frigorific': agentFrigorific,
        'capacitate_btu': capacitateBTU,
        'data_instalare': dataInstalare.toIso8601String(),
        'numar_pv_montaj': numarPVMontaj,
        'job_id': jobId,
        'technician_instalare': technicianInstalare,
        'garantie_luni': garantieLuni,
        'ultima_interventie_data': ultimaInterventieData?.toIso8601String(),
        'ultima_interventie_id': ultimaInterventieId,
        'interval_service_recomandat': intervalServiceRecomandat,
        'stare': stare,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EchipamentInstalat.fromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return EchipamentInstalat(
      id: (m['id'] ?? '').toString(),
      clientId: (m['client_id'] ?? '').toString(),
      clientName: (m['client_name'] ?? '').toString(),
      adresaInstalare: (m['adresa_instalare'] ?? '').toString(),
      tipEchipament: (m['tip_echipament'] ?? '').toString(),
      marca: (m['marca'] ?? '').toString(),
      model: (m['model'] ?? '').toString(),
      serieUnitateExterna: (m['serie_unitate_externa'] ?? '').toString(),
      seriiUnitatiInterne:
          List<String>.from((m['serii_unitati_interne'] as List? ?? [])),
      agentFrigorific: (m['agent_frigorific'] ?? '').toString(),
      capacitateBTU: (m['capacitate_btu'] as num? ?? 0).toDouble(),
      dataInstalare:
          DateTime.tryParse((m['data_instalare'] ?? '').toString()) ?? now,
      numarPVMontaj: (m['numar_pv_montaj'] ?? '').toString(),
      jobId: (m['job_id'] ?? '').toString(),
      technicianInstalare: (m['technician_instalare'] ?? '').toString(),
      garantieLuni: (m['garantie_luni'] as num? ?? 0).toInt(),
      ultimaInterventieData: DateTime.tryParse(
          (m['ultima_interventie_data'] ?? '').toString()),
      ultimaInterventieId: m['ultima_interventie_id'] as String?,
      intervalServiceRecomandat:
          (m['interval_service_recomandat'] as num?)?.toInt(),
      stare: (m['stare'] ?? 'functional').toString(),
      note: (m['note'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((m['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((m['updated_at'] ?? '').toString()) ?? now,
    );
  }
}
