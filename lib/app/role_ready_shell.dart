import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deviz_theme_controller.dart';
import '../core/app_theme_preset.dart';
import '../core/cloud/firebase_bootstrap.dart';
import '../core/auth/app_role_policy.dart';
import '../core/auth_models.dart';
import '../core/auth_session.dart';
import '../core/company_profile.dart';
import '../core/repositories/app_data_repository.dart';
import '../features/agfr/agfr_page.dart';
import '../features/clients/clients_page.dart';
import '../features/company/company_settings_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/documents/documente_page.dart';
import '../features/lucrari/lucrari_page.dart';
import '../features/employees/employees_master_page.dart';
import '../features/email_settings/email_server_settings_page.dart';
import '../features/field_sales/field_sales_page.dart';
import '../features/materials/materials_master_page.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notification_runtime_service.dart';
import '../features/partners/partners_page.dart';
import '../features/partner_financial/partner_financial_dashboard_page.dart';
import '../features/product_catalog/product_catalog_page.dart';
import '../features/product_catalog/warranty_certificates_page.dart';
import '../features/teams/teams_page.dart';
import '../features/hr_deplasari/hr_deplasari_page.dart';
import '../features/hr_payroll_run/hr_payroll_page.dart';
import '../features/oferte/oferte_page.dart';
import '../features/deviz_tehnic/oferte_devize_modul_page.dart';
import '../features/mentenanta/mentenanta_page.dart';
import '../features/placeholders/placeholder_page.dart';
import '../features/programari/programari_page.dart';
import '../features/programari/programare_kituri_page.dart';
import '../features/reclamatii/reclamatii_list_page.dart';
import '../features/refrigerant_reporting/refrigerant_reporting_page.dart';
import '../features/registratura/registratura_page.dart';
import '../features/ai_assistant/ai_assistant_page.dart';
import '../features/admin/field_photos_migration_page.dart';
import '../features/admin/local_backup_restore_page.dart';
import '../features/admin/module_settings_page.dart';
import '../features/admin/roles_overview_page.dart';
import '../features/admin/template_settings_page.dart';
import '../core/help/help_admin_page.dart';
import '../features/tool_packages/pachete_scule_page.dart';
import '../features/tools/scule_page.dart';
import '../features/tasks/app_task_page.dart';
import '../features/users/local_users_admin_page.dart';
import '../features/vehicles/vehicles_page.dart';
import '../features/hr/employee_financial_page.dart';
import '../features/dashboard/financial_dashboard_page.dart';
import '../features/dashboard/pipeline_dashboard_page.dart';
import '../features/stoc/stoc_page.dart';
import '../features/echipamente/echipamente_page.dart';
import '../features/crm/crm_page.dart';
import '../features/crm/crm_repository.dart';
import '../features/obiective/obiective_page.dart';
import '../features/analiza/analiza_page.dart';

typedef ShellPageBuilder = Widget Function(BuildContext context);

class ShellDestination {
  const ShellDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.allowedRoles,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final Set<UserRole> allowedRoles;
  final ShellPageBuilder builder;
}

class _ShellSectionDef {
  const _ShellSectionDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.itemIds,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> itemIds;
}

const List<_ShellSectionDef> _kShellSections = [
  _ShellSectionDef(
    id: 'taskuri',
    label: 'TASKURI',
    icon: Icons.checklist_outlined,
    itemIds: ['taskuri'],
  ),
  _ShellSectionDef(
    id: 'financiar',
    label: 'FINANCIAR',
    icon: Icons.bar_chart_outlined,
    itemIds: ['dashboard_financiar', 'pipeline_dashboard', 'obiective', 'analiza'],
  ),
  _ShellSectionDef(
    id: 'comercial',
    label: 'COMERCIAL',
    icon: Icons.storefront_outlined,
    itemIds: ['crm', 'oferte', 'clienti', 'parteneri', 'financiar_parteneri', 'agent_teren'],
  ),
  _ShellSectionDef(
    id: 'operational',
    label: 'OPERAȚIONAL',
    icon: Icons.construction_outlined,
    itemIds: [
      'programari',
      'documente',
      'lucrari',
      'mentenanta',
      'scule',
      'pachete_scule',
      'reclamatii',
      'registratura',
      'agfr',
      'refrigerant_reporting',
      'autoturisme',
    ],
  ),
  _ShellSectionDef(
    id: 'catalog',
    label: 'CATALOG',
    icon: Icons.category_outlined,
    itemIds: [
      'catalog_produse',
      'stoc_materiale',
      'echipamente_instalate',
      'taloane_garantie',
      'materiale',
      'retete_kit_programari',
    ],
  ),
  _ShellSectionDef(
    id: 'hr',
    label: 'HR',
    icon: Icons.people_outline,
    itemIds: ['angajati', 'echipe', 'hr', 'hr_deplasari', 'financiar_angajati'],
  ),
  _ShellSectionDef(
    id: 'ai',
    label: 'ASISTENT AI',
    icon: Icons.smart_toy_outlined,
    itemIds: ['ai_assistant'],
  ),
  _ShellSectionDef(
    id: 'administrare',
    label: 'ADMINISTRARE',
    icon: Icons.settings_outlined,
    itemIds: [
      'setari_firma',
      'setari_email',
      'module_settings',
      'sabloane',
      'help_admin',
      'roluri',
      'utilizatori',
      'backup_restore',
      'migrare_poze',
    ],
  ),
];

