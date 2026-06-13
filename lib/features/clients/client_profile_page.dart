import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';
import '../jobs/job_models.dart';
import '../oferte/firebase_oferte_repository.dart';
import '../oferte/local_oferte_repository.dart';
import '../oferte/offer_models.dart';
import '../programari/appointment_models.dart';
import 'client_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fișa completă client — 4 tab-uri: Rezumat, Istoric, Financiar, Echipamente
// ─────────────────────────────────────────────────────────────────────────────

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({
    super.key,
    required this.client,
    required this.repository,
    this.onClientUpdated,
  });

  final ClientRecord client;
  final AppDataRepository repository;
  final void Function(ClientRecord updated)? onClientUpdated;

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage>
    with SingleTickerProviderStateMixin {
  static final _moneyFmt = NumberFormat('#,##0.00', 'ro_RO');
  static final _dateFmt = DateFormat('dd.MM.yyyy', 'ro_RO');

  late final TabController _tabs;
  bool _loading = true;
  String? _error;

  // date
  List<Appointment> _appointments = const [];
  List<JobRecord> _jobs = const [];
  List<OfferRecord> _offers = const [];

  // note
  late final TextEditingController _notesCtrl;
  bool _notesDirty = false;
  bool _notesSaving = false;

  // clientul curent (poate fi actualizat)
  late ClientRecord _client;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _client = widget.client;
    _notesCtrl = TextEditingController(text: _client.notes);
    _notesCtrl.addListener(_onNoteChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notesCtrl.removeListener(_onNoteChanged);
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (!_notesDirty) setState(() => _notesDirty = true);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.listAppointments(),
        widget.repository.listJobs(),
        _loadOffers(),
      ]);
      if (!mounted) return;
      final allAppts = results[0] as List<Appointment>;
      final allJobs = results[1] as List<JobRecord>;
      final allOffers = results[2] as List<OfferRecord>;
      setState(() {
        _appointments = allAppts.where(_matchesAppt).toList()
          ..sort((a, b) => b.effectiveStartDateTime.compareTo(a.effectiveStartDateTime));
        _jobs = allJobs.where(_matchesJob).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _offers = allOffers.where(_matchesOffer).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  final _localOffersRepo = LocalOferteRepository();

  Future<List<OfferRecord>> _loadOffers() async {
    if (FirebaseBootstrap.isInitialized) {
      try {
        final cloud = await FirebaseOferteRepository().listOffers();
        await _localOffersRepo.replaceOffers(cloud);
        return cloud;
      } catch (_) {}
    }
    return _localOffersRepo.listOffers();
  }

  bool _matchesAppt(Appointment a) {
    return _idMatch(a.clientId) || _nameMatch(a.clientName) ||
        _idMatch(a.contractingClientId) || _nameMatch(a.contractingClientName);
  }

  bool _matchesJob(JobRecord j) => _idMatch(j.clientId);

  bool _matchesOffer(OfferRecord o) {
    return _idMatch(o.clientId) || _nameMatch(o.clientName) ||
        _idMatch(o.beneficiaryClientId) || _nameMatch(o.beneficiaryName) ||
        _idMatch(o.commercialRecipientClientId) || _nameMatch(o.commercialRecipientName);
  }

  bool _idMatch(String id) {
    final a = id.trim();
    final b = _client.id.trim();
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  bool _nameMatch(String name) {
    final a = name.trim().toLowerCase();
    final b = _client.name.trim().toLowerCase();
    return a.isNotEmpty && b.isNotEmpty && (a == b || a.contains(b) || b.contains(a));
  }

  // ── Salvare note ───────────────────────────────────────────────────────────
  Future<void> _saveNotes() async {
    if (!_notesDirty) return;
    setState(() { _notesSaving = true; });
    try {
      final updated = _client.copyWith(notes: _notesCtrl.text.trim(), updatedAt: DateTime.now());
      await widget.repository.saveClient(updated);
      _client = updated;
      widget.onClientUpdated?.call(updated);
      if (mounted) setState(() { _notesDirty = false; _notesSaving = false; });
    } catch (e) {
      if (mounted) setState(() => _notesSaving = false);
    }
  }

  // ── Apel telefon ──────────────────────────────────────────────────────────
  Future<void> _callPhone() async {
    final phone = _normalizePhone(_client.phone);
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:+$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── WhatsApp ──────────────────────────────────────────────────────────────
  Future<void> _openWhatsApp() async {
    final phone = _normalizePhone(_client.phone);
    if (phone.isEmpty) return;
    final lastEvent = _lastEventDescription();
    final msg = Uri.encodeComponent(
      'Bună ziua! Vă contactăm de la PRO TERM SRL${lastEvent.isNotEmpty ? ' în legătură cu $lastEvent' : ''}.',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('40')) return digits;
    if (digits.startsWith('0')) return '4$digits';
    return '40$digits';
  }

  String _lastEventDescription() {
    if (_appointments.isNotEmpty) {
      final last = _appointments.first;
      final dt = _dateFmt.format(last.effectiveStartDateTime);
      return 'programarea din $dt${last.equipmentDescription.isNotEmpty ? " (${last.equipmentDescription})" : ""}';
    }
    if (_jobs.isNotEmpty) return 'lucrarea "${_jobs.first.title}"';
    return '';
  }

  // ── Statistici ─────────────────────────────────────────────────────────────
  double get _totalFacturat {
    final fromAppts = _appointments.fold<double>(0, (s, a) => s + a.interventionPrice);
    final fromOffers = _offers.fold<double>(0, (s, o) => s + o.totalValue);
    return fromAppts + fromOffers;
  }

  int get _jobsInProgress => _jobs.where((j) =>
      j.status == JobStatus.inExecutie || j.status == JobStatus.planificata).length;

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client.name, overflow: TextOverflow.ellipsis),
        actions: [
          HelpButton(content: AppHelp.clientProfile),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă',
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Rezumat'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Istoric'),
            Tab(icon: Icon(Icons.euro_outlined), text: 'Financiar'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Echipamente'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Reîncearcă')),
                ]))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildRezumat(),
                    _buildIstoric(),
                    _buildFinanciar(),
                    _buildEchipamente(),
                  ],
                ),
    );
  }

  // ── FAB cu meniu ──────────────────────────────────────────────────────────
  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_client.phone.isNotEmpty) ...[
          FloatingActionButton.small(
            heroTag: 'fab_wa',
            onPressed: _openWhatsApp,
            tooltip: 'WhatsApp',
            backgroundColor: const Color(0xFF25D366),
            child: const Icon(Icons.chat, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          FloatingActionButton.small(
            heroTag: 'fab_tel',
            onPressed: _callPhone,
            tooltip: 'Sună clientul',
            child: const Icon(Icons.phone, size: 20),
          ),
          const SizedBox(height: 6),
        ],
        FloatingActionButton.extended(
          heroTag: 'fab_appt',
          onPressed: null,
          icon: const Icon(Icons.event_outlined),
          label: const Text('Programare nouă'),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 0 — Rezumat
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRezumat() {
    final initials = _client.name.trim().isEmpty
        ? '?'
        : _client.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(initials,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_client.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (_client.clientCode.isNotEmpty)
                    Text('Cod: ${_client.clientCode}', style: Theme.of(context).textTheme.bodySmall),
                  Text(_client.type.label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  if (_client.phone.isNotEmpty) _infoRow(Icons.phone, _client.phone),
                  if (_client.email.isNotEmpty) _infoRow(Icons.email_outlined, _client.email),
                  if (_client.address.isNotEmpty || _client.city.isNotEmpty)
                    _infoRow(Icons.location_on_outlined,
                        [_client.address, _client.city, _client.county].where((s) => s.isNotEmpty).join(', ')),
                  if (_client.cui.isNotEmpty) _infoRow(Icons.business_outlined, 'CUI: ${_client.cui}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stat cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _statCard('Programări totale', '${_appointments.length}', Icons.event_outlined, Colors.blue),
            _statCard('Lucrări în curs', '$_jobsInProgress', Icons.construction_outlined, Colors.orange),
            _statCard('Total facturat', '${_moneyFmt.format(_totalFacturat)} RON', Icons.euro_outlined, Colors.green),
            _statCard('Documente emise', '${_offers.length + _jobs.length}', Icons.description_outlined, Colors.purple),
          ],
        ),
        const SizedBox(height: 16),

        // Ultima activitate
        if (_appointments.isNotEmpty || _jobs.isNotEmpty) ...[
          Text('Ultima activitate', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (_appointments.isNotEmpty) _lastActivityTile(_appointments.first),
          if (_jobs.isNotEmpty) _lastJobTile(_jobs.first),
          const SizedBox(height: 16),
        ],

        // Note
        Text('Note client', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtrl,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Adaugă observații despre client...',
            border: const OutlineInputBorder(),
            suffixIcon: _notesDirty
                ? _notesSaving
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.save_outlined),
                        tooltip: 'Salvează note',
                        onPressed: _saveNotes,
                      )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _lastActivityTile(Appointment appt) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.event_outlined, size: 20),
      title: Text(appt.title.isNotEmpty ? appt.title : 'Programare', style: const TextStyle(fontSize: 13)),
      subtitle: Text(_dateFmt.format(appt.effectiveStartDateTime), style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _lastJobTile(JobRecord job) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.construction_outlined, size: 20),
      title: Text(job.title.isEmpty ? 'Lucrare' : job.title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(job.status.label, style: const TextStyle(fontSize: 11)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — Istoric
  // ─────────────────────────────────────────────────────────────────────────

  String _istoricFilter = 'Toate';

  Widget _buildIstoric() {
    final filters = ['Toate', 'Programări', 'Lucrări', 'Documente', 'Acest an', 'Anul trecut'];
    final thisYear = DateTime.now().year;
    final lastYear = thisYear - 1;

    List<_HistoryEvent> events = [
      ..._appointments.map((a) => _HistoryEvent(
            date: a.effectiveStartDateTime,
            type: 'Programare',
            title: a.title.isNotEmpty ? a.title : 'Programare',
            subtitle: a.equipmentDescription.isNotEmpty ? a.equipmentDescription : a.status,
            icon: Icons.event_outlined,
            color: Colors.blue,
          )),
      ..._jobs.map((j) => _HistoryEvent(
            date: j.updatedAt,
            type: 'Lucrare',
            title: j.title.isNotEmpty ? j.title : 'Lucrare',
            subtitle: j.status.label,
            icon: Icons.construction_outlined,
            color: Colors.orange,
          )),
      ..._offers.map((o) => _HistoryEvent(
            date: o.updatedAt,
            type: 'Document',
            title: o.offerNumber.isNotEmpty ? o.offerNumber : 'Ofertă',
            subtitle: '${_moneyFmt.format(o.totalValue)} RON',
            icon: Icons.description_outlined,
            color: Colors.purple,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final filtered = events.where((e) {
      switch (_istoricFilter) {
        case 'Programări': return e.type == 'Programare';
        case 'Lucrări': return e.type == 'Lucrare';
        case 'Documente': return e.type == 'Document';
        case 'Acest an': return e.date.year == thisYear;
        case 'Anul trecut': return e.date.year == lastYear;
        default: return true;
      }
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: filters.map((f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(f),
                selected: _istoricFilter == f,
                onSelected: (_) => setState(() => _istoricFilter = f),
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Nicio activitate în această perioadă.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: e.color.withValues(alpha: 0.15),
                        child: Icon(e.icon, size: 18, color: e.color),
                      ),
                      title: Text(e.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text('${e.type} • ${e.subtitle}', style: const TextStyle(fontSize: 11)),
                      trailing: Text(_dateFmt.format(e.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2 — Financiar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFinanciar() {
    final totalFacturat = _appointments.fold<double>(0, (s, a) => s + a.interventionPrice);
    final totalOferte = _offers.fold<double>(0, (s, o) => s + o.totalValue);
    final grand = totalFacturat + totalOferte;

    // 6 luni date
    final months = _last6Months();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sumar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _financialRow('Total intervenții', totalFacturat, Colors.blue),
              const Divider(),
              _financialRow('Total oferte/documente', totalOferte, Colors.purple),
              const Divider(),
              _financialRow('TOTAL GENERAL', grand, Colors.green, bold: true),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Grafic 6 luni
        if (months.any((m) => m.value > 0)) ...[
          Text('Ultimele 6 luni (intervenții)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _SimpleBarPainter(months),
              size: const Size(double.infinity, 140),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Per programare
        if (_appointments.isNotEmpty) ...[
          Text('Detaliu per programare', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ..._appointments.where((a) => a.interventionPrice > 0).map((a) => ListTile(
                dense: true,
                leading: const Icon(Icons.receipt_outlined, size: 18),
                title: Text(a.title.isNotEmpty ? a.title : 'Programare', style: const TextStyle(fontSize: 13)),
                subtitle: Text(_dateFmt.format(a.effectiveStartDateTime), style: const TextStyle(fontSize: 11)),
                trailing: Text('${_moneyFmt.format(a.interventionPrice)} RON',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              )),
        ],
      ],
    );
  }

  Widget _financialRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
        Text('${_moneyFmt.format(amount)} RON',
            style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
      ]),
    );
  }

  List<_MonthValue> _last6Months() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - 5 + i);
      final total = _appointments
          .where((a) => a.effectiveStartDateTime.year == m.year && a.effectiveStartDateTime.month == m.month)
          .fold<double>(0, (s, a) => s + a.interventionPrice);
      return _MonthValue(DateFormat('MMM', 'ro_RO').format(m), total);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3 — Echipamente
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEchipamente() {
    final withEq = _appointments.where((a) => a.equipmentDescription.trim().isNotEmpty).toList();

    if (withEq.isEmpty) {
      return const Center(child: Text('Niciun echipament înregistrat.'));
    }

    // Deduplicare
    final seen = <String>{};
    final unique = <_EquipmentEntry>[];
    for (final a in withEq) {
      final key = a.equipmentDescription.trim().toLowerCase();
      if (seen.add(key)) {
        unique.add(_EquipmentEntry(
          description: a.equipmentDescription.trim(),
          lastService: a.effectiveStartDateTime,
          count: withEq.where((x) => x.equipmentDescription.trim().toLowerCase() == key).length,
        ));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: unique.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final eq = unique[i];
        return ListTile(
          leading: const CircleAvatar(
            radius: 20,
            child: Icon(Icons.build_outlined, size: 18),
          ),
          title: Text(eq.description, style: const TextStyle(fontSize: 13)),
          subtitle: Text('Ultima intervenție: ${_dateFmt.format(eq.lastService)} • ${eq.count} intervenții',
              style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modele auxiliare
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryEvent {
  const _HistoryEvent({
    required this.date,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final DateTime date;
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _MonthValue {
  const _MonthValue(this.label, this.value);
  final String label;
  final double value;
}

class _EquipmentEntry {
  const _EquipmentEntry({
    required this.description,
    required this.lastService,
    required this.count,
  });
  final String description;
  final DateTime lastService;
  final int count;
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter pentru graficul de 6 luni
// ─────────────────────────────────────────────────────────────────────────────

class _SimpleBarPainter extends CustomPainter {
  const _SimpleBarPainter(this.months);
  final List<_MonthValue> months;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;
    final maxVal = months.map((m) => m.value).fold<double>(0, math.max);
    if (maxVal <= 0) return;

    final barW = (size.width / months.length) * 0.6;
    final gap = (size.width / months.length) * 0.4;
    final barColor = const Color(0xFF1565C0);
    final labelH = 22.0;
    final chartH = size.height - labelH;

    for (var i = 0; i < months.length; i++) {
      final x = i * (barW + gap) + gap / 2;
      final frac = months[i].value / maxVal;
      final bH = frac * (chartH - 20);

      if (bH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, chartH - bH, barW, bH),
            const Radius.circular(3),
          ),
          Paint()..color = barColor,
        );
      }

      // Label luna
      final tp = TextPainter(
        text: TextSpan(
          text: months[i].label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: barW + gap);
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - labelH + 4));
    }
  }

  @override
  bool shouldRepaint(_SimpleBarPainter old) => old.months != months;
}
