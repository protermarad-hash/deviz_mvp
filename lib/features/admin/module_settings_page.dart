import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme_preset.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class AppModuleConfig {
  AppModuleConfig({
    required this.moduleId,
    required this.name,
    required this.description,
    required this.icon,
    required this.availableForRoles,
    required this.orderIndex,
    this.isActive = true,
  });

  final String moduleId;
  final String name;
  final String description;
  final IconData icon;
  final List<String> availableForRoles;
  final int orderIndex;
  bool isActive;

  Map<String, dynamic> toMap() => {
        'moduleId': moduleId,
        'isActive': isActive,
      };

  factory AppModuleConfig.fromMap(
    Map<String, dynamic> map,
    AppModuleConfig def,
  ) {
    return AppModuleConfig(
      moduleId: def.moduleId,
      name: def.name,
      description: def.description,
      icon: def.icon,
      availableForRoles: def.availableForRoles,
      orderIndex: def.orderIndex,
      isActive: map['isActive'] as bool? ?? def.isActive,
    );
  }
}

// ── Definiții module ──────────────────────────────────────────────────────────

final List<AppModuleConfig> _kModuleDefaults = [
  AppModuleConfig(
    moduleId: 'oferte',
    name: 'Oferte',
    description: 'Creare și gestionare oferte comerciale cu generare PDF.',
    icon: Icons.request_quote_outlined,
    availableForRoles: ['admin', 'birou'],
    orderIndex: 1,
  ),
  AppModuleConfig(
    moduleId: 'programari',
    name: 'Programări',
    description: 'Planificare și urmărire programări tehnicieni și echipe.',
    icon: Icons.calendar_month_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa', 'tehnician'],
    orderIndex: 2,
  ),
  AppModuleConfig(
    moduleId: 'lucrari',
    name: 'Lucrări',
    description: 'Gestionare lucrări, materiale, devize și rapoarte.',
    icon: Icons.construction_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa', 'tehnician'],
    orderIndex: 3,
  ),
  AppModuleConfig(
    moduleId: 'reclamatii',
    name: 'Reclamații',
    description: 'Înregistrare și urmărire reclamații și intervenții garanție.',
    icon: Icons.report_problem_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa', 'tehnician'],
    orderIndex: 4,
  ),
  AppModuleConfig(
    moduleId: 'catalog_produse',
    name: 'Catalog produse',
    description: 'Produse și servicii, prețuri, categorii.',
    icon: Icons.inventory_2_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa'],
    orderIndex: 5,
  ),
  AppModuleConfig(
    moduleId: 'materiale',
    name: 'Stocuri / Materiale',
    description: 'Gestiunea stocurilor și a materialelor utilizate.',
    icon: Icons.warehouse_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa'],
    orderIndex: 6,
  ),
  AppModuleConfig(
    moduleId: 'agent_teren',
    name: 'Agent teren',
    description: 'Devize rapide generate de agenții de teren.',
    icon: Icons.person_pin_circle_outlined,
    availableForRoles: ['admin', 'birou'],
    orderIndex: 7,
  ),
  AppModuleConfig(
    moduleId: 'hr',
    name: 'HR / Payroll',
    description: 'Pontaj, state salarii, deplasări și administrare HR.',
    icon: Icons.badge_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa'],
    orderIndex: 8,
  ),
  AppModuleConfig(
    moduleId: 'notificari',
    name: 'Notificări',
    description: 'Centru de notificări interne pentru utilizatori.',
    icon: Icons.notifications_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa', 'tehnician'],
    orderIndex: 9,
  ),
  AppModuleConfig(
    moduleId: 'registratura',
    name: 'Registratură',
    description: 'Registrul de intrări-ieșiri documente.',
    icon: Icons.book_outlined,
    availableForRoles: ['admin', 'birou'],
    orderIndex: 10,
  ),
  AppModuleConfig(
    moduleId: 'setari_email',
    name: 'Setări email',
    description: 'Configurare server SMTP pentru trimitere emailuri.',
    icon: Icons.alternate_email_outlined,
    availableForRoles: ['admin'],
    orderIndex: 11,
  ),
  AppModuleConfig(
    moduleId: 'agfr',
    name: 'AGFR / F-Gas',
    description: 'Echipamente, intervenții și rapoarte AGFR.',
    icon: Icons.ac_unit_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa', 'tehnician'],
    orderIndex: 12,
  ),
  AppModuleConfig(
    moduleId: 'ai_assistant',
    name: 'Asistent AI',
    description: 'Asistent inteligent pentru redactare documente și suport.',
    icon: Icons.smart_toy_outlined,
    availableForRoles: ['admin', 'birou', 'sef_echipa'],
    orderIndex: 13,
  ),
];