class RoleReadyAppShell extends StatefulWidget {
  const RoleReadyAppShell({
    super.key,
    required this.appDataRepository,
    this.initialIndex = 0,
    this.fieldAuthRoleKey,
    this.fieldAuthUserLabel,
    this.fieldAuthUserName,
    this.fieldAuthUserId,
    this.fieldAuthTeamId,
  });

  final AppDataRepository appDataRepository;
  final int initialIndex;
  final String? fieldAuthRoleKey;
  /// Email-ul utilizatorului (folosit pentru funcționalitate — emailuri, query-uri)
  final String? fieldAuthUserLabel;
  /// Numele real al utilizatorului din Firestore (afișat în UI)
  final String? fieldAuthUserName;
  final String? fieldAuthUserId;
  final String? fieldAuthTeamId;

  @override
  State<RoleReadyAppShell> createState() => _RoleReadyAppShellState();
}

class _RoleReadyAppShellState extends State<RoleReadyAppShell> {
  static const String _navigationOrderKey = 'shell_navigation_order_v1';
  static const String _sectionsExpandedKey = 'shell_sections_expanded_v1';
  final NotificationRuntimeService _notificationRuntime =
      NotificationRuntimeService.instance;
  late int _selectedIndex;
  bool _isOnline = true;
  final ScrollController _navigationScrollController = ScrollController();
  List<String>? _savedNavigationOrder;
  // Cache pagini pentru a evita re-initState / re-load la schimbarea tabului
  final Map<String, Widget> _pageCache = {};
  final Set<String> _visitedPageIds = {};
  final Map<String, bool> _expandedSections = {
    'taskuri': true,
    'financiar': true,
    'comercial': true,
    'operational': true,
    'catalog': true,
    'hr': true,
    'ai': true,
    'administrare': true,
  };
  final Map<String, int> _sectionBadges = {};
  static const Duration _sectionBadgesCooldown = Duration(seconds: 30);
  Future<void>? _sectionBadgesLoadFuture;
  DateTime? _lastSectionBadgesLoadedAt;
  DateTime? _lastBackPress;
  String _appVersionLabel = '';

