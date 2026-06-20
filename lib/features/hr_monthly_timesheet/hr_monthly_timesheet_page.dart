import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../../core/auth_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/document_file_service.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../registratura/registry_models.dart';
import '../employees/firebase_angajati_repository.dart';
import '../hr_core/hr_employee_catalog_service.dart';
import '../hr_core/hr_employee_models.dart';
import '../master/master_local_store.dart';
import '../hr_payroll_calc/hr_payroll_calculation_catalog_service.dart';
import '../hr_payroll_input/hr_payroll_input_catalog_service.dart';
import 'monthly_timesheet_excel_service.dart';
import 'monthly_timesheet_pdf_service.dart';
import 'monthly_timesheet_models.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

class HrMonthlyTimesheetPage extends StatefulWidget {
  const HrMonthlyTimesheetPage({
    super.key,
    required this.repository,
    this.currentUser,
  });

  final AppDataRepository repository;
  final AppUser? currentUser;

  @override
  State<HrMonthlyTimesheetPage> createState() => _HrMonthlyTimesheetPageState();
}

class _HrMonthlyTimesheetPageState extends State<HrMonthlyTimesheetPage> {
  final HrEmployeeCatalogService _employeeService = HrEmployeeCatalogService();
  final HrPayrollInputCatalogService _payrollInputService =
      HrPayrollInputCatalogService();
  final HrPayrollCalculationCatalogService _calculationService =
      HrPayrollCalculationCatalogService();
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  bool _saving = false;
  bool _generatingSalarii = false;
  MonthlyTimesheetRecord? _record;
  Map<String, HrContract> _contractsByEmployeeId = const <String, HrContract>{};
  final ScrollController _horizontalScrollController = ScrollController();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _budgetControllers =
      <String, TextEditingController>{};

