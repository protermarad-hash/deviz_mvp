import 'package:flutter/material.dart';

import '../../core/auth/app_role_policy.dart';
import '../../core/auth/field_auth_models.dart';
import '../../core/auth/field_auth_repository_factory.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/help_content.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/help_button.dart';
import '../tasks/task_dashboard_widget.dart';
import '../clients/client_models.dart';
import '../clients/warranty_alert_service.dart';
import '../clients/clienti_cloud_repository.dart';
import '../clients/firebase_clienti_repository.dart';
import '../employees/angajati_cloud_repository.dart';
import '../employees/firebase_angajati_repository.dart';
import '../jobs/firebase_lucrari_repository.dart';
import '../jobs/job_models.dart';
import '../jobs/lucrari_cloud_repository.dart';
import '../master/master_local_store.dart';
import '../oferte/local_oferte_repository.dart';
import '../oferte/offer_models.dart';
import '../programari/appointment_models.dart';
import '../programari/firebase_programari_repository.dart';
import '../programari/programari_cloud_repository.dart';
import '../reclamatii/complaint_models.dart';
import '../hr_payroll_run/hr_payroll_payment_models.dart';
import '../hr_payroll_run/hr_payroll_payment_repository.dart';
import '../teams/echipe_cloud_repository.dart';
import '../teams/firebase_echipe_repository.dart';
import '../../core/services/daily_report_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.repository,
    this.fieldAuthRoleKey,
    this.fieldAuthUserEmail,
    this.fieldAuthUserName,
    this.fieldAuthUserId,
    this.fieldAuthTeamId,
    this.onNavigateTo,
  });

  final AppDataRepository repository;
  final String? fieldAuthRoleKey;
  /// Email-ul utilizatorului (pentru query-uri/filtrare)
  final String? fieldAuthUserEmail;
  /// Numele real al utilizatorului din Firestore (afișat în UI)
  final String? fieldAuthUserName;
  final String? fieldAuthUserId;
  final String? fieldAuthTeamId;
  final void Function(String moduleId)? onNavigateTo;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  bool _loadScheduled = false;
  String _dataSourceLabel = 'local';
  String? _fallbackReason;

  List<Appointment> _appointments = const <Appointment>[];
  // Cache computate odată când se încarcă programările
  List<Appointment> _cachedTodayAppointments = const <Appointment>[];
  List<Appointment> _cachedMyRelevantAppointments = const <Appointment>[];
  List<JobRecord> _jobs = const <JobRecord>[];
  List<ClientRecord> _clients = const <ClientRecord>[];
  List<MasterEmployee> _employees = const <MasterEmployee>[];
  List<MasterTeam> _teams = const <MasterTeam>[];
  List<OfferRecord> _offers = const <OfferRecord>[];
  List<ComplaintRecord> _complaints = const <ComplaintRecord>[];
  int _registryCount = 0;
  WarrantyAlertResult _warrantyAlerts = WarrantyAlertResult.empty;
  Map<String, List<HrPayrollPayment>> _payrollPaymentsMonth =
      const <String, List<HrPayrollPayment>>{};
  FieldAuthUser? _currentUser;

  ProgramariCloudRepository? _programariCloudRepository;
  LucrariCloudRepository? _lucrariCloudRepository;
  ClientiCloudRepository? _clientiCloudRepository;
  AngajatiCloudRepository? _angajatiCloudRepository;
  EchipeCloudRepository? _echipeCloudRepository;

  bool get _isAdminLike {
    final role = AppRolePolicy.resolve(roleKey: widget.fieldAuthRoleKey);
    return AppRolePolicy.canAccessOffice(role);
  }

  String get _roleLabel {
    return AppRolePolicy.displayLabel(roleKey: widget.fieldAuthRoleKey);
  }

  @override
  void initState() {
    super.initState();
    if (FirebaseBootstrap.isInitialized) {
      _programariCloudRepository = FirebaseProgramariRepository();
      _lucrariCloudRepository = FirebaseLucrariRepository();
      _clientiCloudRepository = FirebaseClientiRepository();
      _angajatiCloudRepository = FirebaseAngajatiRepository();
      _echipeCloudRepository = FirebaseEchipeRepository();
    } else {
      _fallbackReason = FirebaseBootstrap.lastErrorMessage;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadScheduled) return;
      _loadScheduled = true;
      _load();
    });
  }

  String _shortError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _loadAppointments(),
      _loadJobs(),
      _loadClients(),
      _loadEmployees(),
      _loadTeams(),
      _loadCurrentUser(),
      _loadOffers(),
      _loadComplaints(),
      _loadRegistryCount(),
    ]);

    final appointmentsResult = results[0] as _LoadResult<List<Appointment>>;
    final jobsResult = results[1] as _LoadResult<List<JobRecord>>;
    final clientsResult = results[2] as _LoadResult<List<ClientRecord>>;
    final employeesResult = results[3] as _LoadResult<List<MasterEmployee>>;
    final teamsResult = results[4] as _LoadResult<List<MasterTeam>>;
    final user = results[5] as FieldAuthUser?;

    final allFromCloud = appointmentsResult.fromCloud &&
        jobsResult.fromCloud &&
        clientsResult.fromCloud &&
        employeesResult.fromCloud &&
        teamsResult.fromCloud;

    final firstError = appointmentsResult.errorReason ??
        jobsResult.errorReason ??
        clientsResult.errorReason ??
        employeesResult.errorReason ??
        teamsResult.errorReason ??
        FirebaseBootstrap.lastErrorMessage;

    if (!mounted) return;
    setState(() {
      _appointments = appointmentsResult.data;
      _jobs = jobsResult.data;
      _clients = clientsResult.data;
      _employees = employeesResult.data;
      _teams = teamsResult.data;
      _currentUser = user;
      _offers = results[6] as List<OfferRecord>;
      _complaints = results[7] as List<ComplaintRecord>;
      _registryCount = results[8] as int;
      _dataSourceLabel = allFromCloud ? 'cloud' : 'local';
      _fallbackReason = allFromCloud ? null : firstError;
      _loading = false;
      _updateAppointmentCache();
    });
    // Garanții — best-effort
    WarrantyAlertService.instance.loadAlerts().then((result) {
      if (mounted) setState(() => _warrantyAlerts = result);
    }).catchError((_) {});
    // Plăți salariale luna curentă — best-effort
    if (_isAdminLike) {
      HrPayrollPaymentRepository.instance
          .listPaymentsForMonth(DateTime.now())
          .then((result) {
        if (mounted) setState(() => _payrollPaymentsMonth = result);
      }).catchError((_) {});
    }
  }

  Future<FieldAuthUser?> _loadCurrentUser() async {
    final authUserId = (widget.fieldAuthUserId ?? '').trim();
    final authEmail = (widget.fieldAuthUserEmail ?? '').trim().toLowerCase();
    if (authUserId.isEmpty && authEmail.isEmpty) {
      return null;
    }
    try {
      final repo = FieldAuthRepositoryFactory.create();
      final users = await repo.listUsers();
      if (authUserId.isNotEmpty) {
        for (final user in users) {
          if (user.id.trim() == authUserId) return user;
        }
      }
      if (authEmail.isNotEmpty) {
        for (final user in users) {
          if (user.email.trim().toLowerCase() == authEmail) return user;
        }
      }
    } catch (e) {
      debugPrint('[Dashboard] rezolvare utilizator curent eșuată: $e');
    }
    return null;
  }

  Future<_LoadResult<List<Appointment>>> _loadAppointments() async {
    final cloud = _programariCloudRepository;
    if (cloud == null) {
      final local = await widget.repository.listAppointments();
      return _LoadResult<List<Appointment>>.local(local);
    }
    try {
      final rows = await cloud.listAppointments();
      return _LoadResult<List<Appointment>>.cloud(rows);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      final local = await widget.repository.listAppointments();
      return _LoadResult<List<Appointment>>.local(
        local,
        errorReason: _shortError(error),
      );
    }
  }

  Future<_LoadResult<List<JobRecord>>> _loadJobs() async {
    final cloud = _lucrariCloudRepository;
    if (cloud == null) {
      final local = await widget.repository.listJobs();
      return _LoadResult<List<JobRecord>>.local(local);
    }
    try {
      final rows = await cloud.listJobs();
      return _LoadResult<List<JobRecord>>.cloud(rows);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      final local = await widget.repository.listJobs();
      return _LoadResult<List<JobRecord>>.local(
        local,
        errorReason: _shortError(error),
      );
    }
  }

  Future<_LoadResult<List<ClientRecord>>> _loadClients() async {
    final cloud = _clientiCloudRepository;
    if (cloud == null) {
      final local = await widget.repository.listClients();
      return _LoadResult<List<ClientRecord>>.local(local);
    }
    try {
      final rows = await cloud.listClients();
      return _LoadResult<List<ClientRecord>>.cloud(rows);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      final local = await widget.repository.listClients();
      return _LoadResult<List<ClientRecord>>.local(
        local,
        errorReason: _shortError(error),
      );
    }
  }

  Future<_LoadResult<List<MasterEmployee>>> _loadEmployees() async {
    final cloud = _angajatiCloudRepository;
    if (cloud == null) {
      final local = await MasterLocalStore.readEmployees();
      return _LoadResult<List<MasterEmployee>>.local(local);
    }
    try {
      final rows = await cloud.listEmployees();
      await MasterLocalStore.writeEmployees(rows);
      return _LoadResult<List<MasterEmployee>>.cloud(rows);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      final local = await MasterLocalStore.readEmployees();
      return _LoadResult<List<MasterEmployee>>.local(
        local,
        errorReason: _shortError(error),
      );
    }
  }

  Future<_LoadResult<List<MasterTeam>>> _loadTeams() async {
    final cloud = _echipeCloudRepository;
    if (cloud == null) {
      final local = await MasterLocalStore.readTeams();
      return _LoadResult<List<MasterTeam>>.local(local);
    }
    try {
      final rows = await cloud.listTeams();
      await MasterLocalStore.writeTeams(rows);
      return _LoadResult<List<MasterTeam>>.cloud(rows);
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      final local = await MasterLocalStore.readTeams();
      return _LoadResult<List<MasterTeam>>.local(
        local,
        errorReason: _shortError(error),
      );
    }
  }

  Future<List<OfferRecord>> _loadOffers() async {
    try {
      return await LocalOferteRepository().listOffers();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ComplaintRecord>> _loadComplaints() async {
    try {
      return await widget.repository.listComplaints();
    } catch (_) {
      return const [];
    }
  }

  Future<int> _loadRegistryCount() async {
    try {
      final entries = await widget.repository.listRegistryEntries();
      final now = DateTime.now();
      return entries
          .where((e) =>
              e.registeredAt.year == now.year &&
              e.registeredAt.month == now.month)
          .length;
    } catch (_) {
      return 0;
    }
  }

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  bool _isJobActive(JobRecord job) {
    if (!job.isActive) return false;
    final status = _normalizeStatus(job.status.value);
    return status != 'inchisa';
  }

  bool _isJobOverdue(JobRecord job) {
    if (!_isJobActive(job)) return false;
    final now = DateTime.now();
    final diff = now.difference(job.updatedAt).inDays;
    return diff >= 14;
  }

  bool _isJobWaiting(JobRecord job) {
    final status = _normalizeStatus(job.status.value);
    return status == 'in_asteptare' || status == 'asteptare';
  }

  String get _effectiveTeamId {
    final userTeam = (_currentUser?.teamId ?? '').trim();
    if (userTeam.isNotEmpty) return userTeam;
    final fallback = (widget.fieldAuthTeamId ?? '').trim();
    if (fallback.isNotEmpty) return fallback;
    final employeeId = (_currentUser?.employeeId ?? '').trim();
    if (employeeId.isEmpty) return '';
    for (final employee in _employees) {
      if (employee.id == employeeId && employee.teamId.trim().isNotEmpty) {
        return employee.teamId.trim();
      }
    }
    for (final team in _teams) {
      if (team.memberIds.contains(employeeId)) {
        return team.id;
      }
    }
    return '';
  }

  bool _isMine(Appointment item) {
    final authUserId = (widget.fieldAuthUserId ?? '').trim();
    final authEmail = (widget.fieldAuthUserEmail ?? '').trim().toLowerCase();
    final sameUser =
        authUserId.isNotEmpty && item.assignedUserId.trim() == authUserId;
    final sameEmail = authEmail.isNotEmpty &&
        item.assignedUserEmail.trim().toLowerCase() == authEmail;
    return sameUser || sameEmail;
  }

  bool _isMyTeam(Appointment item) {
    final teamId = _effectiveTeamId;
    return teamId.isNotEmpty && item.teamId.trim() == teamId;
  }

  List<Appointment> get _todayAppointments => _cachedTodayAppointments;
  List<Appointment> get _myRelevantAppointments =>
      _cachedMyRelevantAppointments;

  void _updateAppointmentCache() {
    _cachedTodayAppointments = _appointments
        .where((item) => _isToday(item.scheduledDate))
        .toList(growable: false);
    _cachedMyRelevantAppointments = _appointments
        .where((item) => _isMine(item) || _isMyTeam(item))
        .toList(growable: false);
  }

  String _teamName(String teamId) {
    if (teamId.trim().isEmpty) return '-';
    for (final team in _teams) {
      if (team.id == teamId) {
        return team.name.trim().isEmpty ? team.id : team.name;
      }
    }
    return teamId;
  }

  String _cardValue(num value) => value.toString();

  Widget _kpiCard(
    String title,
    String value, {
    IconData? icon,
    Color? valueColor,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = valueColor ?? scheme.primary;
    final tappable = onTap != null;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: tappable ? 0.1 : 0.07),
            blurRadius: tappable ? 16 : 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: tappable
              ? effectiveColor.withValues(alpha: 0.2)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              color: effectiveColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: effectiveColor.withValues(alpha: 0.1),
                        ),
                        child: Icon(icon, size: 17, color: effectiveColor),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: effectiveColor,
                    height: 1.0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (tappable) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Deschide',
                        style: TextStyle(
                          fontSize: 10,
                          color: effectiveColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 9, color: effectiveColor),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!tappable) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAdminCards() {
    final programariAzi = _todayAppointments.length;
    final programariInCurs = _appointments
        .where((item) => _normalizeStatus(item.status) == 'in_curs')
        .length;
    final lucrariActive = _jobs.where(_isJobActive).length;
    final lucrariIntarziate = _jobs.where(_isJobOverdue).length;
    final lucrariAsteptare = _jobs.where(_isJobWaiting).length;
    final clientiActivi = _clients.where((client) => client.isActive).length;
    final angajatiActivi = _employees.where((emp) => emp.active).length;
    final echipeActive = _teams.length;

    // Oferte
    final oferteTotal = _offers.length;
    final oferteActive = _offers
        .where((o) =>
            o.status == OfferStatus.draft ||
            o.status == OfferStatus.sent ||
            o.status == OfferStatus.awaiting)
        .length;

    // Reclamații
    final reclamatiiDeschise = _complaints
        .where((c) =>
            c.status != ComplaintStatus.rezolvata &&
            c.status != ComplaintStatus.inchisa &&
            c.status != ComplaintStatus.anulata)
        .length;

    return <Widget>[
      _kpiCard('Programări azi', _cardValue(programariAzi),
          icon: Icons.today,
          onTap: () => widget.onNavigateTo?.call('programari')),
      _kpiCard('Programări în curs', _cardValue(programariInCurs),
          icon: Icons.play_circle_outline,
          onTap: () => widget.onNavigateTo?.call('programari')),
      _kpiCard('Lucrări active', _cardValue(lucrariActive),
          icon: Icons.work,
          onTap: () => widget.onNavigateTo?.call('lucrari')),
      _kpiCard(
        'Lucrări neactualizate 14+ zile',
        _cardValue(lucrariIntarziate),
        icon: Icons.warning_amber_rounded,
        valueColor: lucrariIntarziate > 0 ? Colors.orange.shade700 : null,
        subtitle: lucrariIntarziate > 0 ? 'Verifică progresul' : null,
        onTap: () => widget.onNavigateTo?.call('lucrari'),
      ),
      _kpiCard(
        'Lucrări în așteptare',
        _cardValue(lucrariAsteptare),
        icon: Icons.hourglass_empty,
        valueColor: lucrariAsteptare > 0 ? Colors.amber.shade800 : null,
        onTap: () => widget.onNavigateTo?.call('lucrari'),
      ),
      _kpiCard(
        'Oferte active',
        _cardValue(oferteActive),
        icon: Icons.request_quote_outlined,
        subtitle: oferteTotal > 0 ? 'Total: $oferteTotal' : null,
        onTap: () => widget.onNavigateTo?.call('oferte'),
      ),
      _kpiCard(
        'Reclamații deschise',
        _cardValue(reclamatiiDeschise),
        icon: Icons.report_problem_outlined,
        valueColor: reclamatiiDeschise > 0 ? Colors.red.shade700 : null,
        subtitle: reclamatiiDeschise > 0 ? 'Necesită atenție' : null,
        onTap: () => widget.onNavigateTo?.call('reclamatii'),
      ),
      _kpiCard('Registratură luna curentă', _cardValue(_registryCount),
          icon: Icons.book_outlined,
          onTap: () => widget.onNavigateTo?.call('registratura')),
      _kpiCard('Clienți activi', _cardValue(clientiActivi),
          icon: Icons.groups,
          onTap: () => widget.onNavigateTo?.call('clienti')),
      _kpiCard('Angajați activi', _cardValue(angajatiActivi),
          icon: Icons.badge_outlined,
          onTap: () => widget.onNavigateTo?.call('angajati')),
      _kpiCard('Echipe active', _cardValue(echipeActive),
          icon: Icons.diversity_3,
          onTap: () => widget.onNavigateTo?.call('echipe')),
    ];
  }

  List<Widget> _buildEmployeeCards() {
    final mineToday = _todayAppointments.where(_isMine).length;
    final teamToday = _todayAppointments.where(_isMyTeam).length;
    final relevantJobsCount = _myRelevantAppointments
        .map((item) => item.jobId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final teamName = _teamName(_effectiveTeamId);
    final userStatus = (_currentUser?.active ?? true) ? 'Activ' : 'Inactiv';

    return <Widget>[
      _kpiCard('Programarile mele azi', _cardValue(mineToday),
          icon: Icons.person,
          onTap: () => widget.onNavigateTo?.call('programari')),
      _kpiCard('Programarile echipei mele azi', _cardValue(teamToday),
          icon: Icons.group,
          onTap: () => widget.onNavigateTo?.call('programari')),
      _kpiCard('Lucrari relevante', _cardValue(relevantJobsCount),
          icon: Icons.assignment,
          onTap: () => widget.onNavigateTo?.call('lucrari')),
      _kpiCard('Echipa mea', teamName, icon: Icons.diversity_1),
      _kpiCard('Status utilizator', userStatus,
          icon: Icons.verified_user_outlined),
    ];
  }

  Widget _buildSummarySection() {
    final userLabel = (widget.fieldAuthUserEmail ?? '').trim().isEmpty
        ? '-'
        : widget.fieldAuthUserEmail!.trim();
    final fallback = (_fallbackReason ?? '').trim();
    return _section(
      title: 'Sumar',
      children: [
        Text('Utilizator: $userLabel'),
        Text('Rol: $_roleLabel'),
        Text('Sursa date: $_dataSourceLabel'),
        if (_dataSourceLabel == 'local' && fallback.isNotEmpty)
          Text('Motiv fallback: $fallback'),
      ],
    );
  }

  Widget _buildAdminSections() {
    final appointments = _todayAppointments.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final activeJobs = _jobs.where(_isJobActive).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final overdueJobs = _jobs.where(_isJobOverdue).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    return Column(
      children: [
        if (_warrantyAlerts.hasAlerts) _buildWarrantyAlertsCard(),
        _buildDailyReportCard(),
        _buildPayrollPaymentsSummaryCard(),
        if (overdueJobs.isNotEmpty)
          _section(
            title: '⚠ Lucrări neactualizate (14+ zile)',
            children: overdueJobs.take(5).map((job) {
              final code = job.jobCode.trim().isEmpty ? '-' : job.jobCode;
              final daysSince = DateTime.now().difference(job.updatedAt).inDays;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 20),
                title: Text(job.title.trim().isEmpty ? 'Lucrare' : job.title),
                subtitle: Text(
                    'Cod: $code | Status: ${job.status.value} | Ultima actualizare: $daysSince zile'),
              );
            }).toList(growable: false),
          ),
        _buildFinancialSection(),
        _section(
          title: 'Programări de azi',
          children: appointments.isEmpty
              ? const [Text('Nicio programare azi.')]
              : appointments.take(6).map((item) {
                  final title =
                      item.title.trim().isEmpty ? 'Programare' : item.title;
                  final team = _teamName(item.teamId);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(
                        '${item.startTime} - ${item.endTime} | Echipa: $team'),
                  );
                }).toList(growable: false),
        ),
        _section(
          title: 'Lucrări active / recente',
          children: activeJobs.isEmpty
              ? const [Text('Nicio lucrare activă.')]
              : activeJobs.take(6).map((job) {
                  final code = job.jobCode.trim().isEmpty ? '-' : job.jobCode;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title:
                        Text(job.title.trim().isEmpty ? 'Lucrare' : job.title),
                    subtitle: Text('Cod: $code | Status: ${job.status.value}'),
                  );
                }).toList(growable: false),
        ),
      ],
    );
  }

  // ── Card sumar plăți salariale ───────────────────────────────────────────
  Widget _buildPayrollPaymentsSummaryCard() {
    final now = DateTime.now();
    final monthLabel =
        '${now.month.toString().padLeft(2, '0')}.${now.year}';
    double totalAvansuri = 0.0;
    double totalSalarii = 0.0;
    int nrAngajati = 0;
    for (final entry in _payrollPaymentsMonth.entries) {
      final payments = entry.value;
      if (payments.isEmpty) continue;
      nrAngajati++;
      for (final p in payments) {
        if (p.paymentType == 'avans') {
          totalAvansuri += p.amount;
        } else {
          totalSalarii += p.amount;
        }
      }
    }
    final totalGeneral = totalAvansuri + totalSalarii;
    if (totalGeneral == 0.0) return const SizedBox.shrink();

    return _section(
      title: 'Plăți salariale — $monthLabel',
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.payments_outlined,
              color: Colors.teal, size: 20),
          title: Text('$nrAngajati angajat${nrAngajati == 1 ? '' : 'i'} cu plăți înregistrate'),
          subtitle: Text(
            'Avansuri: ${totalAvansuri.toStringAsFixed(0)} RON'
            '  |  Salarii: ${totalSalarii.toStringAsFixed(0)} RON'
            '\nTotal achitat: ${totalGeneral.toStringAsFixed(0)} RON',
          ),
          isThreeLine: true,
        ),
        if (widget.onNavigateTo != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onNavigateTo!('hr'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Vezi HR'),
            ),
          ),
      ],
    );
  }

  // ── Card raport zilnic ───────────────────────────────────────────────────
  Widget _buildDailyReportCard() {
    final now = DateTime.now();
    return _section(
      title: 'Raport zilnic — ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('Trimite pe WhatsApp'),
                onPressed: () async {
                  final report =
                      await DailyReportService.instance.generateReport();
                  final text =
                      DailyReportService.instance.formatAsText(report);
                  if (!mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Raport zilnic'),
                      content: SingleChildScrollView(
                        child: SelectableText(text,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Inchide')),
                        FilledButton.icon(
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('Trimite WA admin'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            DailyReportService.instance
                                .sendToAdminWhatsApp()
                                .catchError((_) => false);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('Previzualizeaza'),
                onPressed: () async {
                  final report =
                      await DailyReportService.instance.generateReport();
                  if (!mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Raport zilnic'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                            DailyReportService.instance.formatAsText(report),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      actions: [
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Inchide')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Card alertă garanții ─────────────────────────────────────────────────
  Widget _buildWarrantyAlertsCard() {
    final alerts = _warrantyAlerts.all.take(6).toList();
    final String headerTitle;
    if (_warrantyAlerts.expired.isNotEmpty) {
      headerTitle = '⚠ Garanții expirate (${_warrantyAlerts.expired.length})';
    } else if (_warrantyAlerts.urgent.isNotEmpty) {
      headerTitle = '⚠ Garanții care expiră în curând (${_warrantyAlerts.urgent.length})';
    } else {
      headerTitle = 'Garanții — atenție (${_warrantyAlerts.warning.length})';
    }

    return _section(
      title: headerTitle,
      children: alerts.map((alert) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(alert.severityIcon, color: alert.severityColor, size: 20),
          title: Text('${alert.clientDisplay} — ${alert.productDisplay}',
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(alert.expiryLabel,
              style: TextStyle(fontSize: 11, color: alert.severityColor)),
        );
      }).toList(),
    );
  }

  Widget _buildFinancialSection() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Revenue by month (current year, based on closedDate or createdAt of closed jobs)
    final closedJobs = _jobs
        .where((j) =>
            j.status == JobStatus.finalizata &&
            (j.closedDate?.year == currentYear ||
                j.createdAt.year == currentYear))
        .toList();

    // Monthly revenue (estimatedValue as proxy)
    final Map<int, double> monthlyRevenue = {};
    for (final job in closedJobs) {
      final month = job.closedDate?.month ?? job.createdAt.month;
      monthlyRevenue[month] =
          (monthlyRevenue[month] ?? 0) + (job.estimatedValue ?? 0);
    }

    // Top 5 clients by revenue (all closed jobs)
    final allClosedJobs = _jobs.where((j) => j.status == JobStatus.finalizata);
    final Map<String, double> clientRevenue = {};
    for (final job in allClosedJobs) {
      final key = job.clientId.trim().isEmpty ? '(necunoscut)' : job.clientId;
      clientRevenue[key] =
          (clientRevenue[key] ?? 0) + (job.estimatedValue ?? 0);
    }
    final topClients = clientRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalYtd = monthlyRevenue.values.fold(0.0, (s, v) => s + v);
    final monthNames = [
      '',
      'Ian',
      'Feb',
      'Mar',
      'Apr',
      'Mai',
      'Iun',
      'Iul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return _section(
      title: 'Raportare financiară ($currentYear)',
      children: [
        // YTD summary
        Text(
          'Venit estimat YTD (lucrări finalizate): ${totalYtd.toStringAsFixed(2)} RON',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        // Monthly breakdown
        if (monthlyRevenue.isNotEmpty) ...[
          Text(
            'Lunar ($currentYear):',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(currentMonth, (i) {
              final m = i + 1;
              final rev = monthlyRevenue[m] ?? 0;
              return Chip(
                label: Text(
                  '${monthNames[m]}: ${rev.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        rev > 0 ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: rev > 0
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5)
                    : null,
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
        // Top clients
        if (topClients.isNotEmpty) ...[
          Text(
            'Top clienți (venit cumulat):',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          ...topClients.take(5).map((e) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined, size: 18),
              title: Text(e.key),
              trailing: Text(
                '${e.value.toStringAsFixed(2)} RON',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }),
        ],
        if (closedJobs.isEmpty)
          const Text('Nicio lucrare finalizată înregistrată.'),
      ],
    );
  }

  Widget _buildEmployeeSections() {
    final relevant = _myRelevantAppointments.toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final teamName = _teamName(_effectiveTeamId);
    final userLabel = (widget.fieldAuthUserEmail ?? '').trim().isEmpty
        ? '-'
        : widget.fieldAuthUserEmail!.trim();

    return Column(
      children: [
        _section(
          title: 'Programari relevante',
          children: relevant.take(8).map((item) {
            final title = item.title.trim().isEmpty ? 'Programare' : item.title;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: Text(
                '${item.scheduledDate.day.toString().padLeft(2, '0')}.${item.scheduledDate.month.toString().padLeft(2, '0')}.${item.scheduledDate.year} | ${item.startTime} - ${item.endTime}',
              ),
            );
          }).toList(growable: false),
        ),
        _section(
          title: 'Date utilizator',
          children: [
            Text('Utilizator logat: $userLabel'),
            Text('Echipa mea: $teamName'),
            Text('Sursa date: $_dataSourceLabel'),
            if (_dataSourceLabel == 'local' &&
                (_fallbackReason ?? '').trim().isNotEmpty)
              Text('Motiv fallback: ${_fallbackReason!.trim()}'),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyStatsWidget() {
    if (_loading) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.onPrimaryContainer;

    // Colectare statistici cu modulul țintă pentru navigare
    final items = <(String label, String? moduleId)>[];
    final programariAzi = _todayAppointments.length;
    items.add((
      '$programariAzi ${programariAzi == 1 ? 'programare' : 'programări'} azi',
      'programari',
    ));

    if (_isAdminLike) {
      items.add(('${_jobs.where(_isJobActive).length} lucrări active', 'lucrari'));
      final od = _jobs.where(_isJobOverdue).length;
      if (od > 0) items.add(('⚠ $od neactualizate', 'lucrari'));
    } else {
      items.add(('${_todayAppointments.where(_isMine).length} ale mele', 'programari'));
      final tn = _teamName(_effectiveTeamId);
      if (tn != '-') items.add(('Echipa: $tn', null));
    }

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Text(
          ' • ',
          style: TextStyle(
              fontSize: 11, color: baseColor.withValues(alpha: 0.45)),
        ));
      }
      final label = items[i].$1;
      final moduleId = items[i].$2;
      final tappable = moduleId != null && widget.onNavigateTo != null;
      Widget text = Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: tappable ? FontWeight.w600 : FontWeight.w500,
          color: baseColor.withValues(alpha: tappable ? 0.9 : 0.75),
          decoration: tappable ? TextDecoration.underline : null,
          decorationColor: baseColor.withValues(alpha: 0.35),
          decorationStyle: TextDecorationStyle.dotted,
        ),
      );
      if (tappable) {
        text = GestureDetector(
          onTap: () => widget.onNavigateTo!(moduleId),
          child: text,
        );
      }
      children.add(text);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Bună dimineața'
        : hour < 18
            ? 'Bună ziua'
            : 'Bună seara';
    // Afișează numele real dacă e disponibil; fallback la email derivat
    final realName = (widget.fieldAuthUserName ?? '').trim();
    final userLabel = (widget.fieldAuthUserEmail ?? '').trim();
    final userName = realName.isNotEmpty
        ? realName
        : (userLabel.contains('@')
            ? userLabel.split('@').first.replaceAll('.', ' ')
            : userLabel);
    const monthNames = [
      '',
      'ianuarie',
      'februarie',
      'martie',
      'aprilie',
      'mai',
      'iunie',
      'iulie',
      'august',
      'septembrie',
      'octombrie',
      'noiembrie',
      'decembrie',
    ];
    final day = now.day.toString().padLeft(2, '0');
    final dateLabel = '$day ${monthNames[now.month]} ${now.year}';

    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isNotEmpty ? '$greeting, $userName!' : '$greeting!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
                ),
                if (!_loading) ...[
                  const SizedBox(height: 6),
                  _buildDailyStatsWidget(),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                _isAdminLike
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outlined,
                size: 44,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.2),
              ),
              HelpButton(content: AppHelp.dashboard),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return _kpiCard(
      title,
      '...',
      icon: icon,
      subtitle: 'Se încarcă',
      valueColor: scheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _loading
        ? (_isAdminLike
            ? <Widget>[
                _buildLoadingCard('Programări azi', Icons.today),
                _buildLoadingCard('Lucrări active', Icons.work),
                _buildLoadingCard('Oferte active', Icons.request_quote_outlined),
                _buildLoadingCard(
                  'Reclamații deschise',
                  Icons.report_problem_outlined,
                ),
              ]
            : <Widget>[
                _buildLoadingCard('Programări relevante', Icons.today),
                _buildLoadingCard('Date utilizator', Icons.person_outline),
              ])
        : (_isAdminLike ? _buildAdminCards() : _buildEmployeeCards());

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1200
            ? 3
            : width > 760
                ? 2
                : 1;
        final cardWidth = crossAxisCount == 1
            ? width - 32
            : (width - 32 - ((crossAxisCount - 1) * 12)) / crossAxisCount;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 12),
            // ── Widget Taskuri active (vizibil imediat pe Dashboard) ──────────
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            TaskDashboardWidget(
              currentUserId: widget.fieldAuthUserId,
              currentUserName: widget.fieldAuthUserName,
              isAdmin: _isAdminLike,
              onNavigateToTasks: widget.onNavigateTo != null
                  ? () => widget.onNavigateTo!.call('taskuri')
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: cardWidth,
                      child: card,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (!_loading) ...[
              const SizedBox(height: 12),
              _buildSummarySection(),
              const SizedBox(height: 12),
              _isAdminLike ? _buildAdminSections() : _buildEmployeeSections(),
            ],
          ],
        );
      },
    );
  }
}

class _LoadResult<T> {
  const _LoadResult({
    required this.data,
    required this.fromCloud,
    this.errorReason,
  });

  const _LoadResult.cloud(T value)
      : data = value,
        fromCloud = true,
        errorReason = null;

  const _LoadResult.local(T value, {this.errorReason})
      : data = value,
        fromCloud = false;

  final T data;
  final bool fromCloud;
  final String? errorReason;
}
