import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'complaint_models.dart';
import 'repair_report_models.dart';

class RepairReportTemplate {
  const RepairReportTemplate({
    this.beneficiaryName = '',
    this.contractorName = '',
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.location = '',
    this.technicianName = '',
    this.teamName = '',
    this.complaintDescription = '',
    this.findings = '',
    this.workPerformed = '',
    this.materialsUsed = '',
    this.recommendations = '',
    this.equipmentType = '',
    this.equipmentBrand = '',
    this.equipmentModel = '',
    this.outdoorUnitSerial = '',
    this.indoorUnitSerials = '',
    this.equipmentDetails = '',
  });

  final String beneficiaryName;
  final String contractorName;
  final String contactPerson;
  final String phone;
  final String email;
  final String location;
  final String technicianName;
  final String teamName;
  final String complaintDescription;
  final String findings;
  final String workPerformed;
  final String materialsUsed;
  final String recommendations;
  final String equipmentType;
  final String equipmentBrand;
  final String equipmentModel;
  final String outdoorUnitSerial;
  final String indoorUnitSerials;
  final String equipmentDetails;

  bool get hasContent => <String>[
        beneficiaryName,
        contractorName,
        contactPerson,
        phone,
        email,
        location,
        technicianName,
        teamName,
        complaintDescription,
        findings,
        workPerformed,
        materialsUsed,
        recommendations,
        equipmentType,
        equipmentBrand,
        equipmentModel,
        outdoorUnitSerial,
        indoorUnitSerials,
        equipmentDetails,
      ].any((value) => value.trim().isNotEmpty);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'beneficiaryName': beneficiaryName,
        'contractorName': contractorName,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'location': location,
        'technicianName': technicianName,
        'teamName': teamName,
        'complaintDescription': complaintDescription,
        'findings': findings,
        'workPerformed': workPerformed,
        'materialsUsed': materialsUsed,
        'recommendations': recommendations,
        'equipmentType': equipmentType,
        'equipmentBrand': equipmentBrand,
        'equipmentModel': equipmentModel,
        'outdoorUnitSerial': outdoorUnitSerial,
        'indoorUnitSerials': indoorUnitSerials,
        'equipmentDetails': equipmentDetails,
      };

  factory RepairReportTemplate.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString();
        if (value.trim().isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return RepairReportTemplate(
      beneficiaryName: pick(
        const <String>['beneficiaryName', 'beneficiary_name'],
      ),
      contractorName: pick(
        const <String>['contractorName', 'contractor_name'],
      ),
      contactPerson: pick(const <String>['contactPerson', 'contact_person']),
      phone: pick(const <String>['phone']),
      email: pick(const <String>['email']),
      location: pick(const <String>['location']),
      technicianName: pick(
        const <String>['technicianName', 'technician_name'],
      ),
      teamName: pick(const <String>['teamName', 'team_name']),
      complaintDescription: pick(
        const <String>['complaintDescription', 'complaint_description'],
      ),
      findings: pick(const <String>['findings']),
      workPerformed: pick(
        const <String>['workPerformed', 'work_performed'],
      ),
      materialsUsed: pick(const <String>['materialsUsed', 'materials_used']),
      recommendations: pick(const <String>['recommendations']),
      equipmentType: pick(const <String>['equipmentType', 'equipment_type']),
      equipmentBrand: pick(
        const <String>['equipmentBrand', 'equipment_brand'],
      ),
      equipmentModel: pick(
        const <String>['equipmentModel', 'equipment_model'],
      ),
      outdoorUnitSerial: pick(
        const <String>['outdoorUnitSerial', 'outdoor_unit_serial'],
      ),
      indoorUnitSerials: pick(
        const <String>['indoorUnitSerials', 'indoor_unit_serials'],
      ),
      equipmentDetails: pick(
        const <String>['equipmentDetails', 'equipment_details'],
      ),
    );
  }
}

class ComplaintDocumentTemplateService {
  const ComplaintDocumentTemplateService();

  static const String _repairReportTemplateKey =
      'complaint_repair_report_template_v1';