  int get _daysInMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _budgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await widget.repository.listMonthlyTimesheets();
    final employees = await _listActiveEmployees();
    final contracts = await _employeeService.listContracts();
    final contractsByEmployeeId = <String, HrContract>{};
    for (final contract in contracts) {
      final employeeId = contract.employeeId.trim();
      if (employeeId.isEmpty) continue;
      if (!contract.appliesTo(_selectedMonth) &&
          !contract.hasChildcareLeaveOverlapInMonth(_selectedMonth)) {
        continue;
      }
      final previous = contractsByEmployeeId[employeeId];
      if (previous == null ||
          contract.startDate.isAfter(previous.startDate) ||
          contract.updatedAt.isAfter(previous.updatedAt)) {
        contractsByEmployeeId[employeeId] = contract;
      }
    }
    final existing = all.where((item) {
      return item.year == _selectedMonth.year &&
          item.month == _selectedMonth.month;
    }).fold<MonthlyTimesheetRecord?>(
      null,
      (previous, item) => previous ?? item,
    );
    final rawRecord = existing != null
        ? _mergeEmployeesIntoRecord(
            existing.normalizeForMonth(),
            employees,
            contractsByEmployeeId,
          )
        : _buildInitialRecordFromEmployees(employees, contractsByEmployeeId);
    final record =
        _applyChildcareLeaveToRecord(rawRecord, contractsByEmployeeId);
    _rebuildControllers(record);
    _rebuildBudgetControllers(record);
    if (!mounted) {
      return;
    }
    setState(() {
      _record = record;
      _contractsByEmployeeId = contractsByEmployeeId;
      _loading = false;
    });
  }

  MonthlyTimesheetRecord _buildInitialRecordFromEmployees(
    List<_TimesheetEmployeeOption> employees,
    Map<String, HrContract> contractsByEmployeeId,
  ) {
    final rows = employees.map(
      (employee) {
        final contract = contractsByEmployeeId[employee.id];
        final isCcc =
            contract?.hasChildcareLeaveOverlapInMonth(_selectedMonth) ?? false;
        return MonthlyTimesheetEmployeeRow(
          employeeId: employee.id,
          employeeName:
              employee.name.trim().isEmpty ? employee.id : employee.name.trim(),
          teamId: employee.teamId.trim(),
          teamName: employee.teamName,
          dayValues: <String, String>{
            for (var day = 1; day <= _daysInMonth; day++)
              '$day': _isChildcareLeaveDay(contract, day) ? 'CCC' : '',
          },
          notes: isCcc ? 'CCC activ pe luna selectata.' : '',
        );
      },
    ).toList(growable: false);
    final monthKey =
        '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    return MonthlyTimesheetRecord(
      id: 'monthly-timesheet-$monthKey',
      year: _selectedMonth.year,
      month: _selectedMonth.month,
      rows: rows,
      createdByUserId: widget.currentUser?.id ?? '',
      createdByName: widget.currentUser?.displayName ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  MonthlyTimesheetRecord _mergeEmployeesIntoRecord(
    MonthlyTimesheetRecord record,
    List<_TimesheetEmployeeOption> employees,
    Map<String, HrContract> contractsByEmployeeId,
  ) {
    final rowByEmployeeId = <String, MonthlyTimesheetEmployeeRow>{
      for (final row in record.rows)
        row.employeeId.trim(): row.normalizeForDays(record.daysInMonth),
    };
    final mergedRows = employees.map((employee) {
      final existingRow = rowByEmployeeId[employee.id];
      if (existingRow == null) {
        final contract = contractsByEmployeeId[employee.id];
        final isCcc =
            contract?.hasChildcareLeaveOverlapInMonth(_selectedMonth) ?? false;
        return MonthlyTimesheetEmployeeRow(
          employeeId: employee.id,
          employeeName:
              employee.name.trim().isEmpty ? employee.id : employee.name.trim(),
          teamId: employee.teamId.trim(),
          teamName: employee.teamName,
          dayValues: <String, String>{
            for (var day = 1; day <= record.daysInMonth; day++)
              '$day': _isChildcareLeaveDay(contract, day) ? 'CCC' : '',
          },
          notes: isCcc ? 'CCC activ pe luna selectata.' : '',
        );
      }
      final contract = contractsByEmployeeId[employee.id];
      final isCcc =
          contract?.hasChildcareLeaveOverlapInMonth(_selectedMonth) ?? false;
      return existingRow.copyWith(
        employeeName: employee.name.trim().isEmpty
            ? existingRow.employeeName
            : employee.name.trim(),
        teamId: employee.teamId.trim(),
        teamName: employee.teamName,
        dayValues: <String, String>{
          for (var day = 1; day <= record.daysInMonth; day++)
            '$day': existingRow.dayValues['$day'] ?? '',
        },
        notes: isCcc ? 'CCC activ pe luna selectata.' : existingRow.notes,
      );
    }).toList(growable: false);
    return record.copyWith(rows: mergedRows, updatedAt: DateTime.now());
  }

  MonthlyTimesheetRecord _applyChildcareLeaveToRecord(
    MonthlyTimesheetRecord record,
    Map<String, HrContract> contractsByEmployeeId,
  ) {
    final rows = record.rows.map((row) {
      final contract = contractsByEmployeeId[row.employeeId.trim()];
      if (contract == null ||
          !contract.hasChildcareLeaveOverlapInMonth(_selectedMonth)) {
        return row;
      }
      final dayValues = <String, String>{...row.dayValues};
      for (var day = 1; day <= record.daysInMonth; day++) {
        if (_isChildcareLeaveDay(contract, day)) {
          dayValues['$day'] = 'CCC';
        }
      }
      return row.copyWith(
        dayValues: dayValues,
        notes: 'CCC activ pe luna selectata.',
      );
    }).toList(growable: false);
    return record.copyWith(rows: rows, updatedAt: DateTime.now());
  }

  Future<List<_TimesheetEmployeeOption>> _listActiveEmployees() async {
    final local = await MasterLocalStore.readEmployees();
    var employees = local;
    if (FirebaseBootstrap.isInitialized) {
      try {
        employees = await FirebaseAngajatiRepository().listEmployees();
        await MasterLocalStore.writeEmployees(employees);
      } catch (e) {
        debugPrint('[HrMonthlyTimesheet] citire angajați cloud eșuată, folosesc local: $e');
      }
    }
    final teams = await MasterLocalStore.readTeams();
    final teamNameById = <String, String>{
      for (final team in teams) team.id.trim(): team.name.trim(),
    };
    return employees
        .where((employee) => employee.active)
        .map(
          (employee) => _TimesheetEmployeeOption(
            id: employee.id.trim(),
            name: employee.name.trim(),
            teamId: employee.teamId.trim(),
            teamName: teamNameById[employee.teamId.trim()] ?? '',
          ),
        )
        .where((employee) => employee.id.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _rebuildControllers(MonthlyTimesheetRecord record) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final row in record.rows) {
      for (var day = 1; day <= record.daysInMonth; day++) {
        final key = _cellKey(row.employeeId, day);
        _controllers[key] = TextEditingController(
          text: row.dayValues['$day'] ?? '',
        );
      }
    }
  }

  void _rebuildBudgetControllers(MonthlyTimesheetRecord record) {
    for (final controller in _budgetControllers.values) {
      controller.dispose();
    }
    _budgetControllers.clear();
    for (final row in record.rows) {
      final text = row.mealTicketBudgetRon > 0
          ? row.mealTicketBudgetRon.toStringAsFixed(0)
          : '';
      _budgetControllers[row.employeeId] = TextEditingController(text: text);
    }
  }

  String _cellKey(String employeeId, int day) => '$employeeId::$day';

  bool _isChildcareLeaveDay(HrContract? contract, int day) {
    if (contract == null) return false;
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    return contract.isChildcareLeaveActiveOn(date);
  }

  bool _isWeekend(int day) {
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  bool _isUnusualValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final hours = MonthlyTimesheetValueParser.hoursFromValue(normalized);
    if (hours > 24) {
      return true;
    }
    final upper = normalized.toUpperCase();
    return hours == 0 &&
        MonthlyTimesheetValueParser.codeFromValue(upper) == 'ALT' &&
        !MonthlyTimesheetValueParser.supportedCodes.contains(upper);
  }

  void _replaceRecord(MonthlyTimesheetRecord record) {
    _rebuildControllers(record);
    _rebuildBudgetControllers(record);
    if (!mounted) {
      _record = record;
      return;
    }
    setState(() {
      _record = record;
    });
  }

  void _updateBudget(String employeeId, String rawValue) {
    final record = _record;
    if (record == null) return;
    final budget = double.tryParse(rawValue.trim().replaceAll(',', '.')) ?? 0.0;
    final rows = record.rows.map((row) {
      if (row.employeeId != employeeId) return row;
      return row.copyWith(mealTicketBudgetRon: budget);
    }).toList(growable: false);
    _record = record.copyWith(rows: rows, updatedAt: DateTime.now());
    // Rebuild to refresh totals column (setstate not needed — grid reads
    // from _record directly during next frame)
    setState(() {});
  }

  /// Zile lucrate (ore > 0) pentru un rand — estimare rapida
  int _eligibleDaysForRow(MonthlyTimesheetEmployeeRow row) {
    return row.dayValues.entries
        .where((e) =>
            MonthlyTimesheetValueParser.hoursFromValue(e.value) > 0 &&
            !_isWeekend(int.tryParse(e.key) ?? 0))
        .length;
  }

  Future<void> _generatSalarii() async {
    final record = _record;
    if (record == null) return;
    // 1. Salveaza mai intai pontajul
    setState(() => _generatingSalarii = true);
    try {
      await widget.repository.saveMonthlyTimesheet(
        record.copyWith(updatedAt: DateTime.now()),
      );
      final results = <_SalaryGenResult>[];
      for (final row in record.rows) {
        // 2. Genereaza snapshot pontaj din grila de pontaj (sursa unica de adevar)
        final budget = row.mealTicketBudgetRon;
        final generatedSnapshot =
            await _payrollInputService.generateMonthlySnapshotForEmployee(
          employeeId: row.employeeId,
          payrollMonth: _selectedMonth,
          generatedByUserId: widget.currentUser?.id ?? '',
          notes: 'Generat automat din tabelul de pontaj lunar.',
          mealTicketBudgetOverride: budget,
          timesheetRow: row,
        );
        final result =
            await _calculationService.calculatePayrollForEmployeeMonth(
          employeeId: row.employeeId,
          payrollMonth: _selectedMonth,
          inputSnapshot: generatedSnapshot,
        );
        results.add(_SalaryGenResult(
          employeeName: row.employeeName,
          netFinal: result?.netFinal,
          mealTickets: result?.mealTicketsTotalValue,
          mealTicketTax: result?.mealTicketIncomeTaxAmount,
          mealTicketCass: result?.mealTicketCassAmount,
          error: result == null ? 'Nu s-a putut calcula' : null,
        ));
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _SalaryResultsDialog(
          month: _selectedMonth,
          results: results,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la generarea salariilor: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingSalarii = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
    await _load();
  }

  void _updateCell(String employeeId, int day, String value) {
    final record = _record;
    if (record == null) {
      return;
    }
    final normalized = MonthlyTimesheetValueParser.normalize(value);
    final rows = record.rows.map((row) {
      if (row.employeeId != employeeId) {
        return row;
      }
      final contract = _contractsByEmployeeId[employeeId.trim()];
      if (_isChildcareLeaveDay(contract, day)) {
        return row.copyWith(
          dayValues: <String, String>{...row.dayValues, '$day': 'CCC'},
          notes: 'CCC activ pe luna selectata.',
        );
      }
      final nextValues = <String, String>{...row.dayValues, '$day': normalized};
      return row.copyWith(dayValues: nextValues);
    }).toList(growable: false);
    _record = record.copyWith(rows: rows, updatedAt: DateTime.now());
  }

  Future<void> _applyRangeForRow(MonthlyTimesheetEmployeeRow row) async {
    final request = await showDialog<_TimesheetRangeApplyRequest>(
      context: context,
      builder: (context) => _TimesheetRangeApplyDialog(
        employeeName: row.employeeName,
        daysInMonth: _daysInMonth,
      ),
    );
    if (request == null) {
      return;
    }
    final record = _record;
    if (record == null) {
      return;
    }
    final normalizedValue =
        MonthlyTimesheetValueParser.normalize(request.value.trim());
    final rows = record.rows.map((item) {
      if (item.employeeId != row.employeeId) {
        return item;
      }
      final dayValues = <String, String>{...item.dayValues};
      for (var day = request.startDay; day <= request.endDay; day++) {
        dayValues['$day'] = normalizedValue;
      }
      return item.copyWith(dayValues: dayValues);
    }).toList(growable: false);
    _replaceRecord(record.copyWith(rows: rows, updatedAt: DateTime.now()));
  }

  Future<void> _copyRangeFromRow(MonthlyTimesheetEmployeeRow sourceRow) async {
    final record = _record;
    if (record == null) {
      return;
    }
    final request = await showDialog<_TimesheetCopyRequest>(
      context: context,
      builder: (context) => _TimesheetCopyDialog(
        sourceRow: sourceRow,
        rows: record.rows,
        daysInMonth: _daysInMonth,
      ),
    );
    if (request == null) {
      return;
    }
    final sourceValues = <String, String>{
      for (var day = request.startDay; day <= request.endDay; day++)
        '$day': sourceRow.dayValues['$day'] ?? '',
    };
    final targetIds = request.applyToSameTeam
        ? record.rows
            .where(
              (row) =>
                  row.teamId.trim().isNotEmpty &&
                  row.teamId.trim() == sourceRow.teamId.trim() &&
                  row.employeeId != sourceRow.employeeId,
            )
            .map((row) => row.employeeId)
            .toSet()
        : <String>{request.targetEmployeeId};
    if (targetIds.isEmpty) {
      return;
    }
    final rows = record.rows.map((row) {
      if (!targetIds.contains(row.employeeId)) {
        return row;
      }
      final dayValues = <String, String>{...row.dayValues};
      for (var day = request.startDay; day <= request.endDay; day++) {
        dayValues['$day'] = sourceValues['$day'] ?? '';
      }
      return row.copyWith(dayValues: dayValues);
    }).toList(growable: false);
    _replaceRecord(record.copyWith(rows: rows, updatedAt: DateTime.now()));
  }

  Future<void> _save() async {
    final record = _record;
    if (record == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveMonthlyTimesheet(
        record.copyWith(updatedAt: DateTime.now()),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pontajul lunar a fost salvat.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut salva pontajul: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _exportPdf({
    required bool share,
    bool saveAs = false,
  }) async {
    final record = _record;
    if (record == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final persisted = record.copyWith(updatedAt: DateTime.now());
      await widget.repository.saveMonthlyTimesheet(persisted);
      final filePath = await MonthlyTimesheetPdfService.export(
        repository: widget.repository,
        record: persisted,
        saveAs: saveAs,
      );
      await widget.repository.registerGeneratedDocument(
        registryType: RegistryType.iesire,
        documentCategory: 'Pontaj lunar',
        documentTitle:
            'Pontaj lunar ${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
        documentNumber:
            'PONTAJ-${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}',
        documentDate: DateTime.now(),
        issuerName: widget.currentUser?.displayName ?? 'HR',
        filePath: filePath,
        fileName: _fileNameFromPath(filePath),
        notes:
            'Document generat din modulul hr_monthly_timesheet pentru ${persisted.rows.length} angajati.',
        status: 'emis',
      );
      if (share) {
        await DocumentFileService.shareFile(
          filePath,
          subject:
              'Pontaj lunar ${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
          text: 'Pontaj lunar generat din aplicatie.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF-ul de pontaj pregătit pentru share.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF pontaj generat.')),
        );
        await PdfActionsHelper.showPdfActions(
          context,
          filePath: filePath,
          title: 'Pontaj lunar PDF generat',
          shareSubject:
              'Pontaj lunar ${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
          shareText: 'Pontaj lunar generat din aplicație.',
        );
      }
    } on PdfSaveCanceledException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea PDF-ului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut genera PDF-ul de pontaj: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _exportExcel({
    required bool share,
    bool saveAs = false,
  }) async {
    final record = _record;
    if (record == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final persisted = record.copyWith(updatedAt: DateTime.now());
      await widget.repository.saveMonthlyTimesheet(persisted);
      final filePath = await MonthlyTimesheetExcelService.export(
        repository: widget.repository,
        record: persisted,
        saveAs: saveAs,
      );
      await widget.repository.registerGeneratedDocument(
        registryType: RegistryType.iesire,
        documentCategory: 'Pontaj lunar Excel',
        documentTitle:
            'Pontaj lunar Excel ${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
        documentNumber:
            'PONTAJ-XLS-${_selectedMonth.year}${_selectedMonth.month.toString().padLeft(2, '0')}',
        documentDate: DateTime.now(),
        issuerName: widget.currentUser?.displayName ?? 'HR',
        filePath: filePath,
        fileName: _fileNameFromPath(filePath),
        notes:
            'Fisier Excel generat din modulul hr_monthly_timesheet pentru ${persisted.rows.length} angajati.',
        status: 'emis',
      );
      if (share) {
        await DocumentFileService.shareFile(
          filePath,
          subject:
              'Pontaj lunar Excel ${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
          text: 'Pontaj lunar Excel generat din aplicatie.',
        );
      } else {
        await _openGeneratedDocument(filePath);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            share
                ? 'Excel-ul de pontaj a fost generat si pregatit pentru share.'
                : saveAs
                    ? 'Excel-ul de pontaj a fost salvat (Salveaza ca...) si deschis: $filePath'
                    : 'Excel-ul de pontaj a fost salvat si deschis: $filePath',
          ),
        ),
      );
    } on MonthlyTimesheetExcelSaveCanceledException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea Excel-ului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nu am putut genera Excel-ul de pontaj: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _handleExcelAction(_TimesheetExcelAction action) {
    switch (action) {
      case _TimesheetExcelAction.export:
        return _exportExcel(share: false);
      case _TimesheetExcelAction.saveAs:
        return _exportExcel(share: false, saveAs: true);
      case _TimesheetExcelAction.share:
        return _exportExcel(share: true);
    }
  }

  Future<void> _openGeneratedDocument(String filePath) async {
    final result = await DocumentFileService.openFile(filePath);
    if (result.opened || !mounted) {
      return;
    }

    if (DocumentFileService.supportsFolderOpen) {
      await DocumentFileService.openFolderForFile(filePath);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.message} Documentul a fost salvat in: $filePath',
        ),
      ),
    );
  }

  String _weekdayLabel(int day) {
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    const labels = <int, String>{
      DateTime.monday: 'L',
      DateTime.tuesday: 'Ma',
      DateTime.wednesday: 'Mi',
      DateTime.thursday: 'J',
      DateTime.friday: 'V',
      DateTime.saturday: 'S',
      DateTime.sunday: 'D',
    };
    return labels[date.weekday] ?? '-';
  }

  Widget _headerCell(String text, {double width = 56, FontWeight? weight}) {
    return Container(
      width: width,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: weight ?? FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _dayCellColor({
    required String value,
    required int day,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (_isUnusualValue(value)) {
      return scheme.errorContainer;
    }
    if (MonthlyTimesheetValueParser.codeFromValue(value) == 'CCC') {
      return scheme.tertiaryContainer;
    }
    if (value.trim().isEmpty) {
      return _isWeekend(day)
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest;
    }
    if (_isWeekend(day)) {
      return scheme.secondaryContainer;
    }
    return scheme.surface;
  }

  Widget _buildGrid(MonthlyTimesheetRecord record) {
    final monthlySummary = <String, int>{
      for (final option in MonthlyTimesheetCodeOption.defaults)
        option.code: record.totalCodeCount(option.code),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return _buildMobileGrid(record, monthlySummary);
        }
        return Scrollbar(
          thumbVisibility: true,
          controller: _horizontalScrollController,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 310 + 92 + 110 + (_daysInMonth * 56) + 72 + 220 + 90,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  _headerCell('Angajat', width: 310),
                  _headerCell('Actiuni', width: 92),
                  _headerCell('TM buget\n(RON net)', width: 110),
                  for (var day = 1; day <= _daysInMonth; day++)
                    Container(
                      width: 56,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isWeekend(day)
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        '$day\n${_weekdayLabel(day)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _headerCell('Ore', width: 72),
                  for (final option in MonthlyTimesheetCodeOption.defaults)
                    _headerCell(option.code, width: 52),
                  _headerCell('TM\nRON/zi\n(net)', width: 90),
                ],
              ),
              for (final row in record.rows)
                Row(
                  children: [
                    Container(
                      width: 310,
                      height: 52,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            row.employeeName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (row.notes.trim().toUpperCase().contains('CCC'))
                            Text(
                              'CCC activ',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            )
                          else if (row.teamName.trim().isNotEmpty)
                            Text(
                              row.teamName.trim(),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 92,
                      height: 52,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Aplica valoare pe interval',
                            onPressed: () => _applyRangeForRow(row),
                            icon:
                                const Icon(Icons.date_range_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Copiaza interval pe alt angajat / echipa',
                            onPressed: () => _copyRangeFromRow(row),
                            icon: const Icon(Icons.content_copy_outlined,
                                size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    // ── Coloana buget tichete de masa ─────────────────
                    Container(
                      width: 110,
                      height: 52,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        color: Theme.of(context)
                            .colorScheme
                            .tertiaryContainer
                            .withValues(alpha: 0.25),
                      ),
                      child: TextField(
                        controller: _budgetControllers[row.employeeId],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        ],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                          hintText: '0',
                        ),
                        onChanged: (v) => _updateBudget(row.employeeId, v),
                      ),
                    ),
                    for (var day = 1; day <= _daysInMonth; day++)
                      Builder(
                        builder: (context) {
                          final value = row.dayValues['$day'] ?? '';
                          return Container(
                            width: 56,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _dayCellColor(value: value, day: day),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: TextField(
                              controller:
                                  _controllers[_cellKey(row.employeeId, day)],
                              readOnly: _isChildcareLeaveDay(
                                _contractsByEmployeeId[row.employeeId.trim()],
                                day,
                              ),
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                hintText: _isWeekend(day) ? '-' : '',
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              style: TextStyle(
                                fontWeight: value.trim().isEmpty
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                                color: _isUnusualValue(value)
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer
                                    : MonthlyTimesheetValueParser.codeFromValue(
                                                value) ==
                                            'CCC'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer
                                        : null,
                              ),
                              onChanged: (value) =>
                                  _updateCell(row.employeeId, day, value),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 72,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Text(
                        row.totalWorkedHours.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final option in MonthlyTimesheetCodeOption.defaults)
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                        ),
                        child: Text(row.countCode(option.code).toString()),
                      ),
                    // ── Coloana RON/zi tichete ──────────────────────
                    Builder(builder: (context) {
                      final budget = row.mealTicketBudgetRon;
                      final eligDays = _eligibleDaysForRow(row);
                      final perDay = (budget > 0 && eligDays > 0)
                          ? budget / eligDays
                          : 0.0;
                      return Container(
                        width: 90,
                        height: 52,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          color: budget > 0
                              ? Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer
                                  .withValues(alpha: 0.45)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                        ),
                        child: budget <= 0
                            ? const Text('-',
                                style: TextStyle(color: Colors.grey))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    perDay.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    '$eligDays zile',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                      );
                    }),
                  ],
                ),
              Row(
                children: [
                  _headerCell('Sumar luna / actiuni',
                      width: 512, weight: FontWeight.w700),
                  for (var day = 1; day <= _daysInMonth; day++)
                    Container(
                      width: 56,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isWeekend(day)
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  _headerCell(record.totalWorkedHours.toStringAsFixed(0),
                      width: 72),
                  for (final option in MonthlyTimesheetCodeOption.defaults)
                    _headerCell(
                      (monthlySummary[option.code] ?? 0).toString(),
                      width: 52,
                    ),
                  _headerCell(
                    'TM: ${record.rows.fold<double>(0, (s, r) => s + r.mealTicketBudgetRon).toStringAsFixed(0)} RON',
                    width: 90,
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileGrid(
    MonthlyTimesheetRecord record,
    Map<String, int> monthlySummary,
  ) {
    final totalMealBudget = record.rows.fold<double>(
      0,
      (sum, row) => sum + row.mealTicketBudgetRon,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sumar lună',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Ore totale: ${record.totalWorkedHours.toStringAsFixed(0)}'),
                Text('Buget tichete: ${totalMealBudget.toStringAsFixed(0)} RON'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MonthlyTimesheetCodeOption.defaults
                      .map(
                        (option) => Chip(
                          label: Text(
                            '${option.code}: ${monthlySummary[option.code] ?? 0}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        ...record.rows.map((row) {
          final budget = row.mealTicketBudgetRon;
          final eligibleDays = _eligibleDaysForRow(row);
          final perDay = (budget > 0 && eligibleDays > 0)
              ? budget / eligibleDays
              : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.employeeName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (row.notes.trim().toUpperCase().contains('CCC'))
                              Text(
                                'CCC activ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else if (row.teamName.trim().isNotEmpty)
                              Text(
                                row.teamName.trim(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Aplică valoare pe interval',
                            onPressed: () => _applyRangeForRow(row),
                            icon: const Icon(Icons.date_range_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Copiază interval',
                            onPressed: () => _copyRangeFromRow(row),
                            icon:
                                const Icon(Icons.content_copy_outlined, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _budgetControllers[row.employeeId],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Buget tichete de masă (RON)',
                    ),
                    onChanged: (value) => _updateBudget(row.employeeId, value),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Ore: ${row.totalWorkedHours.toStringAsFixed(0)}')),
                      Chip(label: Text('TM/zi: ${perDay.toStringAsFixed(2)} RON')),
                      Chip(label: Text('Zile eligibile: $eligibleDays')),
                      for (final option in MonthlyTimesheetCodeOption.defaults)
                        Chip(label: Text('${option.code}: ${row.countCode(option.code)}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_daysInMonth, (index) {
                    final day = index + 1;
                    final value = row.dayValues['$day'] ?? '';
                    final readOnly = _isChildcareLeaveDay(
                      _contractsByEmployeeId[row.employeeId.trim()],
                      day,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Text(
                              'Ziua $day\n${_weekdayLabel(day)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _isWeekend(day)
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _dayCellColor(value: value, day: day),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller:
                                    _controllers[_cellKey(row.employeeId, day)],
                                readOnly: readOnly,
                                textAlign: TextAlign.center,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  hintText: _isWeekend(day) ? '-' : '',
                                ),
                                style: TextStyle(
                                  fontWeight: value.trim().isEmpty
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: _isUnusualValue(value)
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer
                                      : MonthlyTimesheetValueParser.codeFromValue(
                                                  value) ==
                                              'CCC'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer
                                          : null,
                                ),
                                onChanged: (next) =>
                                    _updateCell(row.employeeId, day, next),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pontaj lunar tabelar'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              '${_selectedMonth.month.toString().padLeft(2, '0')}.${_selectedMonth.year}',
            ),
          ),
          FilledButton.icon(
            onPressed: _loading || _saving || _generatingSalarii
                ? null
                : _generatSalarii,
            icon: _generatingSalarii
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calculate_outlined),
            label: Text(
              _generatingSalarii ? 'Se calculeaza...' : 'Genereaza salarii',
            ),
          ),
          TextButton.icon(
            onPressed:
                _loading || _saving ? null : () => _exportPdf(share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Genereaza PDF'),
          ),
          TextButton.icon(
            onPressed: _loading || _saving
                ? null
                : () => _exportPdf(share: false, saveAs: true),
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('Salveaza ca...'),
          ),
          TextButton.icon(
            onPressed:
                _loading || _saving ? null : () => _exportPdf(share: true),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Trimite'),
          ),
          PopupMenuButton<_TimesheetExcelAction>(
            enabled: !_loading && !_saving,
            tooltip: 'Optiuni Excel',
            onSelected: _handleExcelAction,
            itemBuilder: (context) => const [
              PopupMenuItem<_TimesheetExcelAction>(
                value: _TimesheetExcelAction.export,
                child: Text('Exporta Excel'),
              ),
              PopupMenuItem<_TimesheetExcelAction>(
                value: _TimesheetExcelAction.saveAs,
                child: Text('Salveaza ca Excel'),
              ),
              PopupMenuItem<_TimesheetExcelAction>(
                value: _TimesheetExcelAction.share,
                child: Text('Trimite Excel'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_chart_outlined),
                  SizedBox(width: 6),
                  Text('Excel'),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _loading || _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Se salveaza...' : 'Salveaza'),
          ),
          HelpButton(content: AppHelp.hrPontajLunar),
        ],
      ),
      body: _loading || record == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                              label: Text(
                                  'Luna: ${_selectedMonth.month}/${_selectedMonth.year}')),
                          Chip(label: Text('Zile: $_daysInMonth')),
                          Chip(label: Text('Angajati: ${record.rows.length}')),
                          Chip(
                              label: Text(
                                  'Ore totale: ${record.totalWorkedHours.toStringAsFixed(0)}')),
                          const Chip(label: Text('Weekend evidentiat')),
                          const Chip(label: Text('Goluri marcate discret')),
                          const Chip(label: Text('Valori neobisnuite marcate')),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text('Valori acceptate in celule:'),
                          const Chip(label: Text('ore numerice: 8 / 4 / 7.5')),
                          for (final option
                              in MonthlyTimesheetCodeOption.defaults)
                            Chip(
                                label:
                                    Text('${option.code} = ${option.label}')),
                          const Chip(
                            label: Text('Actiuni pe rand: interval / copiere'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildGrid(record),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

String _fileNameFromPath(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) {
    return '';
  }
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

class _TimesheetEmployeeOption {
  const _TimesheetEmployeeOption({
    required this.id,
    required this.name,
    required this.teamId,
    required this.teamName,
  });

  final String id;
  final String name;
  final String teamId;
  final String teamName;
}

enum _TimesheetExcelAction {
  export,
  saveAs,
  share,
}

class _TimesheetRangeApplyRequest {
  const _TimesheetRangeApplyRequest({
    required this.startDay,
    required this.endDay,
    required this.value,
  });

  final int startDay;
  final int endDay;
  final String value;
}

class _TimesheetRangeApplyDialog extends StatefulWidget {
  const _TimesheetRangeApplyDialog({
    required this.employeeName,
    required this.daysInMonth,
  });

  final String employeeName;
  final int daysInMonth;

  @override
  State<_TimesheetRangeApplyDialog> createState() =>
      _TimesheetRangeApplyDialogState();
}

class _TimesheetRangeApplyDialogState
    extends State<_TimesheetRangeApplyDialog> {
  late int _startDay;
  late int _endDay;
  final TextEditingController _valueController =
      TextEditingController(text: '8');

  @override
  void initState() {
    super.initState();
    _startDay = 1;
    _endDay = widget.daysInMonth;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = List<int>.generate(widget.daysInMonth, (index) => index + 1);
    return AlertDialog(
      title: const Text('Aplica valoare pe interval'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employeeName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _startDay,
                    decoration: const InputDecoration(labelText: 'De la ziua'),
                    items: days
                        .map((day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString()),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _startDay = value;
                        if (_endDay < _startDay) {
                          _endDay = _startDay;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _endDay,
                    decoration:
                        const InputDecoration(labelText: 'Pana la ziua'),
                    items: days
                        .map((day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString()),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _endDay = value;
                        if (_startDay > _endDay) {
                          _startDay = _endDay;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Valoare',
                helperText: 'Exemple: 8, CO, CM, INV',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Aplica'),
        ),
      ],
    );
  }

  void _submit() {
    if (_valueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completeaza o valoare pentru interval.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _TimesheetRangeApplyRequest(
        startDay: _startDay,
        endDay: _endDay,
        value: _valueController.text.trim(),
      ),
    );
  }
}

class _TimesheetCopyRequest {
  const _TimesheetCopyRequest({
    required this.startDay,
    required this.endDay,
    required this.targetEmployeeId,
    required this.applyToSameTeam,
  });

  final int startDay;
  final int endDay;
  final String targetEmployeeId;
  final bool applyToSameTeam;
}

class _TimesheetCopyDialog extends StatefulWidget {
  const _TimesheetCopyDialog({
    required this.sourceRow,
    required this.rows,
    required this.daysInMonth,
  });

  final MonthlyTimesheetEmployeeRow sourceRow;
  final List<MonthlyTimesheetEmployeeRow> rows;
  final int daysInMonth;

  @override
  State<_TimesheetCopyDialog> createState() => _TimesheetCopyDialogState();
}

class _TimesheetCopyDialogState extends State<_TimesheetCopyDialog> {
  late int _startDay;
  late int _endDay;
  bool _applyToSameTeam = false;
  String _targetEmployeeId = '';

  @override
  void initState() {
    super.initState();
    _startDay = 1;
    _endDay = widget.daysInMonth;
    final firstTarget = widget.rows
        .where((row) => row.employeeId != widget.sourceRow.employeeId)
        .fold<String>('',
            (previous, row) => previous.isEmpty ? row.employeeId : previous);
    _targetEmployeeId = firstTarget;
  }

  @override
  Widget build(BuildContext context) {
    final days = List<int>.generate(widget.daysInMonth, (index) => index + 1);
    final targetRows = widget.rows
        .where((row) => row.employeeId != widget.sourceRow.employeeId)
        .toList(growable: false);
    return AlertDialog(
      title: const Text('Copiaza interval'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sursa: ${widget.sourceRow.employeeName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _startDay,
                    decoration: const InputDecoration(labelText: 'De la ziua'),
                    items: days
                        .map((day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString()),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _startDay = value;
                        if (_endDay < _startDay) {
                          _endDay = _startDay;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _endDay,
                    decoration:
                        const InputDecoration(labelText: 'Pana la ziua'),
                    items: days
                        .map((day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString()),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _endDay = value;
                        if (_startDay > _endDay) {
                          _startDay = _endDay;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _applyToSameTeam,
              onChanged: (value) => setState(() => _applyToSameTeam = value),
              title: const Text('Aplica pe toata echipa sursei'),
            ),
            if (!_applyToSameTeam)
              DropdownButtonFormField<String>(
                initialValue:
                    _targetEmployeeId.isEmpty ? null : _targetEmployeeId,
                decoration:
                    const InputDecoration(labelText: 'Angajat destinatie'),
                items: targetRows
                    .map(
                      (row) => DropdownMenuItem<String>(
                        value: row.employeeId,
                        child: Text(row.employeeName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _targetEmployeeId = value ?? ''),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Copiaza'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_applyToSameTeam && _targetEmployeeId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alege un angajat destinatie.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _TimesheetCopyRequest(
        startDay: _startDay,
        endDay: _endDay,
        targetEmployeeId: _targetEmployeeId,
        applyToSameTeam: _applyToSameTeam,
      ),
    );
  }
}

class _SalaryGenResult {
  const _SalaryGenResult({
    required this.employeeName,
    this.netFinal,
    this.mealTickets,
    this.mealTicketTax,
    this.mealTicketCass,
    this.error,
  });

  final String employeeName;
  final double? netFinal;
  final double? mealTickets;
  final double? mealTicketTax;
  final double? mealTicketCass;
  final String? error;
}

class _SalaryResultsDialog extends StatelessWidget {
  const _SalaryResultsDialog({
    required this.month,
    required this.results,
  });

  final DateTime month;
  final List<_SalaryGenResult> results;

  @override
  Widget build(BuildContext context) {
    final successful = results.where((r) => (r.error ?? '').trim().isEmpty);
    final totalNet = successful.fold<double>(
      0,
      (sum, item) => sum + (item.netFinal ?? 0),
    );
    final totalMealTickets = successful.fold<double>(
      0,
      (sum, item) => sum + (item.mealTickets ?? 0),
    );
    final totalMealTicketTax = successful.fold<double>(
      0,
      (sum, item) => sum + (item.mealTicketTax ?? 0),
    );
    final totalMealTicketCass = successful.fold<double>(
      0,
      (sum, item) => sum + (item.mealTicketCass ?? 0),
    );

    return AlertDialog(
      title: Text(
        'Rezultate salarii ${month.month.toString().padLeft(2, '0')}.${month.year}',
      ),
      content: SizedBox(
        width: 860,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Angajati procesati: ${results.length} • Net total: ${totalNet.toStringAsFixed(2)} RON • Tichete: ${totalMealTickets.toStringAsFixed(2)} RON • Impozit tichete: ${totalMealTicketTax.toStringAsFixed(2)} RON • CASS tichete: ${totalMealTicketCass.toStringAsFixed(2)} RON',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Angajat')),
                    DataColumn(label: Text('Salariu net')),
                    DataColumn(label: Text('Tichete masa')),
                    DataColumn(label: Text('Impozit tichete')),
                    DataColumn(label: Text('CASS tichete')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: results.map((result) {
                    final hasError = (result.error ?? '').trim().isNotEmpty;
                    return DataRow(
                      cells: [
                        DataCell(Text(result.employeeName)),
                        DataCell(Text(hasError
                            ? '-'
                            : '${(result.netFinal ?? 0).toStringAsFixed(2)} RON')),
                        DataCell(Text(hasError
                            ? '-'
                            : '${(result.mealTickets ?? 0).toStringAsFixed(2)} RON')),
                        DataCell(Text(hasError
                            ? '-'
                            : '${(result.mealTicketTax ?? 0).toStringAsFixed(2)} RON')),
                        DataCell(Text(hasError
                            ? '-'
                            : '${(result.mealTicketCass ?? 0).toStringAsFixed(2)} RON')),
                        DataCell(Text(hasError ? result.error! : 'OK')),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Inchide'),
        ),
      ],
    );
  }
}
