import 'package:flutter/material.dart';

import '../ai_assistant/ai_assistant_models.dart';
import '../ai_assistant/ai_assistant_requirement_models.dart';
import '../ai_assistant/ai_assistant_service.dart';
import '../clients/client_models.dart';
import '../field_sales/field_sales_models.dart';
import '../jobs/job_models.dart';
import 'offer_editor_defaults_store.dart';
import 'offer_models.dart';

class OfferRequirementAiDialog extends StatefulWidget {
  const OfferRequirementAiDialog({
    super.key,
    required this.aiAssistantService,
    required this.clients,
    required this.jobs,
    required this.defaults,
    required this.nextOfferNumber,
    required this.onCreateDraft,
    this.currentUserId,
    this.currentUserEmail,
  });

  final AiAssistantService aiAssistantService;
  final List<ClientRecord> clients;
  final List<JobRecord> jobs;
  final OfferEditorDefaults defaults;
  final String nextOfferNumber;
  final Future<void> Function(OfferRecord draftOffer) onCreateDraft;
  final String? currentUserId;
  final String? currentUserEmail;

  static Future<void> show({
    required BuildContext context,
    required AiAssistantService aiAssistantService,
    required List<ClientRecord> clients,
    required List<JobRecord> jobs,
    required OfferEditorDefaults defaults,
    required String nextOfferNumber,
    required Future<void> Function(OfferRecord draftOffer) onCreateDraft,
    String? currentUserId,
    String? currentUserEmail,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => OfferRequirementAiDialog(
        aiAssistantService: aiAssistantService,
        clients: clients,
        jobs: jobs,
        defaults: defaults,
        nextOfferNumber: nextOfferNumber,
        onCreateDraft: onCreateDraft,
        currentUserId: currentUserId,
        currentUserEmail: currentUserEmail,
      ),
    );
  }

  @override
  State<OfferRequirementAiDialog> createState() =>
      _OfferRequirementAiDialogState();
}

class _OfferRequirementAiDialogState extends State<OfferRequirementAiDialog> {
  final TextEditingController _requirementController = TextEditingController();
  final TextEditingController _operatorNotesController =
      TextEditingController();

  bool _analyzing = false;
  bool _creatingDraft = false;
  String? _selectedClientId;
  String? _selectedJobId;
  AiRequirementAnalysisResult? _analysis;

  @override
  void dispose() {
    _requirementController.dispose();
    _operatorNotesController.dispose();
    super.dispose();
  }

  ClientRecord? get _selectedClient {
    final selected = (_selectedClientId ?? '').trim();
    if (selected.isNotEmpty) {
      for (final item in widget.clients) {
        if (item.id == selected) return item;
      }
    }
    final job = _selectedJob;
    if (job == null) return null;
    for (final item in widget.clients) {
      if (item.id == job.clientId) return item;
    }
    return null;
  }

  JobRecord? get _selectedJob {
    final selected = (_selectedJobId ?? '').trim();
    if (selected.isEmpty) return null;
    for (final item in widget.jobs) {
      if (item.id == selected) return item;
    }
    return null;
  }

