/// Modele pentru sistemul Help inteligent cu conținut din Firestore + AI.
/// Distincte de HelpContent/HelpSection din lib/core/widgets/help_button.dart.
class HelpModule {
  const HelpModule({
    required this.moduleId,
    required this.titlu,
    required this.descriere,
    this.pasi = const [],
    this.faq = const [],
    this.sfaturi = const [],
    this.versiune = '1.0',
    required this.updatedAt,
  });

  final String moduleId;
  final String titlu;
  final String descriere;
  final List<HelpModuleStep> pasi;
  final List<HelpModuleFaq> faq;
  final List<String> sfaturi;
  final String versiune;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'module_id': moduleId,
        'titlu': titlu,
        'descriere': descriere,
        'pasi': pasi.map((p) => p.toMap()).toList(),
        'faq': faq.map((f) => f.toMap()).toList(),
        'sfaturi': sfaturi,
        'versiune': versiune,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory HelpModule.fromMap(Map<String, dynamic> m) => HelpModule(
        moduleId: (m['module_id'] ?? '').toString(),
        titlu: (m['titlu'] ?? '').toString(),
        descriere: (m['descriere'] ?? '').toString(),
        pasi: (m['pasi'] as List? ?? [])
            .map((e) => HelpModuleStep.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        faq: (m['faq'] as List? ?? [])
            .map((e) => HelpModuleFaq.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        sfaturi: (m['sfaturi'] as List? ?? []).map((e) => e.toString()).toList(),
        versiune: (m['versiune'] ?? '1.0').toString(),
        updatedAt: DateTime.tryParse((m['updated_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class HelpModuleStep {
  const HelpModuleStep({
    required this.nr,
    required this.titlu,
    required this.descriere,
    this.icon,
  });

  final int nr;
  final String titlu;
  final String descriere;
  final String? icon;

  Map<String, dynamic> toMap() => {
        'nr': nr,
        'titlu': titlu,
        'descriere': descriere,
        if (icon != null) 'icon': icon,
      };

  factory HelpModuleStep.fromMap(Map<String, dynamic> m) => HelpModuleStep(
        nr: (m['nr'] as num? ?? 0).toInt(),
        titlu: (m['titlu'] ?? '').toString(),
        descriere: (m['descriere'] ?? '').toString(),
        icon: m['icon']?.toString(),
      );
}

class HelpModuleFaq {
  const HelpModuleFaq({required this.intrebare, required this.raspuns});

  final String intrebare;
  final String raspuns;

  Map<String, dynamic> toMap() => {'intrebare': intrebare, 'raspuns': raspuns};

  factory HelpModuleFaq.fromMap(Map<String, dynamic> m) => HelpModuleFaq(
        intrebare: (m['intrebare'] ?? '').toString(),
        raspuns: (m['raspuns'] ?? '').toString(),
      );
}
