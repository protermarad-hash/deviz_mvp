import 'package:flutter/material.dart';

import '../../core/app_theme_preset.dart';
import '../users/local_users_admin_page.dart';

class RolesOverviewPage extends StatelessWidget {
  const RolesOverviewPage({super.key});

  Widget _buildHeroHeader(BuildContext context, ColorScheme cs) {
    final brand = Theme.of(context).extension<AppBrandTheme>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brand?.shellHeaderGradient ??
            LinearGradient(
              colors: [cs.tertiaryContainer, cs.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brand?.shellGlow ?? cs.tertiary.withValues(alpha: 0.12),
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
                color: cs.onTertiaryContainer.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface.withValues(alpha: 0.15),
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
                      color: cs.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.manage_accounts_outlined,
                        size: 26, color: cs.tertiary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roluri utilizatori',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: cs.onTertiaryContainer,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Permisiuni și module accesibile per rol',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onTertiaryContainer.withValues(alpha: 0.7),
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
                    '${_kRoles.length} roluri',
                    Icons.badge_outlined,
                    cs.surface,
                    cs.tertiary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Read-only',
                    Icons.lock_outline,
                    cs.surface,
                    cs.primary,
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
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Roluri utilizatori')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroHeader(context, cs),
          ..._kRoles.map((role) => _RoleCard(role: role, colorScheme: cs)),
          const SizedBox(height: 16),
          // ── Card acțiune admin ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.manage_accounts, size: 22, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editează rolurile utilizatorilor',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Atribuie sau modifică rolul fiecărui utilizator.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LocalUsersAdminPage(),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Utilizatori'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Notă',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Această pagină arată ce poate face fiecare rol (read-only). '
                    'Pentru a schimba rolul unui utilizator, apasă butonul "Utilizatori" de mai sus.',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Definiții roluri ──────────────────────────────────────────────────────────

class _RoleDef {
  const _RoleDef({
    required this.name,
    required this.key,
    required this.icon,
    required this.color,
    required this.description,
    required this.modules,
    required this.restrictions,
  });

  final String name;
  final String key;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> modules;
  final List<String> restrictions;
}

const List<_RoleDef> _kRoles = [
  _RoleDef(
    name: 'Admin',
    key: 'admin',
    icon: Icons.admin_panel_settings_outlined,
    color: Color(0xFFB71C1C),
    description: 'Acces complet la toate modulele și funcționalitățile aplicației.',
    modules: [
      'Panou de control',
      'Oferte',
      'Clienți',
      'Parteneri',
      'Agent teren',
      'Programări',
      'Lucrări',
      'Scule / Pachete scule',
      'Reclamații',
      'Registratură',
      'AGFR / F-Gas',
      'Catalog produse',
      'Materiale',
      'Angajați',
      'Echipe',
      'HR / Payroll',
      'Deplasări',
      'Notificări',
      'Setări firmă',
      'Setări email',
      'Module',
      'Șabloane documente',
      'Utilizatori',
      'Backup / Restaurare',
    ],
    restrictions: [],
  ),
  _RoleDef(
    name: 'Birou',
    key: 'office',
    icon: Icons.business_center_outlined,
    color: Color(0xFF1565C0),
    description: 'Acces larg la operațiuni comerciale și administrative, '
        'fără administrare utilizatori și backup.',
    modules: [
      'Panou de control',
      'Oferte',
      'Clienți',
      'Parteneri',
      'Agent teren',
      'Programări',
      'Lucrări',
      'Scule / Pachete scule',
      'Reclamații',
      'Registratură',
      'AGFR / F-Gas',
      'Catalog produse',
      'Materiale',
      'Angajați',
      'Echipe',
      'HR / Payroll',
      'Deplasări',
      'Notificări',
      'Setări firmă',
    ],
    restrictions: [
      'Fără acces la Utilizatori',
      'Fără acces la Backup / Restaurare',
      'Fără acces la Setări email',
    ],
  ),
  _RoleDef(
    name: 'Șef echipă',
    key: 'team_lead',
    icon: Icons.supervisor_account_outlined,
    color: Color(0xFF2E7D32),
    description: 'Acces la modulele operaționale și HR. '
        'Poate gestiona echipa și planifica lucrări.',
    modules: [
      'Panou de control',
      'Programări',
      'Lucrări',
      'Scule / Pachete scule',
      'Reclamații',
      'Registratură',
      'AGFR / F-Gas',
      'Catalog produse',
      'Materiale',
      'Clienți',
      'Parteneri',
      'Angajați',
      'Echipe',
      'Deplasări',
      'Notificări',
    ],
    restrictions: [
      'Fără acces la Oferte',
      'Fără acces la HR / Payroll',
      'Fără acces la Setări firmă',
      'Fără acces la module administrative',
    ],
  ),
  _RoleDef(
    name: 'Angajat',
    key: 'employee',
    icon: Icons.engineering_outlined,
    color: Color(0xFF6A1B9A),
    description: 'Acces restricționat la modulele de teren: '
        'programări proprii, lucrări alocate, reclamații și AGFR.',
    modules: [
      'Panou de control (limitat)',
      'Programările mele',
      'Lucrările alocate',
      'Reclamații',
      'AGFR / F-Gas',
      'Notificări',
    ],
    restrictions: [
      'Fără acces la Oferte',
      'Fără acces la Clienți',
      'Fără acces la HR / Payroll',
      'Fără acces la Setări',
      'Vede doar programările și lucrările alocate echipei sale',
    ],
  ),
];

// ── Card rol ──────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.role, required this.colorScheme});

  final _RoleDef role;
  final ColorScheme colorScheme;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final cs = widget.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cs.surface,
          border: Border.all(
              color: role.color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: role.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [role.color, role.color.withValues(alpha: 0.35)],
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: role.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(role.icon, size: 24, color: role.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  role.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: role.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    role.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: role.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role.description,
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: Icon(Icons.keyboard_arrow_down,
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: _expanded
                    ? Column(children: [
                Divider(height: 1, color: cs.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module accesibile (${role.modules.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: role.modules
                            .map(
                              (m) => Chip(
                                label: Text(m,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    role.color.withValues(alpha: 0.07),
                                side: BorderSide(
                                    color:
                                        role.color.withValues(alpha: 0.2)),
                                labelStyle: TextStyle(color: role.color),
                              ),
                            )
                            .toList(),
                      ),
                      if (role.restrictions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Restricții',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...role.restrictions.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.block_outlined,
                                    size: 14, color: Colors.red.shade400),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(r,
                                      style:
                                          const TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