  Future<RepairReportTemplate> loadRepairReportTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_repairReportTemplateKey);
    if (raw == null || raw.trim().isEmpty) {
      return const RepairReportTemplate();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const RepairReportTemplate();
      }
      return RepairReportTemplate.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const RepairReportTemplate();
    }
  }

  Future<void> saveRepairReportTemplate(RepairReportTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _repairReportTemplateKey, jsonEncode(template.toMap()));
  }

  Future<void> resetRepairReportTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_repairReportTemplateKey);
  }

  RepairReportTemplate parseRepairReportTemplate(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException(
          'Fisierul JSON trebuie sa contina un obiect.');
    }
    return RepairReportTemplate.fromMap(Map<String, dynamic>.from(decoded));
  }

  String repairReportTemplateExampleJson() {
    const example = RepairReportTemplate(
      beneficiaryName: '{beneficiaryName}',
      contractorName: '{contractorName}',
      contactPerson: '{contactPerson}',
      phone: '{phone}',
      email: '{email}',
      location: '{location}',
      technicianName: '{technicianName}',
      teamName: '{teamName}',
      complaintDescription: 'Sesizare {complaintNumber}: {problemDescription}',
      findings: '{fieldFinding}',
      workPerformed: '{fieldWorkPerformed}',
      materialsUsed: '{materialsUsed}',
      recommendations: '{internalNotes}',
      equipmentType: '{equipmentType}',
      equipmentBrand: '{equipmentBrand}',
      equipmentModel: '{equipmentModel}',
      outdoorUnitSerial: '{outdoorUnitSerial}',
      indoorUnitSerials: '{indoorUnitSerials}',
      equipmentDetails: '{equipmentDetails}',
    );
    return const JsonEncoder.withIndent('  ').convert(example.toMap());
  }

  RepairReportRecord applyRepairReportTemplate({
    required RepairReportTemplate template,
    required RepairReportRecord current,
    required ComplaintRecord complaint,
  }) {
    if (!template.hasContent) {
      return current;
    }
    final tokens = _repairTokens(current: current, complaint: complaint);
    return current.copyWith(
      beneficiaryName: _mergeTemplateValue(
        current.beneficiaryName,
        template.beneficiaryName,
        tokens,
      ),
      contractorName: _mergeTemplateValue(
        current.contractorName,
        template.contractorName,
        tokens,
      ),
      contactPerson: _mergeTemplateValue(
        current.contactPerson,
        template.contactPerson,
        tokens,
      ),
      phone: _mergeTemplateValue(current.phone, template.phone, tokens),
      email: _mergeTemplateValue(current.email, template.email, tokens),
      location:
          _mergeTemplateValue(current.location, template.location, tokens),
      technicianName: _mergeTemplateValue(
        current.technicianName,
        template.technicianName,
        tokens,
      ),
      teamName:
          _mergeTemplateValue(current.teamName, template.teamName, tokens),
      complaintDescription: _mergeTemplateValue(
        current.complaintDescription,
        template.complaintDescription,
        tokens,
      ),
      findings:
          _mergeTemplateValue(current.findings, template.findings, tokens),
      workPerformed: _mergeTemplateValue(
        current.workPerformed,
        template.workPerformed,
        tokens,
      ),
      materialsUsed: _mergeTemplateValue(
        current.materialsUsed,
        template.materialsUsed,
        tokens,
      ),
      recommendations: _mergeTemplateValue(
        current.recommendations,
        template.recommendations,
        tokens,
      ),
      equipmentType: _mergeTemplateValue(
        current.equipmentType,
        template.equipmentType,
        tokens,
      ),
      equipmentBrand: _mergeTemplateValue(
        current.equipmentBrand,
        template.equipmentBrand,
        tokens,
      ),
      equipmentModel: _mergeTemplateValue(
        current.equipmentModel,
        template.equipmentModel,
        tokens,
      ),
      outdoorUnitSerial: _mergeTemplateValue(
        current.outdoorUnitSerial,
        template.outdoorUnitSerial,
        tokens,
      ),
      indoorUnitSerials: _mergeTemplateValue(
        current.indoorUnitSerials,
        template.indoorUnitSerials,
        tokens,
      ),
      equipmentDetails: _mergeTemplateValue(
        current.equipmentDetails,
        template.equipmentDetails,
        tokens,
      ),
    );
  }

  Map<String, String> _repairTokens({
    required RepairReportRecord current,
    required ComplaintRecord complaint,
  }) {
    return <String, String>{
      'reportNumber': current.reportNumber.trim(),
      'complaintNumber': complaint.complaintNumber.trim(),
      'beneficiaryName': current.beneficiaryName.trim(),
      'contractorName': current.contractorName.trim(),
      'contactPerson': current.contactPerson.trim(),
      'phone': current.phone.trim(),
      'email': current.email.trim(),
      'location': current.location.trim(),
      'technicianName': current.technicianName.trim(),
      'teamName': current.teamName.trim(),
      'complaintDescription': current.complaintDescription.trim(),
      'problemDescription': complaint.problemDescription.trim(),
      'internalNotes': complaint.internalNotes.trim(),
      'fieldFinding': complaint.fieldFinding.trim(),
      'fieldWorkPerformed': complaint.fieldWorkPerformed.trim(),
      'findings': current.findings.trim(),
      'workPerformed': current.workPerformed.trim(),
      'materialsUsed': current.materialsUsed.trim(),
      'recommendations': current.recommendations.trim(),
      'equipmentType': current.equipmentType.trim(),
      'equipmentBrand': current.equipmentBrand.trim(),
      'equipmentModel': current.equipmentModel.trim(),
      'outdoorUnitSerial': current.outdoorUnitSerial.trim(),
      'indoorUnitSerials': current.indoorUnitSerials.trim(),
      'equipmentDetails': current.equipmentDetails.trim(),
      'date': _formatDate(current.interventionDate),
    };
  }

  String _mergeTemplateValue(
    String current,
    String template,
    Map<String, String> tokens,
  ) {
    if (template.trim().isEmpty) {
      return current;
    }
    return _resolveTokens(template, tokens);
  }

  String _resolveTokens(String value, Map<String, String> tokens) {
    var output = value;
    tokens.forEach((key, tokenValue) {
      output = output.replaceAll('{$key}', tokenValue);
    });
    return output;
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}
