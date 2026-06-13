class ObiectivLunar {
  const ObiectivLunar({
    required this.id,
    required this.an,
    required this.luna,
    required this.createdAt,
    this.targetIncasariRON = 0,
    this.targetLucrariNoi = 0,
    this.targetProgramariRON = 0,
    this.targetOferteTrimise = 0,
    this.targetRataConversie = 0,
    this.note = '',
  });

  final String id;
  final int an;
  final int luna;
  final double targetIncasariRON;
  final double targetLucrariNoi;
  final double targetProgramariRON;
  final double targetOferteTrimise;
  final double targetRataConversie;
  final String note;
  final DateTime createdAt;

  ObiectivLunar copyWith({
    String? id,
    int? an,
    int? luna,
    double? targetIncasariRON,
    double? targetLucrariNoi,
    double? targetProgramariRON,
    double? targetOferteTrimise,
    double? targetRataConversie,
    String? note,
    DateTime? createdAt,
  }) =>
      ObiectivLunar(
        id: id ?? this.id,
        an: an ?? this.an,
        luna: luna ?? this.luna,
        targetIncasariRON: targetIncasariRON ?? this.targetIncasariRON,
        targetLucrariNoi: targetLucrariNoi ?? this.targetLucrariNoi,
        targetProgramariRON: targetProgramariRON ?? this.targetProgramariRON,
        targetOferteTrimise: targetOferteTrimise ?? this.targetOferteTrimise,
        targetRataConversie: targetRataConversie ?? this.targetRataConversie,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'an': an,
        'luna': luna,
        'target_incasari_ron': targetIncasariRON,
        'target_lucrari_noi': targetLucrariNoi,
        'target_programari_ron': targetProgramariRON,
        'target_oferte_trimise': targetOferteTrimise,
        'target_rata_conversie': targetRataConversie,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory ObiectivLunar.fromMap(Map<String, dynamic> m) => ObiectivLunar(
        id: (m['id'] ?? '').toString(),
        an: (m['an'] as num? ?? DateTime.now().year).toInt(),
        luna: (m['luna'] as num? ?? DateTime.now().month).toInt(),
        targetIncasariRON:
            (m['target_incasari_ron'] as num? ?? 0).toDouble(),
        targetLucrariNoi:
            (m['target_lucrari_noi'] as num? ?? 0).toDouble(),
        targetProgramariRON:
            (m['target_programari_ron'] as num? ?? 0).toDouble(),
        targetOferteTrimise:
            (m['target_oferte_trimise'] as num? ?? 0).toDouble(),
        targetRataConversie:
            (m['target_rata_conversie'] as num? ?? 0).toDouble(),
        note: (m['note'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class ObiectivProgress {
  const ObiectivProgress({
    required this.obiectiv,
    required this.incasariActuale,
    required this.lucrariNoi,
    required this.programariRON,
    required this.oferteTrimise,
    required this.rataConversieActuala,
  });

  final ObiectivLunar obiectiv;
  final double incasariActuale;
  final double lucrariNoi;
  final double programariRON;
  final double oferteTrimise;
  final double rataConversieActuala;

  double get progresIncasari => obiectiv.targetIncasariRON > 0
      ? (incasariActuale / obiectiv.targetIncasariRON * 100).clamp(0, 150)
      : 0;

  double get progresLucrari => obiectiv.targetLucrariNoi > 0
      ? (lucrariNoi / obiectiv.targetLucrariNoi * 100).clamp(0, 150)
      : 0;

  double get progresProgramari => obiectiv.targetProgramariRON > 0
      ? (programariRON / obiectiv.targetProgramariRON * 100).clamp(0, 150)
      : 0;

  double get progresOferte => obiectiv.targetOferteTrimise > 0
      ? (oferteTrimise / obiectiv.targetOferteTrimise * 100).clamp(0, 150)
      : 0;

  double get progresConversie => obiectiv.targetRataConversie > 0
      ? (rataConversieActuala / obiectiv.targetRataConversie * 100).clamp(0, 150)
      : 0;
}
