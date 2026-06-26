import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/document_file_service.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'complaint_document_template_service.dart';
import '../field_photos/field_photos_page.dart';
import '../mentenanta/interventii/fgas_gwp_catalog.dart';
import '../programari/appointment_models.dart';
import 'complaint_models.dart';
import 'repair_report_pdf_service.dart';
import 'repair_report_models.dart';
import 'signature_capture_page.dart';

class RepairReportEditorPage extends StatefulWidget {
  const RepairReportEditorPage({
    super.key,
    required this.repository,
    required this.complaint,
    this.appointment,
    this.currentReport,
    this.previousReport,
    this.interventionNumber = 1,
  });

  final AppDataRepository repository;
  final ComplaintRecord complaint;
  final Appointment? appointment;
  final RepairReportRecord? currentReport;
  // Câmpuri de înlănțuire (Pasul 5 — PV următor)
  final RepairReportRecord? previousReport;
  final int interventionNumber;

  @override
  State<RepairReportEditorPage> createState() => _RepairReportEditorPageState();
}

class _RepairReportEditorPageState extends State<RepairReportEditorPage> {
  final Uuid _uuid = const Uuid();
  final ComplaintDocumentTemplateService _templateService =
      const ComplaintDocumentTemplateService();
  late final TextEditingController _reportNumberController;
  late final TextEditingController _beneficiaryController;
  late final TextEditingController _contractorController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  late final TextEditingController _technicianController;
  late final TextEditingController _teamController;
  late final TextEditingController _complaintDescriptionController;
  late final TextEditingController _findingsController;
  late final TextEditingController _workPerformedController;
  late final TextEditingController _materialsUsedController;
  late final TextEditingController _recommendationsController;
  late final TextEditingController _equipmentTypeController;
  late final TextEditingController _equipmentBrandController;
  late final TextEditingController _equipmentModelController;
  late final TextEditingController _outdoorUnitSerialController;
  late final TextEditingController _indoorUnitSerialsController;
  late final TextEditingController _equipmentDetailsController;
  // Câmpuri noi template PV Constatare Tehnică
  late final TextEditingController _reprezentantBeneficiarController;
  late final TextEditingController _agentFrigorificController;
  late final TextEditingController _cantitateRecuperataController;
  late final TextEditingController _coduriEroareController;
  late final TextEditingController _stareTestController;
  late final TextEditingController _motivulInterventeiController;
  late final TextEditingController _constatariLocController;
  late final TextEditingController _lucrariEfectuateDetController;
  late final TextEditingController _observatiiTehController;
  late final TextEditingController _concluziController;
  late final TextEditingController _recomandariController;
  late final TextEditingController _mentiuniController;
  late final TextEditingController _materialeDetailedController;
  late final TextEditingController _traseulPieselorController;
  String _pvType = 'constatare';
  bool _agentManualMode = false;
  static const String _altAgentSentinel = '__alt_agent__';
  late RepairReportResolutionStatus _resolutionStatus;
  late DateTime _interventionDate;
  late String _reportId;
  late DateTime _createdAt;
  String _clientSignatureBase64 = '';
  String _technicianSignatureBase64 = '';
  String _pdfPath = '';
  bool _saving = false;
  List<String> _photoBase64List = [];
  List<String> _photoUrls = [];
  List<String> _photoCaptions = [];

  @override
  void initState() {
    super.initState();
    final seed = widget.currentReport ?? _seedFromContext();
    _reportNumberController = TextEditingController(text: seed.reportNumber);
    _beneficiaryController = TextEditingController(text: seed.beneficiaryName);
    _contractorController = TextEditingController(text: seed.contractorName);
    _contactPersonController = TextEditingController(text: seed.contactPerson);
    _phoneController = TextEditingController(text: seed.phone);
    _emailController = TextEditingController(text: seed.email);
    _locationController = TextEditingController(text: seed.location);
    _technicianController = TextEditingController(text: seed.technicianName);
    _teamController = TextEditingController(text: seed.teamName);
    _complaintDescriptionController =
        TextEditingController(text: seed.complaintDescription);
    _findingsController = TextEditingController(text: seed.findings);
    _workPerformedController = TextEditingController(text: seed.workPerformed);
    _materialsUsedController = TextEditingController(text: seed.materialsUsed);
    _recommendationsController =
        TextEditingController(text: seed.recommendations);
    _equipmentTypeController = TextEditingController(text: seed.equipmentType);
    _equipmentBrandController =
        TextEditingController(text: seed.equipmentBrand);
    _equipmentModelController =
        TextEditingController(text: seed.equipmentModel);
    _outdoorUnitSerialController =
        TextEditingController(text: seed.outdoorUnitSerial);
    _indoorUnitSerialsController =
        TextEditingController(text: seed.indoorUnitSerials);
    _equipmentDetailsController =
        TextEditingController(text: seed.equipmentDetails);
    _reprezentantBeneficiarController =
        TextEditingController(text: seed.reprezentantBeneficiar);
    _agentFrigorificController =
        TextEditingController(text: seed.agentFrigorific);
    _cantitateRecuperataController =
        TextEditingController(text: seed.cantitateRecuperata);
    _agentManualMode = seed.agentFrigorific.trim().isNotEmpty &&
        FGasGwpCatalog.getGwp(seed.agentFrigorific) == null;
    _coduriEroareController = TextEditingController(text: seed.coduriEroare);
    _stareTestController = TextEditingController(text: seed.stareTest);
    _motivulInterventeiController =
        TextEditingController(text: seed.motivulInterventiei);
    _constatariLocController =
        TextEditingController(text: seed.constatariLocFinding);
    _lucrariEfectuateDetController =
        TextEditingController(text: seed.lucrariEfectuateDetailed);
    _observatiiTehController =
        TextEditingController(text: seed.observatiiTehnice);
    _concluziController = TextEditingController(text: seed.concluzie);
    _recomandariController = TextEditingController(text: seed.recomandari);
    _mentiuniController = TextEditingController(text: seed.mentiuni);
    _materialeDetailedController =
        TextEditingController(text: seed.materialeDetailed);
    _traseulPieselorController =
        TextEditingController(text: seed.traseulPieselorDefecte);
    _pvType = seed.pvType.isEmpty ? 'constatare' : seed.pvType;
    _resolutionStatus = seed.resolutionStatus;
    _interventionDate = seed.interventionDate;
    _reportId = seed.id;
    _createdAt = seed.createdAt;
    _clientSignatureBase64 = seed.clientSignatureBase64;
    _technicianSignatureBase64 = seed.technicianSignatureBase64;
    _pdfPath = seed.pdfPath;
    _photoBase64List = List.of(seed.photoBase64List);
    _photoUrls = List.of(seed.photoUrls);
    _photoCaptions = List.of(seed.photoCaptions);
    if (widget.currentReport == null && seed.reportNumber.trim().isEmpty) {
      _assignAutomaticNumber();
    }
    _applySavedTemplateOnStart();
  }

