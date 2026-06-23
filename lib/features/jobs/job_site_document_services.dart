import 'dart:convert';

import '../../core/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'job_models.dart';
import 'job_site_document_models.dart';

class JobSiteDocumentDraftTemplate {
  const JobSiteDocumentDraftTemplate({
    required this.documentType,
    this.documentTitle = '',
    this.documentSubtitle = '',
    this.observations = '',
    this.conclusions = '',
    this.probesSummary = '',
    this.functionalStatus = '',
  });

  final JobSiteDocumentType documentType;
  final String documentTitle;
  final String documentSubtitle;
  final String observations;
  final String conclusions;
  final String probesSummary;
  final String functionalStatus;

  JobSiteDocumentDraftTemplate copyWith({
    JobSiteDocumentType? documentType,
    String? documentTitle,
    String? documentSubtitle,
    String? observations,
    String? conclusions,
    String? probesSummary,
    String? functionalStatus,
  }) {
    return JobSiteDocumentDraftTemplate(
      documentType: documentType ?? this.documentType,
      documentTitle: documentTitle ?? this.documentTitle,
      documentSubtitle: documentSubtitle ?? this.documentSubtitle,
      observations: observations ?? this.observations,
      conclusions: conclusions ?? this.conclusions,
      probesSummary: probesSummary ?? this.probesSummary,
      functionalStatus: functionalStatus ?? this.functionalStatus,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'document_type': documentType.storageValue,
        'document_title': documentTitle,
        'document_subtitle': documentSubtitle,
        'observations': observations,
        'conclusions': conclusions,
        'probes_summary': probesSummary,
        'functional_status': functionalStatus,
      };

  factory JobSiteDocumentDraftTemplate.fromMap(Map<String, dynamic> map) {
    return JobSiteDocumentDraftTemplate(
      documentType: JobSiteDocumentType.fromValue(
          map['document_type'] ?? map['documentType']),
      documentTitle:
          (map['document_title'] ?? map['documentTitle'] ?? '').toString(),
      documentSubtitle:
          (map['document_subtitle'] ?? map['documentSubtitle'] ?? '')
              .toString(),
      observations: (map['observations'] ?? '').toString(),
      conclusions: (map['conclusions'] ?? '').toString(),
      probesSummary:
          (map['probes_summary'] ?? map['probesSummary'] ?? '').toString(),
      functionalStatus:
          (map['functional_status'] ?? map['functionalStatus'] ?? '')
              .toString(),
    );
  }
}

class JobSiteDocumentPdfFoundationService {
  const JobSiteDocumentPdfFoundationService();

  String buildSuggestedFileName(JobSiteDocumentRecord document) {
    final safeNumber = document.documentNumber.trim().isEmpty
        ? document.id
        : document.documentNumber.trim();
    final normalized = safeNumber.replaceAll(RegExp(r'[\\/:*?"<>| ]+'), '_');
    return '${document.documentType.shortCode}_$normalized.pdf';
  }
}

class JobSiteDocumentTemplateService {
  const JobSiteDocumentTemplateService({
    this.pdfFoundationService = const JobSiteDocumentPdfFoundationService(),
  });

  static const String _draftTemplateKeyPrefix =
      'job_site_document_draft_template_v1_';

  final JobSiteDocumentPdfFoundationService pdfFoundationService;