  List<ShellDestination> _allDestinations() {
    final allRoles = UserRole.values.toSet();

    return [
      ShellDestination(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        allowedRoles: allRoles,
        builder: (_) => DashboardPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserEmail: widget.fieldAuthUserLabel,
          fieldAuthUserName: widget.fieldAuthUserName,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthTeamId: widget.fieldAuthTeamId,
          onNavigateTo: _navigateToModuleId,
        ),
      ),
      ShellDestination(
        id: 'taskuri',
        label: 'Taskuri',
        icon: Icons.checklist_outlined,
        allowedRoles: allRoles,
        builder: (_) => AppTaskPage(
          currentUserId: widget.fieldAuthUserId,
          currentUserName: widget.fieldAuthUserName,
          isAdmin: widget.fieldAuthRoleKey == 'admin' ||
              widget.fieldAuthRoleKey == null ||
              widget.fieldAuthRoleKey!.isEmpty,
        ),
      ),
      ShellDestination(
        id: 'notificari',
        label: 'Notificari',
        icon: Icons.notifications_none_outlined,
        allowedRoles: allRoles,
        builder: (_) => NotificationCenterPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserEmail: widget.fieldAuthUserLabel,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'agent_teren',
        label: 'Agent teren',
        icon: Icons.point_of_sale_outlined,
        allowedRoles: allRoles,
        builder: (_) => FieldSalesPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserEmail: widget.fieldAuthUserLabel,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'programari',
        label: 'Programari',
        icon: Icons.event_note_outlined,
        allowedRoles: allRoles,
        builder: (_) => ProgramariPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserEmail: widget.fieldAuthUserLabel,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'documente',
        label: 'Documente',
        icon: Icons.folder_copy_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => DocumentePage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'agfr',
        label: 'AGFR / F-GAS',
        icon: Icons.ac_unit_outlined,
        allowedRoles: allRoles,
        builder: (_) => AgfrPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'refrigerant_reporting',
        label: 'Raportari refrigeranti',
        icon: Icons.assignment_turned_in_outlined,
        allowedRoles: allRoles,
        builder: (_) => RefrigerantReportingPage(
          repository: widget.appDataRepository,
        ),
      ),
      ShellDestination(
        id: 'lucrari',
        label: 'Lucrari',
        icon: Icons.assignment_outlined,
        allowedRoles: allRoles,
        builder: (_) => LucrariPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthUserLabel: widget.fieldAuthUserLabel,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'oferte',
        label: 'Oferte',
        icon: Icons.request_quote_outlined,
        allowedRoles: allRoles,
        builder: (_) => OferteDevizeModulPage(
          repository: widget.appDataRepository,
          currentUserId: widget.fieldAuthUserId,
          currentUserEmail: widget.fieldAuthUserLabel,
          currentUserName: widget.fieldAuthUserLabel,
        ),
      ),
      ShellDestination(
        id: 'reclamatii',
        label: 'Reclamatii',
        icon: Icons.support_agent_outlined,
        allowedRoles: {
          UserRole.admin,
          UserRole.birou,
          UserRole.sefEchipa,
          UserRole.tehnician,
        },
        builder: (_) => ReclamatiiListPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthUserLabel: widget.fieldAuthUserLabel,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'registratura',
        label: 'Registratura',
        icon: Icons.library_books_outlined,
        allowedRoles: allRoles,
        builder: (_) => RegistraturaPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'clienti',
        label: 'Clienți',
        icon: Icons.business_outlined,
        allowedRoles: allRoles,
        builder: (_) => ClientsPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'parteneri',
        label: 'Parteneri',
        icon: Icons.handshake_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => PartnersPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'financiar_parteneri',
        label: 'Financiar parteneri',
        icon: Icons.account_balance_wallet_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => PartnerFinancialDashboardPage(
              appRepository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'catalog_produse',
        label: 'Catalog produse',
        icon: Icons.inventory_2_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) =>
            ProductCatalogPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'stoc_materiale',
        label: 'Stoc materiale',
        icon: Icons.warehouse_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const StocPage(),
      ),
      ShellDestination(
        id: 'echipamente_instalate',
        label: 'Echipamente instalate',
        icon: Icons.hvac_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const EchipamentePage(),
      ),
      ShellDestination(
        id: 'taloane_garantie',
        label: 'Taloane garantie',
        icon: Icons.verified_user_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) =>
            WarrantyCertificatesPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'materiale',
        builder: (_) => const MaterialsMasterPage(),
        label: 'Materiale',
        icon: Icons.inventory_2_outlined,
        allowedRoles: allRoles,
      ),
      ShellDestination(
        id: 'retete_kit_programari',
        builder: (_) =>
            ProgramareKituriPage(repository: widget.appDataRepository),
        label: 'Retete kit programari',
        icon: Icons.playlist_add_check_circle_outlined,
        allowedRoles: {UserRole.admin},
      ),
      ShellDestination(
        id: 'angajati',
        builder: (_) => const EmployeesMasterPage(),
        label: 'Angajați',
        icon: Icons.badge_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
      ),
      ShellDestination(
        id: 'echipe',
        builder: (_) => const TeamsPage(),
        label: 'Echipe',
        icon: Icons.diversity_3_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
      ),
      ShellDestination(
        id: 'autoturisme',
        label: 'Autoturisme',
        icon: Icons.directions_car_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => const VehiclesPage(),
      ),
      ShellDestination(
        id: 'scule',
        label: 'Scule',
        icon: Icons.handyman_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => SculePage(
          repository: widget.appDataRepository,
          currentUserId: widget.fieldAuthUserId,
          currentUserEmail: widget.fieldAuthUserLabel,
        ),
      ),
      ShellDestination(
        id: 'pachete_scule',
        label: 'Pachete scule',
        icon: Icons.workspaces_outline,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => const PacheteSculePage(),
      ),
      ShellDestination(
        id: 'hr_deplasari',
        label: 'HR / Deplasări',
        icon: Icons.travel_explore_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => HrDeplasariPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => HrPayrollPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
        ),
      ),
      ShellDestination(
        id: 'financiar_angajati',
        label: 'Financiar angajați',
        icon: Icons.account_balance_wallet_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => EmployeeFinancialPage(
          repository: widget.appDataRepository,
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserEmail: widget.fieldAuthUserLabel,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
      ShellDestination(
        id: 'dashboard_financiar',
        label: 'Dashboard Financiar',
        icon: Icons.bar_chart_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const FinancialDashboardPage(),
      ),
      ShellDestination(
        id: 'pipeline_dashboard',
        label: 'Pipeline Vânzări',
        icon: Icons.account_tree_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const PipelineDashboardPage(),
      ),
      ShellDestination(
        id: 'obiective',
        label: 'Obiective lunare',
        icon: Icons.flag_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const ObiectivePage(),
      ),
      ShellDestination(
        id: 'analiza',
        label: 'Analiza profitabilitate',
        icon: Icons.analytics_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => const AnalizaPage(),
      ),
      ShellDestination(
        id: 'mentenanta',
        label: 'Service & Mentenanță',
        icon: Icons.handyman,
        allowedRoles: {UserRole.admin},
        builder: (_) => MentenantaPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'crm',
        label: 'CRM Vanzari',
        icon: Icons.people_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => CrmPage(repository: widget.appDataRepository),
      ),
      ShellDestination(
        id: 'setari_firma',
        label: 'Setări firmă',
        icon: Icons.apartment_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou},
        builder: (_) => CompanySettingsPage(
          repository: widget.appDataRepository,
        ),
      ),
      ShellDestination(
        id: 'setari_email',
        label: 'Setări email',
        icon: Icons.alternate_email_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const EmailServerSettingsPage(),
      ),
      ShellDestination(
        id: 'module_settings',
        label: 'Module',
        icon: Icons.extension_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const ModuleSettingsPage(),
      ),
      ShellDestination(
        id: 'sabloane',
        label: 'Șabloane documente',
        icon: Icons.description_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const TemplateSettingsPage(),
      ),
      ShellDestination(
        id: 'help_admin',
        label: 'Conținut Help',
        icon: Icons.help_center_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const HelpAdminPage(),
      ),
      ShellDestination(
        id: 'ai_assistant',
        label: 'Asistent AI',
        icon: Icons.smart_toy_outlined,
        allowedRoles: {UserRole.admin, UserRole.birou, UserRole.sefEchipa},
        builder: (_) => const AiAssistantPage(),
      ),
      ShellDestination(
        id: 'roluri',
        label: 'Roluri utilizatori',
        icon: Icons.manage_accounts_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const RolesOverviewPage(),
      ),
      ShellDestination(
        id: 'backup_restore',
        label: 'Backup / Restaurare',
        icon: Icons.backup_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const LocalBackupRestorePage(),
      ),
      ShellDestination(
        id: 'utilizatori',
        label: 'Utilizatori',
        icon: Icons.manage_accounts_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const LocalUsersAdminPage(),
      ),
      ShellDestination(
        id: 'migrare_poze',
        label: 'Migrare poze vechi',
        icon: Icons.photo_library_outlined,
        allowedRoles: {UserRole.admin},
        builder: (_) => const FieldPhotosMigrationPage(),
      ),
    ];
  }

  void _onOnlineStatusChanged() {
    if (!mounted) return;
    setState(() => _isOnline = FirebaseBootstrap.onlineNotifier.value);
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _isOnline = FirebaseBootstrap.isOnline;
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineStatusChanged);
    _initShell();
    Future.microtask(_loadAppVersion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configureNotificationRuntime();
      _scheduleSectionBadgesLoad();
    });
  }

  // Versiune aplicație — afișată discret în Drawer sub numele companiei,
  // ca utilizatorul să poată identifica exact ce build are instalat.
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'v${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // best-effort — fără versiune afișată dacă citirea eșuează
    }
  }

  // Un singur SharedPreferences.getInstance() + totul în paralel
  Future<void> _initShell() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await Future.wait([
      _loadNavigationOrderFromPrefs(prefs),
      _loadSectionsExpandedFromPrefs(prefs),
    ]);
  }

  @override
  void didUpdateWidget(covariant RoleReadyAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldAuthUserId != widget.fieldAuthUserId ||
        oldWidget.fieldAuthUserLabel != widget.fieldAuthUserLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _configureNotificationRuntime();
      });
      _scheduleSectionBadgesLoad(force: true);
    }
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineStatusChanged);
    _navigationScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNavigationOrderFromPrefs(SharedPreferences prefs) async {
    final saved = prefs.getStringList(_navigationOrderKey);
    if (!mounted) return;
    setState(() {
      _savedNavigationOrder = saved;
    });
  }

  Future<void> _loadSectionsExpandedFromPrefs(SharedPreferences prefs) async {
    final collapsed = prefs.getStringList(_sectionsExpandedKey);
    if (!mounted) return;

    // Dacă există un index inițial nenul (deep-link), găsim secțiunea și o forțăm expanded
    final forceExpand = <String>{};
    if (widget.initialIndex > 0) {
      final allDests = _allDestinations();
      if (widget.initialIndex < allDests.length) {
        final destId = allDests[widget.initialIndex].id;
        for (final section in _kShellSections) {
          if (section.itemIds.contains(destId)) {
            forceExpand.add(section.id);
            break;
          }
        }
      }
    }

    setState(() {
      if (collapsed != null) {
        for (final id in collapsed) {
          _expandedSections[id] = false;
        }
      }
      for (final id in forceExpand) {
        _expandedSections[id] = true;
      }
    });
  }

  Future<void> _saveSectionsExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    final collapsed = _expandedSections.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList(growable: false);
    await prefs.setStringList(_sectionsExpandedKey, collapsed);
  }

  Future<void> _loadSectionBadges() async {
    final now = DateTime.now();
    final lastLoadedAt = _lastSectionBadgesLoadedAt;
    if (_sectionBadgesLoadFuture != null) {
      debugPrint('[Shell] badges reload skipped: already loading');
      return;
    }
    if (lastLoadedAt != null &&
        now.difference(lastLoadedAt) < _sectionBadgesCooldown) {
      debugPrint('[Shell] badges reload skipped: cooldown active');
      return;
    }
    final future = _loadSectionBadgesInternal();
    _sectionBadgesLoadFuture = future;
    try {
      await future;
      _lastSectionBadgesLoadedAt = DateTime.now();
    } finally {
      if (identical(_sectionBadgesLoadFuture, future)) {
        _sectionBadgesLoadFuture = null;
      }
    }
  }

  Future<void> _loadSectionBadgesInternal() async {
    try {
      final jobs = await widget.appDataRepository.listJobs();
      final now = DateTime.now();
      final overdueCount = jobs.where((j) {
        if (!j.isActive) return false;
        final s = j.status.value
            .trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_');
        if (s == 'inchisa') return false;
        return now.difference(j.updatedAt).inDays >= 14;
      }).length;
      if (mounted) {
        setState(() {
          _sectionBadges['operational'] = overdueCount;
        });
      }
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
    }

    // Badge CRM: leaduri cu actiuni depășite
    try {
      final crmPending =
          await CrmRepository.instance.listNecesitaActiune();
      if (mounted && crmPending.isNotEmpty) {
        setState(() {
          _sectionBadges['comercial'] = crmPending.length;
        });
        // Alertă locală o singură dată per sesiune (folosim un flag de sesiune)
        _showCrmAlertIfNeeded(crmPending.length);
      }
    } catch (e) {
      debugPrint('[RoleReadyShell] încărcare badge-uri CRM eșuată: $e');
    }
  }

  static bool _crmAlertShownThisSession = false;

  void _showCrmAlertIfNeeded(int count) {
    if (_crmAlertShownThisSession) return;
    _crmAlertShownThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '\u{1F4CB} $count lead-uri necesita actiune in CRM'),
          action: SnackBarAction(
            label: 'Deschide CRM',
            onPressed: () => _navigateToModuleId('crm'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  void _scheduleSectionBadgesLoad({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (force) {
        _lastSectionBadgesLoadedAt = null;
      }
      _loadSectionBadges();
    });
  }

  // Extinde secțiunea care conține destinația dată (fără setState propriu — apelat din setState al apelantului sau separat)
  void _autoExpandSectionFor(String destinationId) {
    for (final section in _kShellSections) {
      if (section.itemIds.contains(destinationId)) {
        if (!(_expandedSections[section.id] ?? true)) {
          setState(() => _expandedSections[section.id] = true);
          _saveSectionsExpanded();
        }
        return;
      }
    }
  }

  // Navighează la un modul după ID, expandând secțiunea dacă e colapsată
  void _navigateToModuleId(String destinationId) {
    if (!mounted) return;
    final session = AppSessionScope.of(context);
    final role = session.currentUser?.role ?? UserRole.admin;
    final fieldRoleKey = widget.fieldAuthRoleKey;
    final all = _applySavedOrder(_allDestinations());
    final destinations = fieldRoleKey == null || fieldRoleKey.isEmpty
        ? all.where((d) => d.allowedRoles.contains(role)).toList()
        : all
            .where((d) => _fieldRoleAllowsDestination(fieldRoleKey, d.id))
            .toList();
    final index = destinations.indexWhere((d) => d.id == destinationId);
    if (index < 0) return;
    setState(() {
      _selectedIndex = index;
      for (final section in _kShellSections) {
        if (section.itemIds.contains(destinationId)) {
          _expandedSections[section.id] = true;
          break;
        }
      }
    });
    _saveSectionsExpanded();
  }

  // Mapare din modulul notificării → ID-ul destinației în shell
  String _moduleToDestId(String module) {
    switch (module) {
      case 'tools':
        return 'scule';
      case 'lucrari':
      case 'jobs':
        return 'lucrari';
      case 'field_sales':
        return 'agent_teren';
      case 'product_catalog':
        return 'catalog_produse';
      default:
        return module; // 'programari', 'reclamatii', 'oferte' — același ID
    }
  }

  Future<void> _configureNotificationRuntime() async {
    await _notificationRuntime.initialize(
      userId: (widget.fieldAuthUserId ?? '').trim(),
      userEmail: (widget.fieldAuthUserLabel ?? '').trim(),
      onTap: _handleNotificationTap,
    );
    // Firebase tocmai s-a inițializat / reconectat — reîncarcă badge-urile cu date cloud
    _scheduleSectionBadgesLoad(force: true);
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> payload) async {
    if (!mounted) return;
    final module = (payload['source_module'] ??
            payload['sourceModule'] ??
            payload['module'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    // Auto-expandează secțiunea care conține modulul notificării
    if (module.isNotEmpty) {
      _autoExpandSectionFor(_moduleToDestId(module));
    }
    final sourceEntityId = (payload['source_entity_id'] ??
            payload['sourceEntityId'] ??
            payload['entity_id'] ??
            '')
        .toString()
        .trim();
    Widget page = NotificationCenterPage(
      repository: widget.appDataRepository,
      fieldAuthRoleKey: widget.fieldAuthRoleKey,
      fieldAuthUserEmail: widget.fieldAuthUserLabel,
      fieldAuthUserId: widget.fieldAuthUserId,
      fieldAuthTeamId: widget.fieldAuthTeamId,
    );
    if (module == 'programari') {
      page = ProgramariPage(
        repository: widget.appDataRepository,
        fieldAuthRoleKey: widget.fieldAuthRoleKey,
        fieldAuthUserEmail: widget.fieldAuthUserLabel,
        fieldAuthUserId: widget.fieldAuthUserId,
        fieldAuthTeamId: widget.fieldAuthTeamId,
        initialFocusAppointmentId: sourceEntityId,
      );
    } else if (module == 'reclamatii') {
      page = ReclamatiiListPage(
        repository: widget.appDataRepository,
        fieldAuthRoleKey: widget.fieldAuthRoleKey,
        fieldAuthUserId: widget.fieldAuthUserId,
        fieldAuthUserLabel: widget.fieldAuthUserLabel,
        fieldAuthTeamId: widget.fieldAuthTeamId,
        initialFocusComplaintId: sourceEntityId,
      );
    } else if (module == 'tools') {
      page = SculePage(
        repository: widget.appDataRepository,
        currentUserId: widget.fieldAuthUserId,
        currentUserEmail: widget.fieldAuthUserLabel,
      );
    } else if (module == 'lucrari' || module == 'jobs') {
      page = LucrariPage(
        repository: widget.appDataRepository,
        fieldAuthRoleKey: widget.fieldAuthRoleKey,
        fieldAuthUserId: widget.fieldAuthUserId,
        fieldAuthUserLabel: widget.fieldAuthUserLabel,
        fieldAuthTeamId: widget.fieldAuthTeamId,
      );
    } else if (module == 'field_sales') {
      page = FieldSalesPage(
        repository: widget.appDataRepository,
        fieldAuthRoleKey: widget.fieldAuthRoleKey,
        fieldAuthUserEmail: widget.fieldAuthUserLabel,
        fieldAuthUserId: widget.fieldAuthUserId,
        fieldAuthTeamId: widget.fieldAuthTeamId,
      );
    } else if (module == 'oferte') {
      page = OfertePage(
        repository: widget.appDataRepository,
        currentUserId: widget.fieldAuthUserId,
        currentUserEmail: widget.fieldAuthUserLabel,
        initialFocusOfferId: sourceEntityId,
      );
    } else if (module == 'product_catalog') {
      page = ProductCatalogPage(repository: widget.appDataRepository);
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  List<ShellDestination> _applySavedOrder(List<ShellDestination> source) {
    final saved = _savedNavigationOrder;
    if (saved == null || saved.isEmpty) {
      return source;
    }
    final byId = <String, ShellDestination>{
      for (final item in source) item.id: item,
    };
    final ordered = <ShellDestination>[];
    for (final id in saved) {
      final match = byId.remove(id);
      if (match != null) {
        ordered.add(match);
      }
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  Future<void> _saveNavigationOrder(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_navigationOrderKey, ids);
    if (!mounted) return;
    setState(() {
      _savedNavigationOrder = ids;
      _selectedIndex = 0;
    });
  }

  Future<void> _resetNavigationOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_navigationOrderKey);
    if (!mounted) return;
    setState(() {
      _savedNavigationOrder = null;
      _selectedIndex = 0;
    });
  }

  Future<void> _openNavigationOrderDialog(
    List<ShellDestination> visibleDestinations,
  ) async {
    var working = visibleDestinations.toList(growable: true);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ordine taburi'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mută modulele în ordinea dorită. Ordinea se salvează local pentru shell-ul principal.',
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: working.length,
                    itemBuilder: (context, index) {
                      final item = working[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Mută sus',
                              onPressed: index == 0
                                  ? null
                                  : () => setDialogState(() {
                                        final current = working.removeAt(index);
                                        working.insert(index - 1, current);
                                      }),
                              icon: const Icon(Icons.arrow_upward_outlined),
                            ),
                            IconButton(
                              tooltip: 'Mută jos',
                              onPressed: index == working.length - 1
                                  ? null
                                  : () => setDialogState(() {
                                        final current = working.removeAt(index);
                                        working.insert(index + 1, current);
                                      }),
                              icon: const Icon(Icons.arrow_downward_outlined),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _resetNavigationOrder();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Resetează'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Închide'),
            ),
            FilledButton(
              onPressed: () async {
                await _saveNavigationOrder(
                  working.map((item) => item.id).toList(growable: false),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final role = session.currentUser?.role ?? UserRole.admin;
    final fieldRoleKey = widget.fieldAuthRoleKey;
    final all = _applySavedOrder(_allDestinations());
    final destinations = fieldRoleKey == null || fieldRoleKey.isEmpty
        ? all.where((item) => item.allowedRoles.contains(role)).toList()
        : all
            .where((item) => _fieldRoleAllowsDestination(fieldRoleKey, item.id))
            .toList();

    if (destinations.isEmpty) {
      return const Scaffold(
        body: PlaceholderFeaturePage(
          title: 'Acces indisponibil',
          description: 'Nu există module disponibile pentru rolul curent.',
        ),
      );
    }

    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }

    final current = destinations[_selectedIndex];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1400
        ? 300.0
        : screenWidth >= 960
            ? 272.0
            : screenWidth < 480
                ? 208.0
                : 236.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        final last = _lastBackPress;
        if (last == null || now.difference(last) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apasă din nou pentru a ieși din aplicație'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        drawer: Drawer(
          width: drawerWidth,
          child: SafeArea(
            child: _buildNavigationList(
            destinations,
            compact: screenWidth < 480,
            showLabels: true,
            closeOnSelect: true,
          ),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: brand == null
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(gradient: brand.shellHeaderGradient),
              ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Meniu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(current.label),
        actions: [
          if ((widget.fieldAuthUserLabel ?? '').isNotEmpty ||
              (widget.fieldAuthUserName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  // Afișează numele real dacă e disponibil, altfel email-ul
                  '${widget.fieldAuthUserName?.isNotEmpty == true ? widget.fieldAuthUserName : widget.fieldAuthUserLabel} | ${_fieldRoleLabel(widget.fieldAuthRoleKey)}',
                ),
              ),
            ),
          if ((widget.fieldAuthUserLabel ?? '').isEmpty &&
              session.currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${session.currentUser!.displayName} • ${session.currentUser!.role.label}',
                ),
              ),
            ),
          IconButton(
            onPressed: () => _openNavigationOrderDialog(destinations),
            tooltip: 'Ordine taburi',
            icon: const Icon(Icons.reorder_outlined),
          ),
          IconButton(
            onPressed: () => session.signOut(),
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Builder(builder: (ctx) {
        _visitedPageIds.add(current.id);
        final stack = IndexedStack(
          index: _selectedIndex,
          children: destinations.map((dest) {
            if (!_visitedPageIds.contains(dest.id)) {
              return const SizedBox.shrink();
            }
            return _pageCache.putIfAbsent(dest.id, () => dest.builder(ctx));
          }).toList(),
        );
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isOnline
                  ? const SizedBox.shrink()
                  : _OfflineBanner(),
            ),
            Expanded(child: stack),
          ],
        );
      }),
      ),
    );
  }

  Uint8List? _tryDecodeLogo(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    try {
      return Uint8List.fromList(UriData.parse(value).contentAsBytes());
    } catch (_) {
      try {
        return Uint8List.fromList(base64Decode(value));
      } catch (_) {
        return null;
      }
    }
  }

  String _initialsForCompany(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'MD';
    }
    return parts.map((item) => item.characters.first.toUpperCase()).join();
  }

  Widget _buildNavigationHeader(
    BuildContext context,
    CompanyProfile profile, {
    required bool compact,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final preset =
        DevizThemeScope.maybeOf(context)?.preset ?? AppThemePreset.atelier;
    final companyName = profile.companyName.trim().isEmpty
        ? 'ProVentaris'
        : profile.companyName.trim();
    final logoBytes = _tryDecodeLogo(profile.logoBase64);
    final isProTerm = preset == AppThemePreset.proTerm;

    return Container(
      margin: EdgeInsets.fromLTRB(
          compact ? 4 : 6, compact ? 4 : 6, compact ? 4 : 6, 12),
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        gradient: brand?.shellHeaderGradient,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: brand?.shellLineColor ?? scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: brand?.shellGlow ?? scheme.primary.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -8,
            child: Container(
              width: compact ? 58 : 74,
              height: compact ? 58 : 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: brand?.shellAccentGradient,
              ),
            ),
          ),
          Positioned(
            bottom: -22,
            right: compact ? 18 : 28,
            child: Container(
              width: compact ? 70 : 96,
              height: compact ? 70 : 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface.withValues(alpha: 0.35),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 48 : 58,
                    height: compact ? 48 : 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: logoBytes == null
                        ? Text(
                            _initialsForCompany(companyName),
                            style: TextStyle(
                              fontSize: compact ? 16 : 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(logoBytes, fit: BoxFit.contain),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isProTerm
                              ? 'Excelenta operationala in HVAC'
                              : 'Controleaza intregul flux HVAC, intr-o platforma premium.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                        if (_appVersionLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _appVersionLabel,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: compact ? 9 : 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.72),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined,
                        color: scheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preset.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _fieldRoleAllowsDestination(String roleKey, String destinationId) {
    return AppRolePolicy.fieldShellAllowsDestination(
      destinationId,
      roleKey: roleKey,
    );
  }

  String _fieldRoleLabel(String? roleKey) {
    switch (roleKey) {
      case 'admin':
        return 'Admin';
      case 'office':
        return 'Office';
      case 'teamLead':
        return 'Șef echipă';
      case 'employee':
        return 'Angajat';
      default:
        return 'Utilizator';
    }
  }

  Widget _buildNavigationList(
    List<ShellDestination> destinations, {
    required bool compact,
    required bool showLabels,
    required bool closeOnSelect,
  }) {
    final profile =
        DevizThemeScope.maybeOf(context)?.profile ?? const CompanyProfile();
    final scheme = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final destinationById = {for (final d in destinations) d.id: d};
    // Pre-calculează indexul O(1) per item — evită destinations.indexOf()
    // care era O(n) per item => O(n²) total la fiecare rebuild al meniului.
    final indexById = {
      for (int i = 0; i < destinations.length; i++) destinations[i].id: i,
    };

    Widget buildDestItem(ShellDestination item) {
      final flatIndex = indexById[item.id] ?? -1;
      final selected = flatIndex == _selectedIndex;
      // Gradientul se construiește DOAR pentru itemul selectat — înainte se
      // crea un LinearGradient + listă de culori pentru fiecare item, la
      // fiecare build, chiar dacă nu era selectat.
      final selectedGradient = (selected && brand != null)
          ? LinearGradient(
              colors: brand.shellAccentGradient.colors
                  .map((c) => c.withValues(alpha: compact ? 0.12 : 0.16))
                  .toList(growable: false),
            )
          : null;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
        child: Tooltip(
          message: item.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected ? selectedGradient : null,
              border: Border.all(
                color: selected
                    ? (brand?.shellLineColor ?? scheme.primary)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              dense: compact,
              visualDensity: compact ? VisualDensity.compact : null,
              tileColor: selected
                  ? scheme.secondaryContainer.withValues(alpha: 0.46)
                  : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: showLabels ? (compact ? 10 : 12) : 6,
                vertical: compact ? 0 : 2,
              ),
              minLeadingWidth: showLabels ? (compact ? 20 : null) : 0,
              selected: selected,
              leading: Icon(
                item.icon,
                size: compact ? 20 : 24,
                color: selected ? scheme.primary : null,
              ),
              title: showLabels
                  ? Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    )
                  : null,
              trailing: selected && showLabels
                  ? Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: scheme.primary,
                    )
                  : null,
              horizontalTitleGap: showLabels ? null : 0,
              minTileHeight: showLabels ? null : 44,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () {
                setState(() => _selectedIndex = flatIndex);
                if (closeOnSelect) Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
      );
    }

    Widget buildSection(_ShellSectionDef sectionDef) {
      final sectionItems = sectionDef.itemIds
          .where(destinationById.containsKey)
          .map((id) => destinationById[id]!)
          .toList(growable: false);
      if (sectionItems.isEmpty) return const SizedBox.shrink();

      final isExpanded = _expandedSections[sectionDef.id] ?? true;
      final hasSectionSelected = sectionItems
          .any((item) => (indexById[item.id] ?? -1) == _selectedIndex);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() => _expandedSections[sectionDef.id] = !isExpanded);
              _saveSectionsExpanded();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 5,
              ),
              child: Row(
                children: [
                  Icon(
                    sectionDef.icon,
                    size: 13,
                    color: hasSectionSelected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sectionDef.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: hasSectionSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if ((_sectionBadges[sectionDef.id] ?? 0) > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_sectionBadges[sectionDef.id]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...sectionItems.map(buildDestItem),
          const SizedBox(height: 2),
        ],
      );
    }

    final allSectionedIds =
        _kShellSections.expand((s) => s.itemIds).toSet();
    final standaloneItems = destinations
        .where((d) => !allSectionedIds.contains(d.id))
        .toList(growable: false);

    final listChildren = <Widget>[
      ...standaloneItems.map(buildDestItem),
      if (standaloneItems.isNotEmpty)
        Divider(
          height: 16,
          thickness: 0.5,
          color: scheme.outlineVariant,
          indent: compact ? 8 : 10,
          endIndent: compact ? 8 : 10,
        ),
      for (final sectionDef in _kShellSections)
        if (sectionDef.itemIds.any(destinationById.containsKey))
          buildSection(sectionDef),
    ];

    return Column(
      children: [
        _buildNavigationHeader(context, profile, compact: compact),
        Expanded(
          // RepaintBoundary izolează repaint-ul listei de restul shell-ului
          // (lista se reconstruiește la fiecare setState din shell).
          child: RepaintBoundary(
            child: Scrollbar(
              controller: _navigationScrollController,
              thumbVisibility: !compact,
              // ScrollConfiguration: scroll fluid pe Windows (touch + mouse +
              // trackpad) și pe Android. Scrollbar-ul îl gestionăm noi mai sus,
              // deci dezactivăm scrollbar-ul implicit.
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const ClampingScrollPhysics(),
                  scrollbars: false,
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView(
                  controller: _navigationScrollController,
                  primary: false,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 0 : 8,
                  ),
                  children: listChildren,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Mod offline — datele se vor sincroniza când revine conexiunea',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