  Future<void> _assignAutomaticNumber() async {
    final nextNumber = await widget.repository.nextRepairReportNumber();
    if (!mounted || _reportNumberController.text.trim().isNotEmpty) {
      return;
    }
    setState(() {
      _reportNumberController.text = nextNumber;
    });
  }

  Future<void> _applySavedTemplateOnStart() async {
    if (widget.currentReport != null) {
      return;
    }
    final template = await _templateService.loadRepairReportTemplate();
    if (!mounted || !template.hasContent) {
      return;
    }
    _applyTemplateToForm(template, showFeedback: false);
  }

  @override
  void dispose() {
    _reportNumberController.dispose();
    _beneficiaryController.dispose();
    _contractorController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _technicianController.dispose();
    _teamController.dispose();
    _complaintDescriptionController.dispose();
    _findingsController.dispose();
    _workPerformedController.dispose();
    _materialsUsedController.dispose();
    _recommendationsController.dispose();
    _equipmentTypeController.dispose();
    _equipmentBrandController.dispose();
    _equipmentModelController.dispose();
    _outdoorUnitSerialController.dispose();
    _indoorUnitSerialsController.dispose();
    _equipmentDetailsController.dispose();
    _reprezentantBeneficiarController.dispose();
    _agentFrigorificController.dispose();
    _cantitateRecuperataController.dispose();
    _coduriEroareController.dispose();
    _stareTestController.dispose();
    _motivulInterventeiController.dispose();
    _constatariLocController.dispose();
    _lucrariEfectuateDetController.dispose();
    _observatiiTehController.dispose();
    _concluziController.dispose();
    _recomandariController.dispose();
    _mentiuniController.dispose();
    _materialeDetailedController.dispose();
    _traseulPieselorController.dispose();
    super.dispose();
  }

  String _appointmentMaterialUsageText(Appointment? appointment) {
    final usage = appointment?.materialUsage;
    if (usage == null) {
      return '';
    }
    final parts = <String>[];
    if (usage.kitTemplateName.trim().isNotEmpty) {
      parts.add('Kit: ${usage.kitTemplateName.trim()}');
    }
    if (usage.linearMetersUsed > 0) {
      parts.add(
        'Cantitate folosita: ${usage.linearMetersUsed.toStringAsFixed(usage.linearMetersUsed == usage.linearMetersUsed.roundToDouble() ? 0 : 2)} ml',
      );
    }
    if (usage.lines.isNotEmpty) {
      parts.add(
        usage.lines
            .map(
              (line) =>
                  '${line.name} - ${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} ${line.unit}',
            )
            .join(', '),
      );
    }
    if (usage.notes.trim().isNotEmpty) {
      parts.add('Observatii materiale: ${usage.notes.trim()}');
    }
    return parts.join('\n');
  }