  Future<JobSiteDocumentRecord> createDraft({
    required JobRecord job,
    required String clientName,
    required JobSiteDocumentType documentType,
    required String documentNumber,
  }) async {
    final now = DateTime.now();
    final resources = await _resolveResources(job);
    final draftTemplate = await loadDraftTemplate(documentType);
    final tokenValues = _tokenValues(
      job: job,
      clientName: clientName,
      documentType: documentType,
    );
    final defaultTitle = _defaultTitle(job, documentType);
    final defaultSubtitle = _defaultSubtitle(job, documentType);
    final defaultObservations = _defaultObservations(documentType);
    final defaultConclusions = _defaultConclusions(documentType);
    final defaultFunctionalStatus = _defaultFunctionalStatus(documentType);
    final defaultProbesSummary = _defaultProbesSummary(documentType);
    final base = JobSiteDocumentRecord(
      id: 'job-site-document-${now.microsecondsSinceEpoch}',
      jobId: job.id,
      documentType: documentType,
      documentTitle: _resolveTemplateText(
        draftTemplate.documentTitle,
        tokenValues,
        fallback: defaultTitle,
      ),
      documentSubtitle: _resolveTemplateText(
        draftTemplate.documentSubtitle,
        tokenValues,
        fallback: defaultSubtitle,
      ),
      documentNumber: documentNumber,
      documentDate: now,
      beneficiaryRepresentative: job.contactPerson.trim().isNotEmpty
          ? job.contactPerson.trim()
          : clientName.trim(),
      executorRepresentative: job.assignedTeamLabel.trim().isNotEmpty
          ? job.assignedTeamLabel.trim()
          : 'Reprezentant executant',
      projectName: job.title.trim().isEmpty ? job.jobCode : job.title.trim(),
      location: _buildLocation(job),
      observations: _resolveTemplateText(
        draftTemplate.observations,
        tokenValues,
        fallback: defaultObservations,
      ),
      conclusions: _resolveTemplateText(
        draftTemplate.conclusions,
        tokenValues,
        fallback: defaultConclusions,
      ),
      clientSignatureBase64: '',
      executorSignatureBase64: '',
      registryEntryId: '',
      documentTypeForRegistry: documentType.registryCategory,
      sourceModule: 'lucrari',
      generatedDocumentPath: '',
      generatedDocumentFileName: '',
      createdAt: now,
      updatedAt: now,
      status: 'draft',
      functionalStatus: _resolveTemplateText(
        draftTemplate.functionalStatus,
        tokenValues,
        fallback: defaultFunctionalStatus,
      ),
      measurements: _measurementsFor(documentType),
      checkItems: _checkItemsFor(documentType),
      annexes: _annexesFor(resources, documentType),
      probesSummary: _resolveTemplateText(
        draftTemplate.probesSummary,
        tokenValues,
        fallback: defaultProbesSummary,
      ),
      remediationDeadline: null,
      trainingProvided: documentType != JobSiteDocumentType.pvMontaj,
      preparedForNextStep: _preparedForNextStep(documentType),
    );
    return base.copyWith(
      generatedDocumentFileName:
          pdfFoundationService.buildSuggestedFileName(base),
    );
  }