  Future<void> _analyzeRequirement() async {
    final requirement = _requirementController.text.trim();
    if (requirement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introdu cerinta clientului inainte de analiza.'),
        ),
      );
      return;
    }
    setState(() {
      _analyzing = true;
      _analysis = null;
    });
    final result = await widget.aiAssistantService.analyzeOfferRequirement(
      runtimeContext: _buildRuntimeContext(),
      requirementText: requirement,
      userNotes: _operatorNotesController.text,
    );
    if (!mounted) return;
    setState(() {
      _analyzing = false;
      _analysis = result;
    });
  }

  AiAssistantRuntimeContext _buildRuntimeContext() {
    final client = _selectedClient;
    final job = _selectedJob;
    return AiAssistantRuntimeContext(
      contextType: AiAssistantContextType.offers,
      module: 'oferte',
      entityId: 'offer-requirement-${DateTime.now().microsecondsSinceEpoch}',
      entityLabel: 'Cerinta client pentru draft oferta',
      userId: (widget.currentUserId ?? '').trim(),
      contextLabel: [
        if (client?.name.trim().isNotEmpty == true) client!.name.trim(),
        if (job?.title.trim().isNotEmpty == true) job!.title.trim(),
      ].join(' • '),
      primaryData: <String, dynamic>{
        'type': 'offer_requirement',
        'requirement_text': _requirementController.text.trim(),
        'selected_client_id': client?.id ?? '',
        'selected_client_name': client?.name ?? '',
        'selected_job_id': job?.id ?? '',
        'selected_job_title': job?.title ?? '',
      },
      relatedData: <String, dynamic>{
        'client': client?.toMap() ?? const <String, dynamic>{},
        'job': job?.toMap() ?? const <String, dynamic>{},
        'service_presets': kFieldSalesServicePresets
            .map(
              (item) => <String, dynamic>{
                'code': item.code,
                'label': item.label,
                'unit': item.unit,
              },
            )
            .toList(growable: false),
      },
      metadata: <String, dynamic>{
        'flow': 'offer_requirement_to_draft',
      },
    );
  }

  Future<void> _editPosition(int index) async {
    final analysis = _analysis;
    if (analysis == null) return;
    final position = analysis.offerPositions[index];
    final titleController = TextEditingController(text: position.title);
    final descriptionController =
        TextEditingController(text: position.description);
    final quantityController =
        TextEditingController(text: position.quantity.toStringAsFixed(2));
    final unitController = TextEditingController(text: position.unitOfMeasure);
    final notesController = TextEditingController(text: position.notes);
    String selectedProductLabel = position.matchedProductLabel;
    final productChoices = <String>{
      if (position.matchedProductLabel.trim().isNotEmpty)
        position.matchedProductLabel.trim(),
      ...position.alternativeProductLabels,
    }.toList(growable: false);

    final saved = await showDialog<AiRequirementOfferPositionDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editeaza pozitie propusa'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titlu'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descriere'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Cantitate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: unitController,
                          decoration: const InputDecoration(labelText: 'UM'),
                        ),
                      ),
                    ],
                  ),
                  if (productChoices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductLabel.isEmpty
                          ? null
                          : selectedProductLabel,
                      decoration: const InputDecoration(
                        labelText: 'Produs propus din catalog',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Pozitie manuala'),
                        ),
                        ...productChoices.map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                          () => selectedProductLabel = value ?? ''),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observatii'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Renunță'),
            ),
            FilledButton(
              onPressed: () {
                final quantity = double.tryParse(
                      quantityController.text.replaceAll(',', '.').trim(),
                    ) ??
                    position.quantity;
                Navigator.of(context).pop(
                  position.copyWith(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    quantity: quantity > 0 ? quantity : 1,
                    unitOfMeasure: unitController.text.trim().isEmpty
                        ? position.unitOfMeasure
                        : unitController.text.trim(),
                    matchedProductId:
                        selectedProductLabel == position.matchedProductLabel
                            ? position.matchedProductId
                            : '',
                    matchedProductLabel: selectedProductLabel.trim(),
                    notes: notesController.text.trim(),
                  ),
                );
              },
              child: const Text('Salveaza'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    notesController.dispose();

    if (saved == null || !mounted) return;
    setState(() {
      _analysis = AiRequirementAnalysisResult(
        originalRequirement: analysis.originalRequirement,
        recognizedItems: analysis.recognizedItems,
        offerPositions: [
          for (var i = 0; i < analysis.offerPositions.length; i++)
            if (i == index) saved else analysis.offerPositions[i],
        ],
        clarificationQuestions: analysis.clarificationQuestions,
        warnings: analysis.warnings,
        suggestedServices: analysis.suggestedServices,
        suggestedAccessories: analysis.suggestedAccessories,
        draftNotes: analysis.draftNotes,
        unavailableReason: analysis.unavailableReason,
      );
    });
  }

  void _togglePosition(int index, bool accepted) {
    final analysis = _analysis;
    if (analysis == null) return;
    setState(() {
      _analysis = AiRequirementAnalysisResult(
        originalRequirement: analysis.originalRequirement,
        recognizedItems: analysis.recognizedItems,
        offerPositions: [
          for (var i = 0; i < analysis.offerPositions.length; i++)
            if (i == index)
              analysis.offerPositions[i].copyWith(accepted: accepted)
            else
              analysis.offerPositions[i],
        ],
        clarificationQuestions: analysis.clarificationQuestions,
        warnings: analysis.warnings,
        suggestedServices: analysis.suggestedServices,
        suggestedAccessories: analysis.suggestedAccessories,
        draftNotes: analysis.draftNotes,
        unavailableReason: analysis.unavailableReason,
      );
    });
  }

  void _deletePosition(int index) {
    final analysis = _analysis;
    if (analysis == null) return;
    setState(() {
      _analysis = AiRequirementAnalysisResult(
        originalRequirement: analysis.originalRequirement,
        recognizedItems: analysis.recognizedItems,
        offerPositions: [
          for (var i = 0; i < analysis.offerPositions.length; i++)
            if (i != index) analysis.offerPositions[i],
        ],
        clarificationQuestions: analysis.clarificationQuestions,
        warnings: analysis.warnings,
        suggestedServices: analysis.suggestedServices,
        suggestedAccessories: analysis.suggestedAccessories,
        draftNotes: analysis.draftNotes,
        unavailableReason: analysis.unavailableReason,
      );
    });
  }

  Future<void> _createDraftOffer() async {
    final analysis = _analysis;
    if (analysis == null) return;
    final acceptedPositions = analysis.offerPositions
        .where((item) => item.accepted)
        .toList(growable: false);
    if (acceptedPositions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteaza cel putin o pozitie pentru draft.'),
        ),
      );
      return;
    }
    setState(() => _creatingDraft = true);
    try {
      await widget.onCreateDraft(_buildDraftOffer(analysis, acceptedPositions));
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _creatingDraft = false);
      }
    }
  }

  OfferRecord _buildDraftOffer(
    AiRequirementAnalysisResult analysis,
    List<AiRequirementOfferPositionDraft> positions,
  ) {
    final now = DateTime.now();
    final client = _selectedClient;
    final job = _selectedJob;
    final manualRate = widget.defaults.currency == 'EUR' ? 5.0 : 0.0;
    final effectiveExchangeRate = widget.defaults.currency == 'EUR'
        ? manualRate * (1 + widget.defaults.exchangeCommissionPercent / 100)
        : 1.0;
    final lines = [
      for (var index = 0; index < positions.length; index++)
        _buildOfferLineItem(index, positions[index]),
    ];
    final totals = OfferRecord.computeTotals(
      lines: lines,
      vatPercent: widget.defaults.vatPercent,
      regiePercent: widget.defaults.regiePercent,
      profitPercent: widget.defaults.profitPercent,
    );
    final title = _buildDraftTitle(client, job, positions);
    final notes = _buildDraftNotes(analysis);

    return OfferRecord.fromMap(<String, dynamic>{
      'id': 'offer-${now.microsecondsSinceEpoch}',
      'offer_number': widget.nextOfferNumber,
      'title': title,
      'client_id': client?.id ?? '',
      'client_name': client?.name ?? '',
      'contact_person_name': '',
      'contact_person_email': '',
      'contact_person_phone': '',
      'job_id': job?.id ?? '',
      'job_code': job?.jobCode ?? '',
      'job_title': job?.title ?? '',
      'status': OfferStatus.draft.value,
      'issue_date': now.toIso8601String(),
      'currency': widget.defaults.currency,
      'exchange_rate_source': widget.defaults.exchangeRateSource.value,
      'manual_rate': manualRate,
      'bnr_rate': 0,
      'exchange_commission_percent': widget.defaults.exchangeCommissionPercent,
      'effective_exchange_rate': effectiveExchangeRate,
      'notes': notes,
      'lines': lines.map((item) => item.toMap()).toList(growable: false),
      'price_display_mode': OfferPriceDisplayMode.both.value,
      'vat_percent': totals.vatPercent,
      'regie_percent': totals.regiePercent,
      'profit_percent': totals.profitPercent,
      'material_subtotal': totals.materialSubtotal,
      'labor_subtotal': totals.laborSubtotal,
      'subtotal_direct': totals.subtotalDirect,
      'regie_value': totals.regieValue,
      'profit_value': totals.profitValue,
      'subtotal_comercial': totals.subtotalComercial,
      'subtotal': totals.subtotalComercial,
      'vat_value': totals.vatValue,
      'total_value': totals.totalValue,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'created_by_user_id': (widget.currentUserId ?? '').trim(),
      'created_by_user_email': (widget.currentUserEmail ?? '').trim(),
    });
  }

  OfferLineItem _buildOfferLineItem(
    int index,
    AiRequirementOfferPositionDraft position,
  ) {
    final lineType = switch (position.category) {
      AiRequirementItemCategory.service ||
      AiRequirementItemCategory.labor =>
        OfferLineType.manopera,
      AiRequirementItemCategory.unknown => OfferLineType.text,
      _ => OfferLineType.material,
    };
    return OfferLineItem(
      id: 'offer-line-${DateTime.now().microsecondsSinceEpoch}-$index',
      name: position.title.trim(),
      description: [
        position.description.trim(),
        if (position.matchedProductLabel.trim().isNotEmpty)
          'Catalog: ${position.matchedProductLabel.trim()}',
        if (position.notes.trim().isNotEmpty) position.notes.trim(),
      ].where((item) => item.isNotEmpty).join('\n'),
      unit: position.unitOfMeasure.trim().isEmpty
          ? 'buc'
          : position.unitOfMeasure.trim(),
      quantity: position.quantity > 0 ? position.quantity : 1,
      unitPrice: 0,
      lineTotal: 0,
      sortOrder: index + 1,
      lineType: lineType,
      materialId:
          lineType == OfferLineType.material ? position.matchedProductId : '',
      laborTemplateId: '',
    );
  }

  String _buildDraftTitle(
    ClientRecord? client,
    JobRecord? job,
    List<AiRequirementOfferPositionDraft> positions,
  ) {
    final firstLabel = positions.isEmpty ? '' : positions.first.title.trim();
    if (job?.title.trim().isNotEmpty == true) {
      return 'Draft oferta ${job!.title.trim()}';
    }
    if (client?.name.trim().isNotEmpty == true && firstLabel.isNotEmpty) {
      return 'Draft oferta ${client!.name.trim()} - $firstLabel';
    }
    if (client?.name.trim().isNotEmpty == true) {
      return 'Draft oferta ${client!.name.trim()}';
    }
    return firstLabel.isEmpty ? 'Draft oferta din cerinta client' : firstLabel;
  }

  String _buildDraftNotes(AiRequirementAnalysisResult analysis) {
    return [
      'Draft generat asistat AI pe baza cerintei clientului. Necesita verificare umana completa.',
      if (analysis.draftNotes.trim().isNotEmpty) analysis.draftNotes.trim(),
      if (analysis.warnings.isNotEmpty)
        'Atentionari:\n- ${analysis.warnings.join('\n- ')}',
      if (analysis.clarificationQuestions.isNotEmpty)
        'Clarificari recomandate:\n- ${analysis.clarificationQuestions.join('\n- ')}',
      'Cerinta client:\n${analysis.originalRequirement.trim()}',
    ].where((item) => item.trim().isNotEmpty).join('\n\n');
  }

  Color _confidenceColor(AiRequirementConfidenceBand band, ColorScheme scheme) {
    switch (band) {
      case AiRequirementConfidenceBand.sure:
        return scheme.primaryContainer;
      case AiRequirementConfidenceBand.probable:
        return scheme.tertiaryContainer;
      case AiRequirementConfidenceBand.needsReview:
        return scheme.errorContainer;
    }
  }

  Widget _buildItemGroups(AiRequirementAnalysisResult analysis) {
    final grouped =
        <AiRequirementItemCategory, List<AiRequirementRecognizedItem>>{};
    for (final item in analysis.recognizedItems) {
      grouped
          .putIfAbsent(item.category, () => <AiRequirementRecognizedItem>[])
          .add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in AiRequirementItemCategory.values)
          if ((grouped[category] ?? const <AiRequirementRecognizedItem>[])
              .isNotEmpty) ...[
            Text(
              category.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in grouped[category]!)
                  Chip(
                    backgroundColor: _confidenceColor(
                      item.confidenceBand,
                      Theme.of(context).colorScheme,
                    ),
                    label: Text(
                      '${item.normalizedName} • ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${item.unitOfMeasure}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildPositions(AiRequirementAnalysisResult analysis) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var index = 0; index < analysis.offerPositions.length; index++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: CheckboxListTile(
              value: analysis.offerPositions[index].accepted,
              onChanged: (value) => _togglePosition(index, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(analysis.offerPositions[index].title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(analysis.offerPositions[index].description),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            '${analysis.offerPositions[index].quantity.toStringAsFixed(analysis.offerPositions[index].quantity == analysis.offerPositions[index].quantity.roundToDouble() ? 0 : 2)} ${analysis.offerPositions[index].unitOfMeasure}',
                          ),
                        ),
                        Chip(
                          backgroundColor: _confidenceColor(
                            analysis.offerPositions[index].confidenceBand,
                            scheme,
                          ),
                          label: Text(
                            analysis.offerPositions[index].confidenceBand.label,
                          ),
                        ),
                        Chip(
                          label: Text(
                            analysis.offerPositions[index].category.label,
                          ),
                        ),
                        if (analysis.offerPositions[index].matchedProductLabel
                            .trim()
                            .isNotEmpty)
                          Chip(
                            label: Text(
                              analysis
                                  .offerPositions[index].matchedProductLabel,
                            ),
                          ),
                      ],
                    ),
                    if (analysis.offerPositions[index].notes.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(analysis.offerPositions[index].notes),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _editPosition(index),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editeaza'),
                        ),
                        TextButton.icon(
                          onPressed: () => _deletePosition(index),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalysisPreview(AiRequirementAnalysisResult analysis) {
    if (!analysis.isAvailable) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(analysis.unavailableReason),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cerința analizată',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(analysis.originalRequirement),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elemente recunoscute',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (analysis.recognizedItems.isEmpty)
                  const Text(
                      'Nu exista elemente structurate in analiza curenta.')
                else
                  _buildItemGroups(analysis),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pozitii propuse pentru draft',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (analysis.offerPositions.isEmpty)
                  const Text('Nu exista pozitii propuse in analiza curenta.')
                else
                  _buildPositions(analysis),
              ],
            ),
          ),
        ),
        if (analysis.clarificationQuestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clarificari recomandate',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final item in analysis.clarificationQuestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $item'),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (analysis.warnings.isNotEmpty ||
            analysis.suggestedServices.isNotEmpty ||
            analysis.suggestedAccessories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observatii AI',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final item in analysis.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $item'),
                    ),
                  for (final item in analysis.suggestedServices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• Serviciu sugerat: $item'),
                    ),
                  for (final item in analysis.suggestedAccessories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• Accesoriu de verificat: $item'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asistent AI - oferta din cerinta client'),
      content: SizedBox(
        width: 940,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedClientId,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Fara client selectat'),
                        ),
                        ...widget.clients.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedClientId = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedJobId,
                      decoration: const InputDecoration(labelText: 'Lucrare'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Fara lucrare selectata'),
                        ),
                        ...widget.jobs.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(
                                item.title.isEmpty ? item.jobCode : item.title),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedJobId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _requirementController,
                minLines: 7,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Cerinta client / lista materiale / brief proiect',
                  alignLabelWithHint: true,
                  hintText:
                      'Lipeste aici cerinta clientului. Exemplu: 2 aparate split 12000 BTU pentru birou, traseu estimat 8 ml/aparat, montaj inclus, PIF si accesorii necesare.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _operatorNotesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Indicatii suplimentare pentru analiza',
                  hintText:
                      'Exemplu: preferam echipamente dintr-un anumit brand, fara estimare de pret, pastram neclaritatile explicit.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _analyzing ? null : _analyzeRequirement,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Analizeaza cerinta'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Flux controlat: analiza, preview, confirmare, draft.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (_analysis != null) ...[
                const SizedBox(height: 20),
                _buildAnalysisPreview(_analysis!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creatingDraft ? null : () => Navigator.of(context).pop(),
          child: const Text('Închide'),
        ),
        FilledButton.icon(
          onPressed: _creatingDraft || !(_analysis?.canCreateDraft ?? false)
              ? null
              : _createDraftOffer,
          icon: _creatingDraft
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.post_add_outlined),
          label: const Text('Creeaza draft oferta'),
        ),
      ],
    );
  }
}