  RepairReportRecord _seedFromContext() {
    final complaint = widget.complaint;
    final appointment = widget.appointment;
    final start = appointment?.effectiveStartDateTime ?? DateTime.now();
    final appointmentMaterials = _appointmentMaterialUsageText(appointment);
    return RepairReportRecord(
      id: 'rr-${_uuid.v4()}',
      complaintId: complaint.id,
      appointmentId: complaint.appointmentId.trim().isNotEmpty
          ? complaint.appointmentId.trim()
          : (appointment?.id ?? ''),
      jobId: complaint.jobId.trim().isNotEmpty
          ? complaint.jobId.trim()
          : (appointment?.jobId ?? ''),
      reportNumber: '',
      clientSignatureBase64: '',
      technicianSignatureBase64: '',
      pdfPath: '',
      equipmentType: complaint.equipmentType?.label ?? '',
      equipmentBrand: complaint.equipmentBrand.trim(),
      equipmentModel: complaint.equipmentModel.trim(),
      outdoorUnitSerial: complaint.outdoorUnitSerial.trim(),
      indoorUnitSerials: complaint.indoorUnitSerials.trim(),
      equipmentDetails: complaint.equipmentDetails.trim(),
      interventionDate: start,
      technicianName: (appointment?.assignedUserEmail ?? '').trim().isNotEmpty
          ? appointment!.assignedUserEmail.trim()
          : (appointment?.assignedEmployeeIds.isNotEmpty == true
              ? appointment!.assignedEmployeeIds.first
              : complaint.assignedEmployeeId),
      teamName: appointment?.assignedTeamIds.isNotEmpty == true
          ? appointment!.assignedTeamIds.first
          : (appointment?.teamId.trim().isNotEmpty == true
              ? appointment!.teamId.trim()
              : complaint.assignedTeamId.trim()),
      beneficiaryName: complaint.beneficiaryName.trim().isNotEmpty
          ? complaint.beneficiaryName.trim()
          : (appointment?.clientName ?? ''),
      contractorName: complaint.contractorName.trim().isNotEmpty
          ? complaint.contractorName.trim()
          : (appointment?.contractingClientName ?? ''),
      contactPerson: complaint.contactPerson.trim().isNotEmpty
          ? complaint.contactPerson.trim()
          : (appointment?.contactPerson ?? ''),
      phone: complaint.phone.trim().isNotEmpty
          ? complaint.phone.trim()
          : (appointment?.contactPhone ?? ''),
      email: complaint.email.trim().isNotEmpty
          ? complaint.email.trim()
          : (appointment?.contactEmail ?? ''),
      location: complaint.location.trim().isNotEmpty
          ? complaint.location.trim()
          : (appointment?.location ?? ''),
      complaintDescription: complaint.problemDescription.trim(),
      findings: '',
      workPerformed: '',
      materialsUsed: appointmentMaterials,
      recommendations: complaint.internalNotes.trim(),
      resolutionStatus: RepairReportResolutionStatus.rezolvata,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      // Pre-completare din reclamatie (Pasul 5)
      motivulInterventiei: complaint.problemDescription.trim(),
      constatariLocFinding: '',
      lucrariEfectuateDetailed: '',
    );
  }