  Future<JobSiteDocumentDraftTemplate> loadDraftTemplate(
    JobSiteDocumentType documentType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templateKey(documentType));
    if (raw == null || raw.trim().isEmpty) {
      return JobSiteDocumentDraftTemplate(documentType: documentType);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return JobSiteDocumentDraftTemplate(documentType: documentType);
      }
      return JobSiteDocumentDraftTemplate.fromMap(
        Map<String, dynamic>.from(decoded),
      ).copyWith(documentType: documentType);
    } catch (_) {
      return JobSiteDocumentDraftTemplate(documentType: documentType);
    }
  }

  Future<void> saveDraftTemplate(JobSiteDocumentDraftTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _templateKey(template.documentType),
      jsonEncode(template.toMap()),
    );
  }

  Future<void> resetDraftTemplate(JobSiteDocumentType documentType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_templateKey(documentType));
  }

  String _templateKey(JobSiteDocumentType documentType) {
    return '$_draftTemplateKeyPrefix${documentType.storageValue}';
  }

  Map<String, String> _tokenValues({
    required JobRecord job,
    required String clientName,
    required JobSiteDocumentType documentType,
  }) {
    return <String, String>{
      'project': job.title.trim().isEmpty ? job.jobCode : job.title.trim(),
      'jobCode': job.jobCode.trim(),
      'location': _buildLocation(job),
      'client': clientName.trim(),
      'team': job.assignedTeamLabel.trim(),
      'type': documentType.label,
    };
  }

  String _resolveTemplateText(
    String template,
    Map<String, String> tokenValues, {
    required String fallback,
  }) {
    final source = template.trim().isEmpty ? fallback : template;
    var output = source;
    tokenValues.forEach((key, value) {
      output = output.replaceAll('{$key}', value.trim());
    });
    return output;
  }

  Future<_ResolvedDocumentResources> _resolveResources(JobRecord job) async {
    // 0. Prioritate maxima: liniiPlanificate — sursa unificata folosita de tab
    // Situatie/Executie. Daca exista, anexele se construiesc direct din ea.
    final fromLinii = _fromLiniiPlanificate(job);
    if (fromLinii.materials.isNotEmpty ||
        fromLinii.labor.isNotEmpty ||
        fromLinii.equipment.isNotEmpty) {
      return _ResolvedDocumentResources(
        materials: fromLinii.materials,
        equipment: fromLinii.equipment,
        labor: fromLinii.labor,
        beneficiaryEquipment: job.beneficiarySuppliedEquipment
            .map(
              (item) => JobSiteDocumentAnnexItem(
                id: item.id,
                label: item.name,
                quantity: _formatNumber(item.quantity),
                unit: 'buc',
                details: <String>[
                  if (item.equipmentType.trim().isNotEmpty)
                    item.equipmentType.trim(),
                  if (item.brand.trim().isNotEmpty) item.brand.trim(),
                  if (item.model.trim().isNotEmpty) item.model.trim(),
                  if (item.serialNumber.trim().isNotEmpty)
                    'SN ${item.serialNumber.trim()}',
                ].join(' | '),
                source: 'job_beneficiary_equipment',
              ),
            )
            .toList(growable: false),
        beneficiaryMaterials: job.beneficiarySuppliedMaterials
            .map(
              (item) => JobSiteDocumentAnnexItem(
                id: item.id,
                label: item.name,
                quantity: _formatNumber(item.quantity),
                unit: item.unit,
                details: item.notes.trim(),
                source: 'job_beneficiary_materials',
              ),
            )
            .toList(growable: false),
      );
    }

    final jobMaterials = _fromJobMaterials(job);
    final jobEquipment = _fromJobEquipment(job, jobMaterials);

    if (jobMaterials.isNotEmpty || jobEquipment.isNotEmpty) {
      return _ResolvedDocumentResources(
        materials: jobMaterials,
        equipment: jobEquipment,
        beneficiaryEquipment: job.beneficiarySuppliedEquipment
            .map(
              (item) => JobSiteDocumentAnnexItem(
                id: item.id,
                label: item.name,
                quantity: _formatNumber(item.quantity),
                unit: 'buc',
                details: <String>[
                  if (item.equipmentType.trim().isNotEmpty)
                    item.equipmentType.trim(),
                  if (item.brand.trim().isNotEmpty) item.brand.trim(),
                  if (item.model.trim().isNotEmpty) item.model.trim(),
                  if (item.serialNumber.trim().isNotEmpty)
                    'SN ${item.serialNumber.trim()}',
                ].join(' | '),
                source: 'job_beneficiary_equipment',
              ),
            )
            .toList(growable: false),
        beneficiaryMaterials: job.beneficiarySuppliedMaterials
            .map(
              (item) => JobSiteDocumentAnnexItem(
                id: item.id,
                label: item.name,
                quantity: _formatNumber(item.quantity),
                unit: item.unit,
                details: item.notes.trim(),
                source: 'job_beneficiary_materials',
              ),
            )
            .toList(growable: false),
      );
    }

    final documentFallback = _fromJobDocuments(job);
    if (documentFallback.materials.isNotEmpty ||
        documentFallback.equipment.isNotEmpty) {
      return documentFallback;
    }

    return _fromOfferBundle(job);
  }

  /// Construieste resursele direct din `job.liniiPlanificate` (sursa unificata
  /// planificat vs realizat). Liniile de manopera ajung in [labor], restul in
  /// [materials]; echipamentele se deduc dupa cuvinte-cheie din [materials].
  _ResolvedDocumentResources _fromLiniiPlanificate(JobRecord job) {
    final lines = job.liniiPlanificate;
    if (lines.isEmpty) return const _ResolvedDocumentResources();

    final materials = <JobSiteDocumentAnnexItem>[];
    final labor = <JobSiteDocumentAnnexItem>[];
    for (final line in lines) {
      final label = line.denumire.trim();
      if (label.isEmpty) continue;
      // Cantitate / pret: prefera valoarea reala daca exista, altfel ofertata.
      final qty =
          line.cantitateReala > 0 ? line.cantitateReala : line.cantitateOferta;
      final price = line.pretUnitarReal > 0
          ? line.pretUnitarReal
          : line.pretUnitarOferta;
      final categorie = line.categorie.trim().toLowerCase();
      final details = <String>[
        _categorieLabel(line.categorie),
        if (price > 0) 'Pret unitar ${_formatNumber(price)}',
        if (line.observatii.trim().isNotEmpty) line.observatii.trim(),
      ].where((item) => item.isNotEmpty).join(' | ');
      final item = JobSiteDocumentAnnexItem(
        id: line.id,
        label: label,
        quantity: _formatNumber(qty),
        unit: line.um,
        details: details,
        source: 'job_linii_planificate',
      );
      if (categorie == 'manopera') {
        labor.add(item);
      } else {
        materials.add(item);
      }
    }

    return _ResolvedDocumentResources(
      materials: materials,
      equipment:
          materials.where((item) => _looksLikeEquipment(item.label)).toList(
                growable: false,
              ),
      labor: labor,
    );
  }

  String _categorieLabel(String categorie) {
    switch (categorie.trim().toLowerCase()) {
      case 'material':
        return 'Material';
      case 'manopera':
        return 'Manopera';
      case 'transport':
        return 'Transport';
      default:
        return categorie.trim().isEmpty ? '' : categorie.trim();
    }
  }

  List<JobSiteDocumentAnnexItem> _fromJobMaterials(JobRecord job) {
    return job.materials
        .map((row) => _annexItemFromMap(row, source: 'job_materials'))
        .where((item) => item.label.isNotEmpty)
        .toList(growable: false);
  }

  List<JobSiteDocumentAnnexItem> _fromJobEquipment(
    JobRecord job,
    List<JobSiteDocumentAnnexItem> materials,
  ) {
    final items = <JobSiteDocumentAnnexItem>[
      ...job.beneficiarySuppliedEquipment.map(
        (item) => JobSiteDocumentAnnexItem(
          id: item.id,
          label: item.name,
          quantity: _formatNumber(item.quantity),
          unit: 'buc',
          details: <String>[
            if (item.equipmentType.trim().isNotEmpty) item.equipmentType.trim(),
            if (item.brand.trim().isNotEmpty) item.brand.trim(),
            if (item.model.trim().isNotEmpty) item.model.trim(),
            if (item.serialNumber.trim().isNotEmpty)
              'SN ${item.serialNumber.trim()}',
          ].join(' | '),
          source: 'job_beneficiary_equipment',
        ),
      ),
      ...materials.where((item) => _looksLikeEquipment(item.label)),
    ];
    return _dedupeItems(items);
  }

  _ResolvedDocumentResources _fromJobDocuments(JobRecord job) {
    final candidates = job.documents
        .map((item) => Map<String, dynamic>.from(item))
        .where((row) {
      final type =
          '${row['type'] ?? row['tipDocument'] ?? ''}'.trim().toLowerCase();
      return type.contains('oferta') || type.contains('deviz');
    }).toList(growable: false)
      ..sort((a, b) {
        final left = '${a['updatedAt'] ?? a['createdAt'] ?? ''}';
        final right = '${b['updatedAt'] ?? b['createdAt'] ?? ''}';
        return right.compareTo(left);
      });

    for (final row in candidates) {
      final rawMaterials = row['materialsSnapshot'];
      if (rawMaterials is! List || rawMaterials.isEmpty) continue;
      final materials = rawMaterials
          .whereType<Map>()
          .map(
            (item) => _annexItemFromMap(
              Map<String, dynamic>.from(item),
              source: 'job_document_snapshot',
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList(growable: false);
      if (materials.isEmpty) continue;
      return _ResolvedDocumentResources(
        materials: materials,
        equipment:
            materials.where((item) => _looksLikeEquipment(item.label)).toList(
                  growable: false,
                ),
        beneficiaryEquipment: const <JobSiteDocumentAnnexItem>[],
        beneficiaryMaterials: const <JobSiteDocumentAnnexItem>[],
      );
    }

    return const _ResolvedDocumentResources();
  }

  Future<_ResolvedDocumentResources> _fromOfferBundle(JobRecord job) async {
    final offerId = job.sourceOfferId.trim();
    if (offerId.isEmpty) {
      return const _ResolvedDocumentResources();
    }

    try {
      final repository = await AppRepository.create();
      final bundle = await repository.loadOfferBundle(offerId);
      if (bundle == null) return const _ResolvedDocumentResources();
      final materials = bundle.lines
          .map(
            (line) => JobSiteDocumentAnnexItem(
              id: line.materialId,
              label: line.materialName,
              quantity: _formatNumber(line.quantity),
              unit: line.unit,
              details: line.unitPrice > 0
                  ? 'Pret unitar ${line.unitPrice.toStringAsFixed(2)}'
                  : '',
              source: 'offer_bundle',
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList(growable: false);
      return _ResolvedDocumentResources(
        materials: materials,
        equipment:
            materials.where((item) => _looksLikeEquipment(item.label)).toList(
                  growable: false,
                ),
        beneficiaryEquipment: const <JobSiteDocumentAnnexItem>[],
        beneficiaryMaterials: const <JobSiteDocumentAnnexItem>[],
      );
    } catch (_) {
      return const _ResolvedDocumentResources();
    }
  }

  List<JobSiteDocumentAnnex> _annexesFor(
    _ResolvedDocumentResources resources,
    JobSiteDocumentType type,
  ) {
    final materials = _materialsAnnex(resources.materials);
    final equipments = _equipmentAnnex(resources);
    final laborAnnex = _laborAnnex(resources.labor);
    final commissionedEquipment =
        _commissionedEquipmentAnnex(resources.equipment);
    final airMaterials = _airDistributionAnnex(resources.materials);
    final airNetwork = _airNetworkSummaryAnnex(resources.materials);

    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return <JobSiteDocumentAnnex>[
          materials,
          if (laborAnnex.items.isNotEmpty) laborAnnex,
          equipments,
        ];
      case JobSiteDocumentType.pif:
        return <JobSiteDocumentAnnex>[
          commissionedEquipment,
          airMaterials,
          airNetwork,
          equipments,
          if (laborAnnex.items.isNotEmpty) laborAnnex,
        ];
      case JobSiteDocumentType.pvReceptieServicii:
        // Document simplu de confirmare — fără anexe generate automat.
        return const <JobSiteDocumentAnnex>[];
    }
  }

  JobSiteDocumentAnnex _laborAnnex(List<JobSiteDocumentAnnexItem> items) {
    return JobSiteDocumentAnnex(
      key: 'lista_manopera',
      title: 'Anexa - manopera / lucrari',
      description:
          'Generata automat din executia reala (liniile planificate ale lucrarii).',
      summary: 'Total pozitii manopera: ${items.length}',
      items: items,
    );
  }

  JobSiteDocumentAnnex _materialsAnnex(List<JobSiteDocumentAnnexItem> items) {
    return JobSiteDocumentAnnex(
      key: 'lista_materiale_montate',
      title: 'Anexa - lista materiale montate',
      description:
          'Generata automat din executia reala sau, daca lipseste, din Oferta / Deviz.',
      summary: 'Total pozitii materiale: ${items.length}',
      items: items,
    );
  }

  JobSiteDocumentAnnex _equipmentAnnex(_ResolvedDocumentResources resources) {
    final items = _dedupeItems(<JobSiteDocumentAnnexItem>[
      ...resources.equipment,
      ...resources.beneficiaryEquipment,
    ]);
    return JobSiteDocumentAnnex(
      key: 'lista_echipamente_montate',
      title: 'Anexa - lista echipamente montate',
      description:
          'Generata automat din lucrare, cu fallback controlat din Oferta / Deviz.',
      summary: 'Total pozitii echipamente: ${items.length}',
      items: items,
    );
  }

  JobSiteDocumentAnnex _commissionedEquipmentAnnex(
    List<JobSiteDocumentAnnexItem> items,
  ) {
    return JobSiteDocumentAnnex(
      key: 'echipamente_puse_in_functiune',
      title: 'Anexa - echipamente puse in functiune',
      description:
          'Baza de anexa pentru echipamentele validate in etapa de PIF.',
      summary: 'Total pozitii echipamente PIF: ${items.length}',
      items: items,
    );
  }

  JobSiteDocumentAnnex _airDistributionAnnex(
    List<JobSiteDocumentAnnexItem> items,
  ) {
    final filtered = items
        .where((item) => _looksLikeAirDistributionMaterial(item.label))
        .toList(growable: false);
    return JobSiteDocumentAnnex(
      key: 'materiale_instalatii_puse_in_functiune',
      title: 'Anexa - materiale / instalatii puse in functiune',
      description:
          'Pozitii relevante pentru ventilatie, distributie aer sau instalatii conexe.',
      summary: 'Total pozitii instalatii: ${filtered.length}',
      items: filtered,
    );
  }

  JobSiteDocumentAnnex _airNetworkSummaryAnnex(
    List<JobSiteDocumentAnnexItem> items,
  ) {
    final filtered = items
        .where((item) => _looksLikeAirDistributionMaterial(item.label))
        .toList(growable: false);
    return JobSiteDocumentAnnex(
      key: 'retea_distributie_aer_sumar',
      title: 'Anexa - retea distributie aer / sumar',
      description: 'Sumar automat al pozitiei de distributie aer.',
      summary: 'Pozitii: ${filtered.length}',
      items: filtered,
    );
  }

  String _defaultTitle(JobRecord job, JobSiteDocumentType type) {
    final baseProject =
        job.title.trim().isNotEmpty ? job.title.trim() : job.jobCode;
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'Document montaj / executie - $baseProject';
      case JobSiteDocumentType.pif:
        return 'Document PIF - $baseProject';
      case JobSiteDocumentType.pvReceptieServicii:
        return 'Proces-verbal receptie servicii - $baseProject';
    }
  }

  String _defaultSubtitle(JobRecord job, JobSiteDocumentType type) {
    final location = _buildLocation(job);
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return location.isEmpty
            ? 'Montaj / executie'
            : 'Montaj / executie | $location';
      case JobSiteDocumentType.pif:
        return location.isEmpty
            ? 'PIF - Punere in Functiune'
            : 'PIF - Punere in Functiune | $location';
      case JobSiteDocumentType.pvReceptieServicii:
        return location.isEmpty
            ? 'Receptie servicii'
            : 'Receptie servicii | $location';
    }
  }

  String _buildLocation(JobRecord job) {
    final parts = <String>[
      if (job.location.trim().isNotEmpty) job.location.trim(),
      if (job.city.trim().isNotEmpty) job.city.trim(),
      if (job.county.trim().isNotEmpty) job.county.trim(),
    ];
    return parts.join(', ');
  }

  String _defaultObservations(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'S-au verificat vizual montajul, materialele si echipamentele instalate. Documentul ramane baza pentru etapa de PIF.';
      case JobSiteDocumentType.pif:
        return 'S-au verificat partea electrica, automatizarea, probele functionale, masuratorile si functionarea sistemului pus in functiune.';
      case JobSiteDocumentType.pvReceptieServicii:
        // Lasat gol — utilizatorul descrie liber serviciile efectuate.
        return '';
    }
  }

  String _defaultConclusions(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'Lucrarea de montaj / executie este pregatita pentru verificari finale si, dupa caz, pentru etapa de punere in functiune.';
      case JobSiteDocumentType.pif:
        return 'Sistemul este pus in functiune si poate fi exploatat in regim normal dupa predarea catre beneficiar, cu respectarea instructiunilor de utilizare si mentenanta.';
      case JobSiteDocumentType.pvReceptieServicii:
        // Lasat gol — constatari / observatii optionale completate manual.
        return '';
    }
  }

  String _defaultFunctionalStatus(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'pregatit pentru pif';
      case JobSiteDocumentType.pif:
        return 'pus in functiune';
      case JobSiteDocumentType.pvReceptieServicii:
        return '';
    }
  }

  String _defaultProbesSummary(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'Verificari vizuale si tehnice preliminare.';
      case JobSiteDocumentType.pif:
        return 'Verificari electrice, probe functionale si masuratori (debite, presiuni, temperaturi).';
      case JobSiteDocumentType.pvReceptieServicii:
        return '';
    }
  }

  String _preparedForNextStep(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return 'pregatire etapa PIF';
      case JobSiteDocumentType.pif:
        return 'predare beneficiar';
      case JobSiteDocumentType.pvReceptieServicii:
        return '';
    }
  }

  List<JobSiteDocumentCheckItem> _checkItemsFor(JobSiteDocumentType type) {
    List<JobSiteDocumentCheckItem> build(String section, List<String> labels) {
      return List<JobSiteDocumentCheckItem>.generate(
        labels.length,
        (index) => JobSiteDocumentCheckItem(
          id: '$section-$index',
          sectionKey: section,
          label: labels[index],
        ),
        growable: false,
      );
    }

    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return <JobSiteDocumentCheckItem>[
          ...build('montaj_fizic', <String>[
            'Materialele principale sunt montate conform situatiei din teren',
            'Echipamentele principale sunt pozitionate si fixate',
          ]),
          ...build('verificari_vizuale', <String>[
            'Aspect vizual conform si fara deteriorari evidente',
            'Etichetarea / accesul de service este asigurat',
          ]),
          ...build('verificari_tehnice_preliminare', <String>[
            'Traseele si conexiunile sunt pregatite pentru etapa PIF',
            'Sunt semnalate eventuale remedieri sau completari',
          ]),
        ];
      case JobSiteDocumentType.pif:
        return <JobSiteDocumentCheckItem>[
          ...build('verificari_pre_pornire', <String>[
            'Traseele si conexiunile au fost verificate',
            'Sistemul este pregatit pentru pornire',
          ]),
          ...build('verificari_electrice', <String>[
            'Alimentarea electrica a fost verificata',
            'Protectiile si conexiunile sunt conforme',
          ]),
          ...build('probe_functionale', <String>[
            'Sistemul porneste si functioneaza stabil',
            'Comenzile si automatizarea raspund corect',
          ]),
          ...build('instruire_beneficiar', <String>[
            'Beneficiarul a fost instruit privind exploatarea',
            'Beneficiarul a fost instruit privind mentenanta de baza',
          ]),
        ];
      case JobSiteDocumentType.pvReceptieServicii:
        return const <JobSiteDocumentCheckItem>[];
    }
  }

  List<JobSiteDocumentMeasurement> _measurementsFor(JobSiteDocumentType type) {
    switch (type) {
      case JobSiteDocumentType.pvMontaj:
        return const <JobSiteDocumentMeasurement>[
          JobSiteDocumentMeasurement(
            id: 'montaj-materiale',
            sectionKey: 'montaj_fizic',
            label: 'Pozitii materiale montate',
            unit: 'pozitii',
          ),
          JobSiteDocumentMeasurement(
            id: 'montaj-echipamente',
            sectionKey: 'montaj_fizic',
            label: 'Pozitii echipamente montate',
            unit: 'pozitii',
          ),
        ];
      case JobSiteDocumentType.pif:
        return const <JobSiteDocumentMeasurement>[
          JobSiteDocumentMeasurement(
            id: 'pif-debit',
            sectionKey: 'probe_functionale',
            label: 'Debit aer / agent',
            unit: 'mc/h',
          ),
          JobSiteDocumentMeasurement(
            id: 'pif-presiune',
            sectionKey: 'probe_functionale',
            label: 'Presiune proba',
            unit: 'bar',
          ),
          JobSiteDocumentMeasurement(
            id: 'pif-temperatura',
            sectionKey: 'probe_functionale',
            label: 'Temperatura refulare',
            unit: 'C',
          ),
          JobSiteDocumentMeasurement(
            id: 'pif-curent',
            sectionKey: 'verificari_electrice',
            label: 'Curent absorbit',
            unit: 'A',
          ),
        ];
      case JobSiteDocumentType.pvReceptieServicii:
        return const <JobSiteDocumentMeasurement>[];
    }
  }

  JobSiteDocumentAnnexItem _annexItemFromMap(
    Map<String, dynamic> row, {
    required String source,
  }) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = (row[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return JobSiteDocumentAnnexItem(
      id: read(const <String>['id', 'material_id']),
      label: read(const <String>['name', 'denumire', 'label', 'material_name']),
      quantity: read(const <String>['qty', 'quantity', 'cantitate']),
      unit: read(const <String>['um', 'unit']),
      details: <String>[
        read(const <String>['category', 'categorie']),
        read(const <String>['notes', 'observatii']),
      ].where((item) => item.isNotEmpty).join(' | '),
      source: source,
    );
  }

  List<JobSiteDocumentAnnexItem> _dedupeItems(
    List<JobSiteDocumentAnnexItem> items,
  ) {
    final map = <String, JobSiteDocumentAnnexItem>{};
    for (final item in items) {
      final key =
          '${item.label.toLowerCase()}|${item.quantity}|${item.unit}|${item.source}';
      map[key] = item;
    }
    return map.values.toList(growable: false);
  }

  bool _looksLikeEquipment(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    const keywords = <String>[
      'unitate',
      'vrf',
      'recuperator',
      'ventilator',
      'controller',
      'centrala',
      'split',
      'chiller',
      'pompa',
    ];
    return keywords.any(normalized.contains);
  }

  bool _looksLikeAirDistributionMaterial(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    const keywords = <String>[
      'tubul',
      'conduct',
      'aer',
      'grila',
      'anemostat',
      'difuzor',
      'plenum',
      'clapeta',
      'ventilatie',
    ];
    return keywords.any(normalized.contains);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _ResolvedDocumentResources {
  const _ResolvedDocumentResources({
    this.materials = const <JobSiteDocumentAnnexItem>[],
    this.equipment = const <JobSiteDocumentAnnexItem>[],
    this.labor = const <JobSiteDocumentAnnexItem>[],
    this.beneficiaryEquipment = const <JobSiteDocumentAnnexItem>[],
    this.beneficiaryMaterials = const <JobSiteDocumentAnnexItem>[],
  });

  final List<JobSiteDocumentAnnexItem> materials;
  final List<JobSiteDocumentAnnexItem> equipment;
  final List<JobSiteDocumentAnnexItem> labor;
  final List<JobSiteDocumentAnnexItem> beneficiaryEquipment;
  final List<JobSiteDocumentAnnexItem> beneficiaryMaterials;
}