// ── Repository local ──────────────────────────────────────────────────────────

class _ModuleConfigStore {
  static const _key = 'app_module_configs_v1';

  Future<List<AppModuleConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return List.from(_kModuleDefaults);
    try {
      final list = jsonDecode(raw) as List;
      final saved = {
        for (final item in list.whereType<Map>())
          (item['moduleId'] as String? ?? ''): Map<String, dynamic>.from(item)
      };
      return _kModuleDefaults.map((def) {
        final data = saved[def.moduleId];
        return data != null ? AppModuleConfig.fromMap(data, def) : def;
      }).toList();
    } catch (_) {
      return List.from(_kModuleDefaults);
    }
  }

  Future<void> save(List<AppModuleConfig> modules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(modules.map((m) => m.toMap()).toList()));
  }
}

// ── Pagina ────────────────────────────────────────────────────────────────────

class ModuleSettingsPage extends StatefulWidget {
  const ModuleSettingsPage({super.key});

  @override
  State<ModuleSettingsPage> createState() => _ModuleSettingsPageState();
}

class _ModuleSettingsPageState extends State<ModuleSettingsPage> {
  final _store = _ModuleConfigStore();
  List<AppModuleConfig> _modules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final modules = await _store.load();
    if (!mounted) return;
    setState(() {
      _modules = modules;
      _loading = false;
    });
  }

  Future<void> _toggle(AppModuleConfig module) async {
    setState(() => module.isActive = !module.isActive);
    await _store.save(_modules);
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetare la implicite'),
        content: const Text(
          'Toate modulele vor fi setate ca active. Continui?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resetează'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final fresh = _kModuleDefaults.map((d) {
      d.isActive = true;
      return d;
    }).toList();
    await _store.save(fresh);
    setState(() => _modules = fresh);
  }

  String _rolesLabel(List<String> roles) {
    const labels = {
      'admin': 'Admin',
      'birou': 'Birou',
      'sef_echipa': 'Șef echipă',
      'tehnician': 'Tehnician',
    };
    return roles.map((r) => labels[r] ?? r).join(', ');
  }

  Widget _buildHeroHeader(ColorScheme cs) {
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final activeCount = _modules.where((m) => m.isActive).length;
    final inactiveCount = _modules.length - activeCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brand?.shellHeaderGradient ??
            LinearGradient(
              colors: [cs.primaryContainer, cs.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brand?.shellGlow ?? cs.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onPrimaryContainer.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.extension_outlined,
                        size: 26, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Module aplicație',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Controlează ce module apar în meniu',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatChip(
                    '$activeCount active',
                    Icons.check_circle_outline,
                    cs.surface,
                    cs.primary,
                  ),
                  const SizedBox(width: 8),
                  if (inactiveCount > 0)
                    _buildStatChip(
                      '$inactiveCount inactive',
                      Icons.block_outlined,
                      Colors.orange.shade50,
                      Colors.orange.shade800,
                    )
                  else
                    _buildStatChip(
                      'Toate active',
                      Icons.check_circle_outline,
                      Colors.green.shade50,
                      Colors.green.shade700,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Module'),
        actions: [
          TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: const Text('Resetare implicite'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeroHeader(cs),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: _modules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ModuleCard(
                      module: _modules[i],
                      rolesLabel: _rolesLabel(_modules[i].availableForRoles),
                      onToggle: () => _toggle(_modules[i]),
                      colorScheme: cs,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.rolesLabel,
    required this.onToggle,
    required this.colorScheme,
  });

  final AppModuleConfig module;
  final String rolesLabel;
  final VoidCallback onToggle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final active = module.isActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surface,
        border: Border.all(
          color: active
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: active ? 1.5 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: active ? 3 : 0,
              decoration: BoxDecoration(
                gradient: Theme.of(context).extension<AppBrandTheme>()?.shellAccentGradient ??
                    LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: active
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      module.icon,
                      size: 22,
                      color: active
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: active
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          module.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                rolesLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: active,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
