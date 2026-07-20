import 'package:flutter/material.dart';

import '../../../core/auth/app_role_policy.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../../../core/auth_models.dart';
import '../asociere_models.dart';
import '../asociere_repository.dart';
import 'asociere_config_page.dart';
import 'decont_asociere_page.dart';
import 'pontaj_asociere_page.dart';
import 'registru_asociere_page.dart';
import 'tarife_asociere_page.dart';

/// Tab „Asociere" din fișa Lucrare. Dacă lucrarea are o asociere activă →
/// hub cu navigare la sub-ecrane; altfel buton „Adaugă asociere".
/// Ecranele financiare (Registru, Decont) sunt vizibile DOAR pentru admin.
class AsociereTab extends StatefulWidget {
  const AsociereTab({
    super.key,
    required this.repository,
    required this.lucrareId,
    this.roleKey,
  });

  final AppDataRepository repository;
  final String lucrareId;
  final String? roleKey;

  @override
  State<AsociereTab> createState() => _AsociereTabState();
}

class _AsociereTabState extends State<AsociereTab> {
  AsociereRecord? _asociere;
  bool _loading = true;

  bool get _isAdmin =>
      AppRolePolicy.resolve(roleKey: widget.roleKey) == UserRole.admin;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final list =
        await AsociereRepository.instance.listByLucrare(widget.lucrareId);
    if (!mounted) return;
    setState(() {
      // Preferă o asociere activă; altfel prima (cea mai recentă).
      _asociere = list.isEmpty
          ? null
          : list.firstWhere((a) => a.status == AsociereStatus.activa,
              orElse: () => list.first);
      _loading = false;
    });
  }

  Future<void> _config({AsociereRecord? existing}) async {
    final result = await Navigator.of(context).push<AsociereRecord>(
      MaterialPageRoute(
        builder: (_) => AsociereConfigPage(
          repository: widget.repository,
          lucrareId: widget.lucrareId,
          existing: existing,
        ),
      ),
    );
    if (result != null) await _load();
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final a = _asociere;
    if (a == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.handshake_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Această lucrare nu are o asociere.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _config(),
              icon: const Icon(Icons.add),
              label: const Text('Adaugă asociere'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      a.partenerExternNume.isEmpty
                          ? 'Partener nespecificat'
                          : a.partenerExternNume,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text(a.status.label)),
                ]),
                const SizedBox(height: 4),
                Text('Cote: PRO TERM ${_fmt(a.cotaProTerm)}% · '
                    'Partener ${_fmt(a.cotaPartener)}%'),
                Text('Facturează: ${a.cineFactureazaBeneficiarul.label}'),
                if (_isAdmin)
                  Text('Prag aprobare: ${_fmt(a.pragAprobareRON)} RON · '
                      'Rezervă ${_fmt(a.procentRezervaGarantie)}%'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _config(existing: a),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editează'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _navCard(Icons.badge_outlined, 'Tarife',
            'Calificări și tarife RON/oră, RON/km',
            () => _open(TarifeAsocierePage(asociereId: a.id))),
        _navCard(Icons.schedule_outlined, 'Pontaj',
            'Ore lucrate, confirmare PRO TERM / Partener',
            () => _open(PontajAsocierePage(asociereId: a.id))),
        if (_isAdmin) ...[
          _navCard(Icons.receipt_long_outlined, 'Registru',
              'Costuri și venituri, aprobări',
              () => _open(RegistruAsocierePage(
                  asociereId: a.id, pragAprobareRON: a.pragAprobareRON))),
          _navCard(Icons.calculate_outlined, 'Decont lunar',
              'Generează decontul lunii, cu componente separate',
              () => _open(DecontAsocierePage(asociereId: a.id))),
        ],
      ],
    );
  }

  Widget _navCard(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