  Future<void> _pickInterventionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _interventionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _interventionDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _interventionDate.hour,
        _interventionDate.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final report = await _persistDraft();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(report);
  }

  RepairReportRecord _buildDraftReport() {
    return RepairReportRecord(
      id: _reportId,
      complaintId: widget.complaint.id,
      appointmentId: widget.complaint.appointmentId.trim().isNotEmpty
          ? widget.complaint.appointmentId.trim()
          : (widget.appointment?.id ?? ''),
      jobId: widget.complaint.jobId.trim().isNotEmpty
          ? widget.complaint.jobId.trim()
          : (widget.appointment?.jobId ?? ''),
      reportNumber: _reportNumberController.text.trim(),
      clientSignatureBase64: _clientSignatureBase64,
      technicianSignatureBase64: _technicianSignatureBase64,
      pdfPath: _pdfPath,
      equipmentType: _equipmentTypeController.text.trim(),
      equipmentBrand: _equipmentBrandController.text.trim(),
      equipmentModel: _equipmentModelController.text.trim(),
      outdoorUnitSerial: _outdoorUnitSerialController.text.trim(),
      indoorUnitSerials: _indoorUnitSerialsController.text.trim(),
      equipmentDetails: _equipmentDetailsController.text.trim(),
      interventionDate: _interventionDate,
      technicianName: _technicianController.text.trim(),
      teamName: _teamController.text.trim(),
      beneficiaryName: _beneficiaryController.text.trim(),
      contractorName: _contractorController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      location: _locationController.text.trim(),
      complaintDescription: _complaintDescriptionController.text.trim(),
      findings: _findingsController.text.trim(),
      workPerformed: _workPerformedController.text.trim(),
      materialsUsed: _materialsUsedController.text.trim(),
      recommendations: _recommendationsController.text.trim(),
      resolutionStatus: _resolutionStatus,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      interventionNumber: widget.currentReport?.interventionNumber ?? widget.interventionNumber,
      previousReportId: widget.previousReport?.id ?? (widget.currentReport?.previousReportId ?? ''),
      previousReportNumber: widget.previousReport?.reportNumber ?? (widget.currentReport?.previousReportNumber ?? ''),
      previousInterventionSummary: widget.previousReport?.findings ?? (widget.currentReport?.previousInterventionSummary ?? ''),
      isFollowUp: widget.previousReport != null || (widget.currentReport?.isFollowUp ?? false),
      photoBase64List: List.unmodifiable(_photoBase64List),
      photoUrls: List.unmodifiable(_photoUrls),
      photoCategories: const <String>[],
      photoCaptions: List.unmodifiable(_photoCaptions),
      pvType: _pvType,
      reprezentantBeneficiar: _reprezentantBeneficiarController.text.trim(),
      agentFrigorific: _agentFrigorificController.text.trim(),
      cantitateRecuperata: _cantitateRecuperataController.text.trim(),
      coduriEroare: _coduriEroareController.text.trim(),
      stareTest: _stareTestController.text.trim(),
      motivulInterventiei: _motivulInterventeiController.text.trim(),
      constatariLocFinding: _constatariLocController.text.trim(),
      lucrariEfectuateDetailed: _lucrariEfectuateDetController.text.trim(),
      observatiiTehnice: _observatiiTehController.text.trim(),
      concluzie: _concluziController.text.trim(),
      recomandari: _recomandariController.text.trim(),
      mentiuni: _mentiuniController.text.trim(),
      materialeDetailed: _materialeDetailedController.text.trim(),
      traseulPieselorDefecte: _traseulPieselorController.text.trim(),
    );
  }

  Future<RepairReportRecord> _persistDraft() async {
    var report = _buildDraftReport();
    if (report.reportNumber.trim().isEmpty) {
      final nextNumber = await widget.repository.nextRepairReportNumber();
      _reportNumberController.text = nextNumber;
      report = report.copyWith(reportNumber: nextNumber);
    }
    await widget.repository.saveRepairReport(report);
    _reportId = report.id;
    _createdAt = report.createdAt;
    return report;
  }

  void _applyDraftToControllers(RepairReportRecord report) {
    _beneficiaryController.text = report.beneficiaryName;
    _contractorController.text = report.contractorName;
    _contactPersonController.text = report.contactPerson;
    _phoneController.text = report.phone;
    _emailController.text = report.email;
    _locationController.text = report.location;
    _technicianController.text = report.technicianName;
    _teamController.text = report.teamName;
    _complaintDescriptionController.text = report.complaintDescription;
    _findingsController.text = report.findings;
    _workPerformedController.text = report.workPerformed;
    _materialsUsedController.text = report.materialsUsed;
    _recommendationsController.text = report.recommendations;
    _equipmentTypeController.text = report.equipmentType;
    _equipmentBrandController.text = report.equipmentBrand;
    _equipmentModelController.text = report.equipmentModel;
    _outdoorUnitSerialController.text = report.outdoorUnitSerial;
    _indoorUnitSerialsController.text = report.indoorUnitSerials;
    _equipmentDetailsController.text = report.equipmentDetails;
    _reprezentantBeneficiarController.text = report.reprezentantBeneficiar;
    _agentFrigorificController.text = report.agentFrigorific;
    _cantitateRecuperataController.text = report.cantitateRecuperata;
    _coduriEroareController.text = report.coduriEroare;
    _stareTestController.text = report.stareTest;
    _motivulInterventeiController.text = report.motivulInterventiei;
    _constatariLocController.text = report.constatariLocFinding;
    _lucrariEfectuateDetController.text = report.lucrariEfectuateDetailed;
    _observatiiTehController.text = report.observatiiTehnice;
    _concluziController.text = report.concluzie;
    _recomandariController.text = report.recomandari;
    _mentiuniController.text = report.mentiuni;
    _materialeDetailedController.text = report.materialeDetailed;
    _traseulPieselorController.text = report.traseulPieselorDefecte;
    _pvType = report.pvType.isEmpty ? 'constatare' : report.pvType;
  }

  void _applyTemplateToForm(
    RepairReportTemplate template, {
    bool showFeedback = true,
  }) {
    final applied = _templateService.applyRepairReportTemplate(
      template: template,
      current: _buildDraftReport(),
      complaint: widget.complaint,
    );
    setState(() {
      _applyDraftToControllers(applied);
    });
    if (!showFeedback || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sablonul PV a fost aplicat pe document.'),
      ),
    );
  }

  Future<void> _openTemplateManager() async {
    final savedTemplate = await _templateService.loadRepairReportTemplate();
    if (!mounted) {
      return;
    }
    final result = await showDialog<_RepairReportTemplateDialogResult>(
      context: context,
      builder: (context) => _RepairReportTemplateDialog(
        initialTemplate: savedTemplate,
        templateService: _templateService,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.resetSavedTemplate) {
      await _templateService.resetRepairReportTemplate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sablonul implicit pentru PV a fost resetat.'),
        ),
      );
      return;
    }
    if (result.saveAsDefault) {
      await _templateService.saveRepairReportTemplate(result.template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sablonul PV a fost salvat ca implicit.'),
        ),
      );
    }
    if (result.applyNow) {
      _applyTemplateToForm(result.template);
    }
  }

  Future<void> _captureSignature({required bool forClient}) async {
    final bytes = await Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => SignatureCapturePage(
          title: forClient ? 'Semnatura client' : 'Semnatura tehnician',
        ),
      ),
    );
    if (bytes == null || !mounted) {
      return;
    }
    final encoded = base64Encode(bytes);
    setState(() {
      if (forClient) {
        _clientSignatureBase64 = encoded;
      } else {
        _technicianSignatureBase64 = encoded;
      }
    });
  }

  void _clearSignature({required bool forClient}) {
    setState(() {
      if (forClient) {
        _clientSignatureBase64 = '';
      } else {
        _technicianSignatureBase64 = '';
      }
    });
  }

  // ── Gestionare poze anexă PV ────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoBase64List.length >= 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 20 poze per PV.')),
        );
      }
      return;
    }
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null || !mounted) return;
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _photoBase64List.add(b64);
        _photoCaptions.add('');
        _photoUrls.add('');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare adăugare poză: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      if (index < _photoBase64List.length) _photoBase64List.removeAt(index);
      if (index < _photoUrls.length) _photoUrls.removeAt(index);
      if (index < _photoCaptions.length) _photoCaptions.removeAt(index);
    });
  }

  Widget _buildPhotoAnnexSection() {
    return _section(
      'Poze anexă PV (${_photoBase64List.length}/20)',
      [
        if (_photoBase64List.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _photoBase64List.length,
            itemBuilder: (_, i) {
              Uint8List? bytes;
              try {
                bytes = base64Decode(_photoBase64List[i]);
              } catch (e) {
                debugPrint('[RepairReportEditor] decodare poză preview eșuată: $e');
              }
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (bytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(bytes, fit: BoxFit.cover),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.image_outlined),
                          ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _removePhoto(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    onChanged: (val) {
                      if (i < _photoCaptions.length) _photoCaptions[i] = val;
                    },
                    controller: TextEditingController(
                      text: i < _photoCaptions.length ? _photoCaptions[i] : '',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Descriere...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 11),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _photoBase64List.length >= 20
                  ? null
                  : () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: const Text('Fă poză'),
            ),
            OutlinedButton.icon(
              onPressed: _photoBase64List.length >= 20
                  ? null
                  : () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Din galerie'),
            ),
          ],
        ),
      ],
    );
  }

  Uint8List? _decodeSignature(String base64Value) {
    if (base64Value.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
  }

  Widget _signatureCard({
    required String title,
    required String signatureBase64,
    required VoidCallback onSign,
    required VoidCallback onClear,
  }) {
    final bytes = _decodeSignature(signatureBase64);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Container(
              height: 110,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: bytes == null
                  ? const Text('Fara semnatura')
                  : Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onSign,
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Semneaza'),
                ),
                OutlinedButton.icon(
                  onPressed: bytes == null ? null : onClear,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('Reseteaza'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf({
    required bool share,
    bool saveAs = false,
  }) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final company = await widget.repository.loadCompanyProfile();
      var report = await _persistDraft();
      if (share) {
        await RepairReportPdfService.share(company: company, report: report);
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Share deschis pentru procesul verbal.')),
        );
        setState(() => _saving = false);
        return;
      }
      final path = await RepairReportPdfService.export(
        repository: widget.repository,
        company: company,
        report: report,
        saveAs: saveAs,
      );
      report = report.copyWith(pdfPath: path);
      await widget.repository.saveRepairReport(report);
      if (!mounted) {
        return;
      }
      setState(() {
        _pdfPath = path;
        _saving = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('PDF generat: $path')),
      );
      await _showGeneratedPdfActions(path);
    } on PdfSaveCanceledException {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Salvarea documentului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Nu am putut genera PDF-ul: $error')),
      );
    }
  }

  Future<void> _showGeneratedPdfActions(String filePath) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PDF proces verbal generat',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  filePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final result =
                            await DocumentFileService.openFile(filePath);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                        if (result.shouldOfferShare && mounted) {
                          await _shareExistingPdf(filePath);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareExistingPdf(filePath);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    if (!DocumentFileService.isMobilePlatform)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final opened =
                              await DocumentFileService.openFolderForFile(
                            filePath,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? 'Folder deschis.'
                                    : 'Nu am putut deschide folderul.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareExistingPdf(String filePath) async {
    try {
      await DocumentFileService.shareFile(
        filePath,
        subject: _reportNumberController.text.trim().isEmpty
            ? 'Proces verbal reparatie'
            : _reportNumberController.text.trim(),
        text: 'Proces verbal generat din aplicatie.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share deschis pentru procesul verbal.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut trimite PDF-ul: $error')),
      );
    }
  }

  Future<void> _openFieldPhotos() async {
    final report = await _persistDraft();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldPhotosPage(
          repository: widget.repository,
          sourceModule: 'repair_report',
          sourceEntityId: widget.complaint.id,
          documentId: report.id,
          title: 'Poze teren proces verbal',
        ),
      ),
    );
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  static String _pvTypeTitle(String pvType) {
    switch (pvType) {
      case 'interventie':
        return 'PV Interventie';
      case 'montaj':
        return 'PV Receptie Montaj';
      case 'garantie':
        return 'PV Garantie';
      default:
        return 'PV Constatare Tehnica';
    }
  }

  double _parseKg(String raw) {
    final cleaned =
        raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Câmp agent frigorific cu dropdown din catalogul unificat (FGasGwpCatalog →
  /// AgfrRefrigerantData) + afișaj readonly GWP și tone CO₂ (din cant. recuperată).
  Widget _buildAgentFGasField() {
    final agent = _agentFrigorificController.text;
    final gwp = FGasGwpCatalog.getGwp(agent);
    final cant = _parseKg(_cantitateRecuperataController.text);
    final tone = gwp != null ? gwp * cant / 1000.0 : 0.0;

    String? dropdownValue;
    if (_agentManualMode) {
      dropdownValue = _altAgentSentinel;
    } else {
      final t = agent.trim().toUpperCase();
      for (final a in FGasGwpCatalog.agentiDisponibili) {
        if (a.toUpperCase() == t) {
          dropdownValue = a;
          break;
        }
      }
    }

    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Agent frigorific'),
            items: [
              ...FGasGwpCatalog.agentiDisponibili.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('$a (GWP ${FGasGwpCatalog.getGwp(a) ?? 0})'),
                  )),
              const DropdownMenuItem(
                  value: _altAgentSentinel, child: Text('Alt agent…')),
            ],
            onChanged: (v) => setState(() {
              if (v == _altAgentSentinel) {
                _agentManualMode = true;
              } else if (v != null) {
                _agentManualMode = false;
                _agentFrigorificController.text = v;
              }
            }),
          ),
          if (_agentManualMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _agentFrigorificController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Denumire agent (manual)'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              gwp != null
                  ? 'GWP: $gwp | Tone CO₂: ${tone.toStringAsFixed(3)} t'
                  : 'GWP: necunoscut',
              style: TextStyle(
                  fontSize: 12,
                  color: gwp != null ? Colors.green.shade700 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.currentReport == null
              ? _pvTypeTitle(_pvType)
              : 'Editeaza PV',
        ),
        actions: [
          IconButton(
            tooltip: 'Sabloane PV',
            onPressed: _saving ? null : _openTemplateManager,
            icon: const Icon(Icons.text_snippet_outlined),
          ),
          IconButton(
            tooltip: 'Genereaza PDF',
            onPressed: _saving ? null : () => _generatePdf(share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Save As',
            onPressed:
                _saving ? null : () => _generatePdf(share: false, saveAs: true),
            icon: const Icon(Icons.save_as_outlined),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: _saving ? null : () => _generatePdf(share: true),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.previousReport != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.link, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            'INTERVENȚIA NR. ${widget.interventionNumber} — REVENIRE',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Continuare după PV ${widget.previousReport!.reportNumber.isEmpty ? widget.previousReport!.id : widget.previousReport!.reportNumber}'
                        ' din ${widget.previousReport!.interventionDate.day.toString().padLeft(2,'0')}.${widget.previousReport!.interventionDate.month.toString().padLeft(2,'0')}.${widget.previousReport!.interventionDate.year}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      ),
                      if (widget.previousReport!.findings.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text('Constatare anterioară:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(widget.previousReport!.findings, style: const TextStyle(fontSize: 11)),
                      ],
                      if (widget.previousReport!.workPerformed.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text('Lucrări efectuate anterior:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(widget.previousReport!.workPerformed, style: const TextStyle(fontSize: 11)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Status anterior: ${widget.previousReport!.resolutionStatus.label}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
              _section(
                'Document',
                [
                  DropdownButtonFormField<String>(
                    initialValue: _pvType,
                    decoration: const InputDecoration(labelText: 'Tip PV'),
                    items: const [
                      DropdownMenuItem(
                          value: 'constatare',
                          child: Text('PV Constatare Tehnica')),
                      DropdownMenuItem(
                          value: 'interventie',
                          child: Text('PV Interventie')),
                      DropdownMenuItem(
                          value: 'montaj',
                          child: Text('PV Receptie Montaj')),
                      DropdownMenuItem(
                          value: 'garantie',
                          child: Text('PV Garantie')),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _pvType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _reportNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numar proces verbal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _pickInterventionDate,
                    child:
                        Text('Data interventiei: ${_date(_interventionDate)}'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RepairReportResolutionStatus>(
                    initialValue: _resolutionStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status rezolvare',
                    ),
                    items: RepairReportResolutionStatus.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _resolutionStatus = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                'Context',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _beneficiaryController,
                    decoration: const InputDecoration(labelText: 'Beneficiar'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _reprezentantBeneficiarController,
                    decoration: const InputDecoration(
                        labelText: 'Reprezentant beneficiar'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _contractorController,
                    decoration: const InputDecoration(
                      labelText: 'Societate contractanta / colaborator',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _contactPersonController,
                    decoration: const InputDecoration(
                      labelText: 'Persoana de contact',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _phoneController,
                          decoration:
                              const InputDecoration(labelText: 'Telefon'),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _locationController,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Adresa / locatie'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _technicianController,
                          decoration: const InputDecoration(
                            labelText: 'Tehnician / persoana',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _teamController,
                          decoration:
                              const InputDecoration(labelText: 'Echipa'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                'Echipament / Utilaj',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _equipmentTypeController,
                    decoration:
                        const InputDecoration(labelText: 'Tip echipament'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _equipmentBrandController,
                          decoration: const InputDecoration(labelText: 'Brand'),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _equipmentModelController,
                          decoration: const InputDecoration(labelText: 'Model'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _outdoorUnitSerialController,
                    decoration: const InputDecoration(
                      labelText: 'Serie unitate exterioara',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _indoorUnitSerialsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Serii unitati interioare',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _equipmentDetailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Detalii tehnice',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                'Date tehnice instalatie',
                [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildAgentFGasField(),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _cantitateRecuperataController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                              labelText: 'Cantitate recuperata (ex: 7,22 kg)'),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _coduriEroareController,
                          decoration: const InputDecoration(
                              labelText: 'Coduri eroare (ex: P9 / JA / E1)'),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: _stareTestController,
                          decoration: const InputDecoration(
                              labelText: 'Stare test (ex: AC debugging)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '1. Motivul interventiei',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _motivulInterventeiController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Descrieti motivul tehnic al interventiei...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '2. Constatari la fata locului',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _constatariLocController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Enumerati constatarile tehnice...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '3. Lucrari efectuate',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _lucrariEfectuateDetController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Descrieti lucrarile efectuate...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '4. Observatii tehnice',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _observatiiTehController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Observatii si interpretari tehnice...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '5. Concluzie',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _concluziController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Concluzia tehnica si recomandarea...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '6. Recomandari',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _recomandariController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enumerati recomandarile tehnice...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                '7. Mentiuni',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _mentiuniController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Mentiuni suplimentare...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                'Materiale si piese detaliate',
                [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _materialeDetailedController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Cod articol / denumire / cantitate',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _traseulPieselorController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Traseu piese defecte/inlocuite',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPhotoAnnexSection(),
              const SizedBox(height: 12),
              _section(
                'Semnaturi',
                [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 320,
                        child: _signatureCard(
                          title: 'Semnatura client',
                          signatureBase64: _clientSignatureBase64,
                          onSign: () => _captureSignature(forClient: true),
                          onClear: () => _clearSignature(forClient: true),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: _signatureCard(
                          title: 'Semnatura tehnician',
                          signatureBase64: _technicianSignatureBase64,
                          onSign: () => _captureSignature(forClient: false),
                          onClear: () => _clearSignature(forClient: false),
                        ),
                      ),
                    ],
                  ),
                  if (_pdfPath.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('PDF generat: ${_pdfPath.trim()}'),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _openFieldPhotos,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Poze de teren'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label:
                Text(_saving ? 'Se salveaza...' : 'Salveaza procesul verbal'),
          ),
        ),
      ),
    );
  }
}

class _RepairReportTemplateDialogResult {
  const _RepairReportTemplateDialogResult({
    required this.template,
    this.applyNow = false,
    this.saveAsDefault = false,
    this.resetSavedTemplate = false,
  });

  final RepairReportTemplate template;
  final bool applyNow;
  final bool saveAsDefault;
  final bool resetSavedTemplate;
}

class _RepairReportTemplateDialog extends StatefulWidget {
  const _RepairReportTemplateDialog({
    required this.initialTemplate,
    required this.templateService,
  });

  final RepairReportTemplate initialTemplate;
  final ComplaintDocumentTemplateService templateService;

  @override
  State<_RepairReportTemplateDialog> createState() =>
      _RepairReportTemplateDialogState();
}

class _RepairReportTemplateDialogState
    extends State<_RepairReportTemplateDialog> {
  late final TextEditingController _beneficiaryController;
  late final TextEditingController _contractorController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  late final TextEditingController _technicianController;
  late final TextEditingController _teamController;
  late final TextEditingController _complaintDescriptionController;
  late final TextEditingController _findingsController;
  late final TextEditingController _workPerformedController;
  late final TextEditingController _materialsUsedController;
  late final TextEditingController _recommendationsController;
  late final TextEditingController _equipmentTypeController;
  late final TextEditingController _equipmentBrandController;
  late final TextEditingController _equipmentModelController;
  late final TextEditingController _outdoorUnitSerialController;
  late final TextEditingController _indoorUnitSerialsController;
  late final TextEditingController _equipmentDetailsController;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTemplate;
    _beneficiaryController =
        TextEditingController(text: initial.beneficiaryName);
    _contractorController = TextEditingController(text: initial.contractorName);
    _contactPersonController =
        TextEditingController(text: initial.contactPerson);
    _phoneController = TextEditingController(text: initial.phone);
    _emailController = TextEditingController(text: initial.email);
    _locationController = TextEditingController(text: initial.location);
    _technicianController = TextEditingController(text: initial.technicianName);
    _teamController = TextEditingController(text: initial.teamName);
    _complaintDescriptionController =
        TextEditingController(text: initial.complaintDescription);
    _findingsController = TextEditingController(text: initial.findings);
    _workPerformedController =
        TextEditingController(text: initial.workPerformed);
    _materialsUsedController =
        TextEditingController(text: initial.materialsUsed);
    _recommendationsController =
        TextEditingController(text: initial.recommendations);
    _equipmentTypeController =
        TextEditingController(text: initial.equipmentType);
    _equipmentBrandController =
        TextEditingController(text: initial.equipmentBrand);
    _equipmentModelController =
        TextEditingController(text: initial.equipmentModel);
    _outdoorUnitSerialController =
        TextEditingController(text: initial.outdoorUnitSerial);
    _indoorUnitSerialsController =
        TextEditingController(text: initial.indoorUnitSerials);
    _equipmentDetailsController =
        TextEditingController(text: initial.equipmentDetails);
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _contractorController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _technicianController.dispose();
    _teamController.dispose();
    _complaintDescriptionController.dispose();
    _findingsController.dispose();
    _workPerformedController.dispose();
    _materialsUsedController.dispose();
    _recommendationsController.dispose();
    _equipmentTypeController.dispose();
    _equipmentBrandController.dispose();
    _equipmentModelController.dispose();
    _outdoorUnitSerialController.dispose();
    _indoorUnitSerialsController.dispose();
    _equipmentDetailsController.dispose();
    super.dispose();
  }

  RepairReportTemplate _buildTemplate() {
    return RepairReportTemplate(
      beneficiaryName: _beneficiaryController.text.trim(),
      contractorName: _contractorController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      location: _locationController.text.trim(),
      technicianName: _technicianController.text.trim(),
      teamName: _teamController.text.trim(),
      complaintDescription: _complaintDescriptionController.text.trim(),
      findings: _findingsController.text.trim(),
      workPerformed: _workPerformedController.text.trim(),
      materialsUsed: _materialsUsedController.text.trim(),
      recommendations: _recommendationsController.text.trim(),
      equipmentType: _equipmentTypeController.text.trim(),
      equipmentBrand: _equipmentBrandController.text.trim(),
      equipmentModel: _equipmentModelController.text.trim(),
      outdoorUnitSerial: _outdoorUnitSerialController.text.trim(),
      indoorUnitSerials: _indoorUnitSerialsController.text.trim(),
      equipmentDetails: _equipmentDetailsController.text.trim(),
    );
  }

  void _fillControllers(RepairReportTemplate template) {
    _beneficiaryController.text = template.beneficiaryName;
    _contractorController.text = template.contractorName;
    _contactPersonController.text = template.contactPerson;
    _phoneController.text = template.phone;
    _emailController.text = template.email;
    _locationController.text = template.location;
    _technicianController.text = template.technicianName;
    _teamController.text = template.teamName;
    _complaintDescriptionController.text = template.complaintDescription;
    _findingsController.text = template.findings;
    _workPerformedController.text = template.workPerformed;
    _materialsUsedController.text = template.materialsUsed;
    _recommendationsController.text = template.recommendations;
    _equipmentTypeController.text = template.equipmentType;
    _equipmentBrandController.text = template.equipmentBrand;
    _equipmentModelController.text = template.equipmentModel;
    _outdoorUnitSerialController.text = template.outdoorUnitSerial;
    _indoorUnitSerialsController.text = template.indoorUnitSerials;
    _equipmentDetailsController.text = template.equipmentDetails;
  }

  Future<void> _importJsonTemplate() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      final filePath = result?.files.single.path ?? '';
      if (filePath.trim().isEmpty) {
        return;
      }
      final raw = await File(filePath).readAsString();
      final template = widget.templateService.parseRepairReportTemplate(raw);
      _fillControllers(template);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sablonul JSON a fost importat in formular.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut importa sablonul: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      textCapitalization: TextCapitalization.sentences,
      controller: controller,
      minLines: maxLines > 1 ? maxLines : null,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sabloane PV reparatie'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Importi un JSON extern sau configurezi direct sablonul. Placeholder-e utile: {complaintNumber}, {beneficiaryName}, {contractorName}, {contactPerson}, {phone}, {email}, {location}, {technicianName}, {teamName}, {problemDescription}, {internalNotes}, {fieldFinding}, {fieldWorkPerformed}, {equipmentType}, {equipmentBrand}, {equipmentModel}, {outdoorUnitSerial}, {indoorUnitSerials}, {equipmentDetails}, {date}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                widget.templateService.repairReportTemplateExampleJson(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _importing ? null : _importJsonTemplate,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(_importing ? 'Import...' : 'Importa JSON'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _fillControllers(const RepairReportTemplate()),
                    child: const Text('Goleste formularul'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Beneficiar', _beneficiaryController),
              const SizedBox(height: 12),
              _field('Societate contractanta', _contractorController),
              const SizedBox(height: 12),
              _field('Persoana contact', _contactPersonController),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                      width: 220, child: _field('Telefon', _phoneController)),
                  SizedBox(
                      width: 260, child: _field('Email', _emailController)),
                ],
              ),
              const SizedBox(height: 12),
              _field('Locatie', _locationController, maxLines: 2),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: _field('Tehnician', _technicianController),
                  ),
                  SizedBox(
                      width: 220, child: _field('Echipa', _teamController)),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                'Descriere reclamatie',
                _complaintDescriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field('Constatare', _findingsController, maxLines: 4),
              const SizedBox(height: 12),
              _field('Lucrari efectuate', _workPerformedController,
                  maxLines: 4),
              const SizedBox(height: 12),
              _field(
                'Materiale / piese folosite',
                _materialsUsedController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(
                'Recomandari / observatii',
                _recommendationsController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field('Tip echipament', _equipmentTypeController),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: _field('Brand', _equipmentBrandController),
                  ),
                  SizedBox(
                    width: 220,
                    child: _field('Model', _equipmentModelController),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                'Serie unitate exterioara',
                _outdoorUnitSerialController,
              ),
              const SizedBox(height: 12),
              _field(
                'Serii unitati interioare',
                _indoorUnitSerialsController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(
                'Detalii tehnice',
                _equipmentDetailsController,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Inchide'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              const _RepairReportTemplateDialogResult(
                template: RepairReportTemplate(),
                resetSavedTemplate: true,
              ),
            );
          },
          child: const Text('Reseteaza implicit'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop(
              _RepairReportTemplateDialogResult(
                template: _buildTemplate(),
                applyNow: true,
              ),
            );
          },
          child: const Text('Aplica acum'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _RepairReportTemplateDialogResult(
                template: _buildTemplate(),
                applyNow: true,
                saveAsDefault: true,
              ),
            );
          },
          child: const Text('Aplica si salveaza'),
        ),
      ],
    );
  }
}
