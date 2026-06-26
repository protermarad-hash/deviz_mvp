import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/auth/app_role_policy.dart';
import '../../core/auth_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/document_file_service.dart';
import '../../core/repositories/app_data_repository.dart';
import 'complaint_intervention_editor_page.dart';
import 'complaint_models.dart';
import 'complaint_quick_offer_tab.dart';
import 'repair_report_editor_page.dart';
import 'repair_report_models.dart';
import 'repair_report_pdf_service.dart';
import 'log_fgas_reclamatie_pdf_service.dart';
import '../../core/pdf_actions_helper.dart';

class ComplaintDetailPage extends StatefulWidget {
  const ComplaintDetailPage({
    super.key,
    required this.repository,
    required this.complaint,
    this.allReports = const [],
    this.fieldAuthRoleKey,
    this.fieldAuthUserId,
    this.fieldAuthUserLabel,
    this.fieldAuthTeamId,
  });

  final AppDataRepository repository;
  final ComplaintRecord complaint;
  final List<RepairReportRecord> allReports;
  final String? fieldAuthRoleKey;
  final String? fieldAuthUserId;
  final String? fieldAuthUserLabel;
  final String? fieldAuthTeamId;

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late ComplaintRecord _complaint;
  List<RepairReportRecord> _reports = const [];
  AppUser? _currentUser;
  bool _loading = false;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _complaint = widget.complaint;
    _reports = List.of(widget.allReports);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.loadCurrentUser(),
        widget.repository.listRepairReports(),
        widget.repository.listComplaints(),
      ]);
      if (!mounted) return;
      final allReports = results[1] as List<RepairReportRecord>;
      final allComplaints = results[2] as List<ComplaintRecord>;
      final refreshed = allComplaints.where((c) => c.id == _complaint.id).firstOrNull;
      setState(() {
        _currentUser = results[0] as AppUser?;
        _reports = allReports.where((r) => r.complaintId == _complaint.id).toList();
        if (refreshed != null) _complaint = refreshed;
        _loading = false;
      });
    } catch (e) {
      FirebaseBootstrap.registerRuntimeError(e);
      if (mounted) setState(() => _loading = false);
    }
  }

  UserRole? get _role => AppRolePolicy.resolve(
        appRole: _currentUser?.role,
        roleKey: widget.fieldAuthRoleKey,
      );

  bool get _canManage => AppRolePolicy.canAccessTeamLead(_role);

  Color _statusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.noua:
        return Colors.blue;
      case ComplaintStatus.analizata:
        return Colors.indigo;
      case ComplaintStatus.programata:
        return Colors.purple;
      case ComplaintStatus.inLucru:
        return Colors.orange;
      case ComplaintStatus.inAsteptare:
        return Colors.amber.shade700;
      case ComplaintStatus.rezolvata:
        return Colors.green;
      case ComplaintStatus.inchisa:
        return Colors.grey;
      case ComplaintStatus.anulata:
        return Colors.red;
    }
  }

  Color _outcomeColor(ComplaintInterventionOutcome? outcome) {
    switch (outcome) {
      case ComplaintInterventionOutcome.rezolvata:
        return Colors.green;
      case ComplaintInterventionOutcome.necesitaRevenire:
        return Colors.orange;
      case ComplaintInterventionOutcome.necesitaPiese:
        return Colors.red;
      case ComplaintInterventionOutcome.monitorizare:
        return Colors.blue;
      case ComplaintInterventionOutcome.clientIndisponibil:
        return Colors.grey;
      case ComplaintInterventionOutcome.faraDefectConstatat:
        return Colors.teal;
      case null:
        return Colors.grey;
    }
  }

  Widget _statusBadge(ComplaintStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> rows, {IconData? icon}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                ],
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  // ── TAB 0: SUMAR ──────────────────────────────────────────────────────────

  Widget _buildSumarTab() {
    final c = _complaint;
    return ListView(
      children: [
        _sectionCard('Date reclamație', [
          _infoRow('Număr', c.complaintNumber),
          _infoRow('Data', '${c.complaintDate.day.toString().padLeft(2,'0')}.${c.complaintDate.month.toString().padLeft(2,'0')}.${c.complaintDate.year}'),
          _infoRow('Tip', c.type.label),
          _infoRow('Sursă', c.source.label),
          _infoRow('Status', c.status.label),
          // Sursă reclamație (iun 2026)
          if (c.tipSursa != 'client_direct') ...[
            const Divider(height: 10),
            _infoRow('Tip sursă',
                c.tipSursa == 'colaborator' ? 'Via colaborator' : 'Garanție producător'),
          ],
        ], icon: Icons.info_outline),
        // Banner colaborator dacă sursa nu e client direct
        if (c.tipSursa != 'client_direct' && c.colaboratorNume.isNotEmpty)
          _sectionCard('Colaborator / Societate sursă', [
            _infoRow('Societate', c.colaboratorNume),
            if (c.colaboratorContact.isNotEmpty)
              _infoRow('Persoană contact', c.colaboratorContact),
            if (c.colaboratorTelefon.isNotEmpty)
              _infoRow('Telefon', c.colaboratorTelefon),
            if (c.colaboratorRefNumber.isNotEmpty)
              _infoRow('Nr. referință', c.colaboratorRefNumber),
            if (c.clientFinalNume.isNotEmpty)
              _infoRow('Client final', c.clientFinalNume),
          ], icon: Icons.handshake_outlined),
        _sectionCard('Client / Beneficiar', [
          _infoRow('Beneficiar', c.beneficiaryName),
          _infoRow('Persoană contact', c.contactPerson),
          _infoRow('Telefon', c.phone),
          _infoRow('Email', c.email),
          _infoRow('Locație', c.location),
          if (c.hasPartner) ...[
            const Divider(height: 10),
            _infoRow('Contractor', c.contractorName),
          ],
        ], icon: Icons.person_outline),
        if (c.equipmentBrand.isNotEmpty || c.equipmentModel.isNotEmpty || c.equipmentType != null)
          _sectionCard('Echipament', [
            _infoRow('Tip', c.equipmentType?.label ?? ''),
            _infoRow('Marcă', c.equipmentBrand),
            _infoRow('Model', c.equipmentModel),
            _infoRow('Serie U.E.', c.outdoorUnitSerial),
            _infoRow('Serii U.I.', c.indoorUnitSerials),
            _infoRow('Detalii', c.equipmentDetails),
          ], icon: Icons.ac_unit_outlined),
        if (c.problemDescription.isNotEmpty)
          _sectionCard('Descriere problemă', [
            Text(c.problemDescription, style: const TextStyle(fontSize: 13)),
          ], icon: Icons.report_problem_outlined),
        if (c.internalNotes.isNotEmpty)
          _sectionCard('Note interne', [
            Text(c.internalNotes, style: const TextStyle(fontSize: 13)),
          ], icon: Icons.notes_outlined),
        _sectionCard('Linkuri', [
          if (c.jobId.isNotEmpty) _infoRow('Lucrare ID', c.jobId),
          if (c.warrantyCertificateId.isNotEmpty) _infoRow('Certificat garanție', c.warrantyCertificateId),
          if (c.appointmentId.isNotEmpty) _infoRow('Programare', c.appointmentId),
        ], icon: Icons.link_outlined),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── TAB 1: INTERVENȚII ────────────────────────────────────────────────────

  Future<void> _addIntervention() async {
    final result = await Navigator.of(context).push<ComplaintInterventionEntry>(
      MaterialPageRoute(
        builder: (_) => ComplaintInterventionEditorPage(
          complaint: _complaint,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final updated = _complaint.copyWith(
      interventionHistory: [..._complaint.interventionHistory, result],
      updatedAt: DateTime.now(),
    );
    await widget.repository.saveComplaint(updated);
    if (!mounted) return;
    setState(() => _complaint = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intervenție adăugată.')),
    );
  }

  Future<void> _editIntervention(ComplaintInterventionEntry entry) async {
    final result = await Navigator.of(context).push<ComplaintInterventionEntry>(
      MaterialPageRoute(
        builder: (_) => ComplaintInterventionEditorPage(
          complaint: _complaint,
          existing: entry,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final history = _complaint.interventionHistory.map((e) => e.id == result.id ? result : e).toList();
    final updated = _complaint.copyWith(
      interventionHistory: history,
      updatedAt: DateTime.now(),
    );
    await widget.repository.saveComplaint(updated);
    if (!mounted) return;
    setState(() => _complaint = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intervenție actualizată.')),
    );
  }

  Future<void> _deleteIntervention(ComplaintInterventionEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ștergere intervenție'),
        content: const Text('Ești sigur că vrei să ștergi această intervenție?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Anulează')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final history = _complaint.interventionHistory.where((e) => e.id != entry.id).toList();
    final updated = _complaint.copyWith(
      interventionHistory: history,
      updatedAt: DateTime.now(),
    );
    setState(() => _complaint = updated);
    widget.repository.saveComplaint(updated).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la ștergere: $e')),
        );
        _load();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Intervenție ștearsă.')),
    );
  }

  Widget _buildInterventionCard(ComplaintInterventionEntry entry, int index) {
    final color = _outcomeColor(entry.outcome);
    final date = entry.interventionDate;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Intervenția ${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                if (date != null)
                  Text(
                    '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                const Spacer(),
                if (entry.outcome != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(entry.outcome!.label, style: TextStyle(fontSize: 10, color: color)),
                  ),
                if (_canManage) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) {
                      if (val == 'edit') _editIntervention(entry);
                      if (val == 'delete') _deleteIntervention(entry);
                      if (val == 'pv') _addPvFromIntervention(entry, index);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editează')),
                      const PopupMenuItem(value: 'pv', child: Text('Generează PV')),
                      const PopupMenuItem(value: 'delete', child: Text('Șterge')),
                    ],
                  ),
                ],
              ],
            ),
            if (entry.finding.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Constatare: ${entry.finding}', style: const TextStyle(fontSize: 12)),
            ],
            if (entry.workPerformed.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Lucrări: ${entry.workPerformed}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
            if (entry.materialsUsed.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Materiale: ${entry.materialsUsed}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            if (entry.partsChanged.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Piese schimbate: ${entry.partsChanged}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addPvFromIntervention(ComplaintInterventionEntry entry, int index) async {
    final previousReports = List.of(_reports)
      ..sort((a, b) => a.interventionDate.compareTo(b.interventionDate));
    final prev = previousReports.isNotEmpty ? previousReports.last : null;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RepairReportEditorPage(
          repository: widget.repository,
          complaint: _complaint,
          previousReport: prev,
          interventionNumber: index + 1,
        ),
      ),
    );
    if (mounted) _load();
  }

  Widget _buildInterventiiTab() {
    final history = _complaint.interventionHistory;
    return Stack(
      children: [
        history.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Nicio intervenție înregistrată.', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Adaugă prima intervenție cu butonul +', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: history.length,
                itemBuilder: (_, i) => _buildInterventionCard(history[i], i),
              ),
        if (_canManage)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_interventie',
              onPressed: _addIntervention,
              icon: const Icon(Icons.add),
              label: const Text('Adaugă intervenție'),
            ),
          ),
      ],
    );
  }

  // ── TAB 2: PROCESE VERBALE ─────────────────────────────────────────────────

  Future<void> _addPv() async {
    final previousReports = List.of(_reports)
      ..sort((a, b) => a.interventionDate.compareTo(b.interventionDate));
    final prev = previousReports.isNotEmpty ? previousReports.last : null;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RepairReportEditorPage(
          repository: widget.repository,
          complaint: _complaint,
          previousReport: prev,
          interventionNumber: _reports.length + 1,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _generatePvPdf(RepairReportRecord report) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final company = await widget.repository.loadCompanyProfile();
      final path = await RepairReportPdfService.export(
        repository: widget.repository,
        company: company,
        report: report,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'PV ${report.reportNumber.isEmpty ? report.id : report.reportNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare generare PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _generateLogFGas(RepairReportRecord report) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final path = await LogFGasReclamatiePdfService.export(
        repository: widget.repository,
        report: report,
      );
      final updated =
          report.copyWith(logFGasGenerat: true, logFGasPath: path);
      await widget.repository.saveRepairReport(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log F-Gas generat.')),
      );
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title:
            'Log F-Gas ${report.reportNumber.isEmpty ? report.id : report.reportNumber}',
      );
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare generare Log F-Gas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _deletePv(RepairReportRecord report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Ștergere PV'),
        content: Text('Ștergi PV ${report.reportNumber.isEmpty ? report.id : report.reportNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Anulează')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _reports = _reports.where((r) => r.id != report.id).toList());
    widget.repository.deleteRepairReport(report.id).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la ștergere: $e')),
        );
        _load();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PV șters.')),
    );
  }

  Widget _buildPvCard(RepairReportRecord report, int index) {
    final isFollowUp = report.isFollowUp;
    final prevNum = report.previousReportNumber;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Column(
        children: [
          if (isFollowUp && prevNum.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Revenire după $prevNum',
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Intervenția ${report.interventionNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.reportNumber.isEmpty ? '(fără număr)' : report.reportNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        report.resolutionStatus.label,
                        style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${report.interventionDate.day.toString().padLeft(2,'0')}.${report.interventionDate.month.toString().padLeft(2,'0')}.${report.interventionDate.year} — ${report.technicianName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (report.findings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.findings,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _generatingPdf ? null : () => _generatePvPdf(report),
                      icon: _generatingPdf
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    ),
                    if (report.agentFrigorific.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed:
                            _generatingPdf ? null : () => _generateLogFGas(report),
                        icon: Icon(
                          report.logFGasGenerat
                              ? Icons.check_circle_outline
                              : Icons.air,
                          size: 16,
                          color: report.logFGasGenerat ? Colors.green : null,
                        ),
                        label: const Text('F-Gas', style: TextStyle(fontSize: 12)),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RepairReportEditorPage(
                              repository: widget.repository,
                              complaint: _complaint,
                              currentReport: report,
                            ),
                          ),
                        );
                        if (mounted) _load();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editează', style: TextStyle(fontSize: 12)),
                    ),
                    if (_canManage)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red.shade400,
                        tooltip: 'Șterge PV',
                        onPressed: () => _deletePv(report),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPvTab() {
    final sorted = List.of(_reports)
      ..sort((a, b) => a.interventionDate.compareTo(b.interventionDate));

    return Stack(
      children: [
        sorted.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Niciun PV generat.', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _addPv,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Adaugă primul PV'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  // Timeline line between PVs
                  for (int i = 0; i < sorted.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    _buildPvCard(sorted[i], i),
                  ],
                ],
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_pv',
            onPressed: _addPv,
            icon: const Icon(Icons.add),
            label: Text(sorted.isEmpty ? 'PV Nou' : 'PV Nou (Intervenția #${sorted.length + 1})'),
          ),
        ),
      ],
    );
  }

  // ── TAB 3: DOCUMENTE ──────────────────────────────────────────────────────

  Widget _buildDocumenteTab() {
    final docs = _complaint.linkedDocuments;
    return docs.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('Niciun document atașat.', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final doc = docs[i];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(doc.label.isEmpty ? doc.fileName : doc.label),
                subtitle: doc.fileName.isNotEmpty && doc.fileName != doc.label
                    ? Text(doc.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new_outlined),
                  onPressed: () async {
                    final result = await DocumentFileService.openFile(doc.filePath);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    }
                  },
                ),
              );
            },
          );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _complaint.complaintNumber.isEmpty
                    ? 'Reclamație'
                    : _complaint.complaintNumber,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(_complaint.status),
          ],
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reîncarcă',
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Sumar'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Intervenții'),
            Tab(icon: Icon(Icons.description_outlined), text: 'PV-uri'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Documente'),
            Tab(icon: Icon(Icons.request_quote_outlined), text: 'Ofertă'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSumarTab(),
          _buildInterventiiTab(),
          _buildPvTab(),
          _buildDocumenteTab(),
          ComplaintQuickOfferTab(
            complaint: _complaint,
            repository: widget.repository,
            isAdmin: AppRolePolicy.canAccessOffice(_role),
          ),
        ],
      ),
    );
  }
}
