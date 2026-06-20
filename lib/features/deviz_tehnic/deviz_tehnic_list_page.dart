import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../clients/client_models.dart';
import '../jobs/firebase_lucrari_repository.dart';
import '../jobs/job_models.dart';
import 'deviz_tehnic_models.dart';
import 'deviz_tehnic_pdf_service.dart';
import 'deviz_tehnic_repository.dart';
import 'deviz_tehnic_form_page.dart';

/// Prioritatea de afișare a unui deviz tehnic / ofertă / situație după status
/// (sortare logică, nu cronologică). Ordinea dorită: Acceptat → Trimis →
/// Draft → Respins → Anulat → Convertită (ultimele). Convertirea în lucrare are
/// prioritate ABSOLUTĂ peste statusul de bază.
int _devizStatusRank(DevizTehnicRecord d) {
  if (d.isConverted) return 100;
  switch (d.status) {
    case DevizTehnicStatus.acceptat:
      return 0;
    case DevizTehnicStatus.trimis:
      return 1;
    case DevizTehnicStatus.draft:
      return 2;
    case DevizTehnicStatus.respins:
      return 3;
    case DevizTehnicStatus.anulat:
      return 4;
  }
}

/// Comparator: întâi după prioritatea statusului, apoi (în cadrul aceluiași
/// status) după dată descrescător (cele mai recente primele).
int _compareDevizeByStatus(DevizTehnicRecord a, DevizTehnicRecord b) {
  final byStatus = _devizStatusRank(a).compareTo(_devizStatusRank(b));
  if (byStatus != 0) return byStatus;
  return b.updatedAt.compareTo(a.updatedAt);
}

/// Lista devizelor tehnice cu logica de calcul Excel (Mat/Man/Utilaj/Transport).
class DevizTehnicListPage extends StatefulWidget {
  const DevizTehnicListPage({
    super.key,
    required this.repository,
    required this.currentUserName,
    required this.currentUserId,
    this.hideAppBar = false,
  });

  final AppDataRepository repository;
  final String currentUserName;
  final String currentUserId;
  final bool hideAppBar;

  @override
  State<DevizTehnicListPage> createState() => _DevizTehnicListPageState();
}

class _DevizTehnicListPageState extends State<DevizTehnicListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _devizRepo = DevizTehnicRepository();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _syncing = false;
  List<DevizTehnicRecord> _items = [];
  List<ClientRecord> _clients = [];

  // Filtre
  bool _filtersVisible = false;
  final Set<DevizTehnicTipDocument> _filterTip = {};
  final Set<DevizTehnicStatus> _filterStatus = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_refresh);
    // Listener onlineNotifier: dacă pagina s-a deschis înainte ca Firebase să
    // fie ready (sau înainte de conexiune), reîncarcă automat.
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onOnlineChanged() {
    // Reîncarcă automat când devenim online — DAR NUMAI dacă lista e goală
    // (nu suprascriem date deja încărcate cu succes).
    if (FirebaseBootstrap.onlineNotifier.value && _items.isEmpty && !_loading) {
      _load();
    }
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _devizRepo.list(),
        _loadClients(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (results[0] as List<DevizTehnicRecord>)
          ..sort(_compareDevizeByStatus);
        _clients = results[1] as List<ClientRecord>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la încărcare: $e')),
      );
    }
  }

  Future<List<ClientRecord>> _loadClients() async {
    try {
      final list = await widget.repository.listClients();
      return [...list]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return [];
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_searchCtrl.text.isNotEmpty) count++;
    if (_filterTip.isNotEmpty) count++;
    if (_filterStatus.isNotEmpty) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _filterTip.clear();
      _filterStatus.clear();
    });
  }

  List<DevizTehnicRecord> get _filtered {
    var list = _items;
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((d) {
        return d.titlu.toLowerCase().contains(q) ||
            d.numar.toLowerCase().contains(q) ||
            d.clientName.toLowerCase().contains(q) ||
            d.obiectiv.toLowerCase().contains(q);
      }).toList();
    }
    if (_filterTip.isNotEmpty) {
      list = list.where((d) => _filterTip.contains(d.tipDocument)).toList();
    }
    if (_filterStatus.isNotEmpty) {
      list = list.where((d) => _filterStatus.contains(d.status)).toList();
    }
    return list;
  }

  Future<void> _exportPdf(DevizTehnicRecord d) async {
    try {
      final path = await DevizTehnicPdfService.export(
        repository: widget.repository,
        deviz: d,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'PDF ${d.tipDocument.label.toLowerCase()} generat',
        shareSubject:
            '${d.tipDocument.label} ${d.numar.isNotEmpty ? d.numar : d.titlu}',
        shareText:
            'PDF ${d.tipDocument.label.toLowerCase()} generat din aplicație.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare export PDF: $e')),
      );
    }
  }

  Future<void> _openForm({DevizTehnicRecord? existing}) async {
    final result = await Navigator.of(context).push<DevizTehnicRecord>(
      MaterialPageRoute(
        builder: (_) => DevizTehnicFormPage(
          existing: existing,
          clients: _clients,
          currentUserName: widget.currentUserName,
          currentUserId: widget.currentUserId,
          repository: _devizRepo,
          appRepository: widget.repository,
        ),
      ),
    );
    if (result != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? '${result.tipDocument.label} salvat: ${result.numar}'
              : '${result.tipDocument.label} actualizat: ${result.numar}'),
        ),
      );
    }
  }

  Future<void> _convertDevizToJob(DevizTehnicRecord d) async {
    if (d.isConverted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Devizul este deja convertit în lucrare (${d.convertedToJobId}).'),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convertește în lucrare'),
        content: Text(
          'Creezi o lucrare nouă din devizul "${d.numar.isNotEmpty ? d.numar : d.titlu}"?\n\n'
          'Liniile și totalul vor fi copiate ca plan de lucrare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convertește'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final now = DateTime.now();
      String nextJobCode = '';
      try {
        nextJobCode = await widget.repository.nextJobCode();
      } catch (_) {
        final stamp = now.millisecondsSinceEpoch.toString();
        final tail =
            stamp.length > 4 ? stamp.substring(stamp.length - 4) : stamp;
        nextJobCode = 'JOB-$tail';
      }

      // Mapare articole deviz → linii planificate JobLine
      // Fiecare articol poate avea până la 4 componente de preț;
      // generăm câte o linie separată per componentă nenulă.
      final linii = <JobLine>[];
      for (final a in d.articole) {
        if (a.pretMat > 0) {
          linii.add(JobLine(
            id: '',
            ofertaLineId: a.id,
            denumire: '${a.denumire} (Mat)',
            um: a.um,
            cantitateOferta: a.cantitate,
            cantitateReala: 0,
            pretUnitarOferta: a.pretMat,
            pretUnitarReal: 0,
            categorie: 'material',
          ));
        }
        if (a.pretMan > 0) {
          linii.add(JobLine(
            id: '',
            ofertaLineId: a.id,
            denumire: '${a.denumire} (Man)',
            um: a.um,
            cantitateOferta: a.cantitate,
            cantitateReala: 0,
            pretUnitarOferta: a.pretMan,
            pretUnitarReal: 0,
            categorie: 'manopera',
          ));
        }
        if (a.pretUtilaj > 0) {
          linii.add(JobLine(
            id: '',
            ofertaLineId: a.id,
            denumire: '${a.denumire} (Utilaj)',
            um: a.um,
            cantitateOferta: a.cantitate,
            cantitateReala: 0,
            pretUnitarOferta: a.pretUtilaj,
            pretUnitarReal: 0,
            categorie: 'utilaj',
          ));
        }
        if (a.pretTransport > 0) {
          linii.add(JobLine(
            id: '',
            ofertaLineId: a.id,
            denumire: '${a.denumire} (Transport)',
            um: a.um,
            cantitateOferta: a.cantitate,
            cantitateReala: 0,
            pretUnitarOferta: a.pretTransport,
            pretUnitarReal: 0,
            categorie: 'transport',
          ));
        }
      }

      // Formula profitului SPECIFICĂ devizului tehnic:
      //   regie  = totalDirect × regiePercent/100
      //   profit = (totalDirect + regie) × profitPercent/100  ← diferit față de Oferte
      // totalOferta = deviz.totalFaraTva (calculat corect cu formula devizului)
      final job = JobRecord(
        id: 'job-${now.microsecondsSinceEpoch}',
        jobCode: nextJobCode.trim(),
        clientId: d.clientId,
        title: d.titlu.isNotEmpty
            ? d.titlu
            : 'Lucrare din deviz ${d.numar}',
        location: '',
        city: '',
        county: '',
        contactPerson: d.contactPerson,
        contactPhone: d.clientPhone,
        description: 'Generata din deviz tehnic ${d.numar}',
        category: 'deviz_tehnic',
        status: JobStatus.planificata,
        startDate: null,
        dueDate: null,
        closedDate: null,
        estimatedValue: d.totalFaraTva > 0 ? d.totalFaraTva : null,
        notes: [
          if (d.note.trim().isNotEmpty) d.note.trim(),
          'Sursa deviz tehnic: ${d.numar}',
        ].join('\n'),
        isActive: true,
        createdAt: now,
        updatedAt: now,
        sourceOfferId: d.id,
        sourceOfferNumber: d.numar,
        sourceOfferTitle: d.titlu,
        sourceDocumentType: 'deviz_tehnic',
        createdByUserId: d.createdByUserId,
        regiePercent: d.regiePercent,
        profitPercent: d.profitPercent,
        vatPercent: d.tvaPercent,
        liniiPlanificate: linii,
        totalOferta: d.totalFaraTva,
      );

      // Salvare locală + cloud (pattern din oferte_page._saveJobResolved)
      FirebaseLucrariRepository? cloudRepo;
      if (FirebaseBootstrap.isInitialized) {
        try {
          cloudRepo = FirebaseLucrariRepository();
        } catch (_) {}
      }
      var queuedOffline = cloudRepo == null;
      if (cloudRepo != null) {
        try {
          await cloudRepo.upsertJob(job);
        } catch (e) {
          FirebaseBootstrap.registerRuntimeError(e);
          queuedOffline = true;
        }
      }
      final savedJob = await widget.repository.saveJob(job);
      if (queuedOffline) {
        await OfflineSyncRuntime.instance.queueJob(savedJob);
      }

      // Marchează devizul ca convertit
      final updatedDeviz = d.copyWith(
        convertedToJobId: savedJob.id,
        updatedAt: now,
      );
      await _devizRepo.save(updatedDeviz);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lucrare creată: ${savedJob.jobCode.isNotEmpty ? savedJob.jobCode : savedJob.id}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare conversie: $e')));
      }
    }
  }

  Future<void> _changeStatus(
      DevizTehnicRecord d, DevizTehnicStatus newStatus) async {
    try {
      final updated = d.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _devizRepo.save(updated);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status schimbat în: ${newStatus.label}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
  }

  Future<void> _confirmDelete(DevizTehnicRecord d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge deviz'),
        content: Text(
            'Ești sigur că vrei să ștergi devizul ${d.numar.isNotEmpty ? d.numar : d.titlu}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Optimistic UI: elimină imediat din listă — UI răspunde instant
    setState(() => _items.removeWhere((item) => item.id == d.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Deviz șters.')));

    // Defer ștergerea DUPĂ ce frame-ul curent se randează complet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _devizRepo.delete(d.id).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Eroare la ștergere: $e')));
          _load();
        }
      });
    });
  }

  Future<void> _duplicateDevizTehnic(DevizTehnicRecord source) async {
    final now = DateTime.now();
    final numar = await _devizRepo.nextNumber(source.tipDocument);
    if (!mounted) return;
    final draft = DevizTehnicRecord(
      id: 'dvz-dup-${now.microsecondsSinceEpoch}',
      numar: numar,
      titlu: source.titlu,
      obiectiv: source.obiectiv,
      clientId: source.clientId,
      clientName: source.clientName,
      clientCui: source.clientCui,
      clientAddress: source.clientAddress,
      clientPhone: source.clientPhone,
      clientEmail: source.clientEmail,
      contactPerson: source.contactPerson,
      contactDepartment: source.contactDepartment,
      dataEmiterii: now,
      zileValabilitate: source.zileValabilitate,
      articole: source.articole
          .map((a) => a.copyWith())
          .toList(growable: false),
      regiePercent: source.regiePercent,
      profitPercent: source.profitPercent,
      tvaPercent: source.tvaPercent,
      intocmitDe: source.intocmitDe,
      note: source.note,
      createdAt: now,
      updatedAt: now,
      createdByUserId: widget.currentUserId,
      tipDocument: source.tipDocument,
      status: DevizTehnicStatus.draft,
      priceDisplay: source.priceDisplay,
      registryEntryId: '',
      registryNumber: '',
    );
    final result = await Navigator.of(context).push<DevizTehnicRecord>(
      MaterialPageRoute(
        builder: (_) => DevizTehnicFormPage(
          existing: draft,
          clients: _clients,
          currentUserName: widget.currentUserName,
          currentUserId: widget.currentUserId,
          repository: _devizRepo,
          appRepository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${source.tipDocument.label} ${source.numar.isNotEmpty ? source.numar : source.titlu} '
            'duplicat ca ${result.numar}.',
          ),
        ),
      );
    }
  }

  Future<void> _forceSyncToCloud() async {
    setState(() => _syncing = true);
    try {
      final count = await _devizRepo.forceSyncLocalToCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '$count document(e) trimise la cloud cu succes.'
              : 'Niciun document de trimis.'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la trimitere: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filtered;
    final fmt = NumberFormat('#,##0.00', 'ro_RO');
    final dateFmt = DateFormat('dd.MM.yyyy');
    final cs = Theme.of(context).colorScheme;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final showFilters = isWide || _filtersVisible;
        final hasActiveFilters = _activeFilterCount > 0;

        return Column(
          children: [
            // ── Toolbar: search + buton filtre ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Caută după număr, titlu, client...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        border: hasActiveFilters
                            ? OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.5),
                              )
                            : const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (!isWide) ...[
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _activeFilterCount > 0,
                      label: Text('$_activeFilterCount'),
                      child: IconButton(
                        icon: Icon(_filtersVisible
                            ? Icons.filter_list_off
                            : Icons.filter_list),
                        tooltip: 'Filtre',
                        onPressed: () =>
                            setState(() => _filtersVisible = !_filtersVisible),
                      ),
                    ),
                  ],
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Resetează'),
                    ),
                  ],
                  // Buton sincronizare forțată — trimite datele locale la cloud.
                  // Util pe PC (web) dacă datele au fost create offline și nu
                  // au ajuns în Firestore (nu sunt vizibile pe alte dispozitive).
                  const SizedBox(width: 4),
                  IconButton(
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync_outlined),
                    tooltip: 'Sincronizează la cloud (trimite datele locale)',
                    onPressed: (_loading || _syncing) ? null : _forceSyncToCloud,
                  ),
                ],
              ),
            ),
            // ── Panoul de filtre ──
            if (showFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filtrare tip document
                    Text(
                      'Tip document',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: DevizTehnicTipDocument.values.map((tip) {
                        final active = _filterTip.contains(tip);
                        return FilterChip(
                          label: Text(tip.label,
                              style: const TextStyle(fontSize: 12)),
                          selected: active,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _filterTip.add(tip);
                              } else {
                                _filterTip.remove(tip);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Filtrare status
                    Text(
                      'Status',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: DevizTehnicStatus.values.map((st) {
                        final active = _filterStatus.contains(st);
                        return FilterChip(
                          label: Text(st.label,
                              style: const TextStyle(fontSize: 12)),
                          selected: active,
                          selectedColor: st.color.withValues(alpha: 0.2),
                          checkmarkColor: st.color,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _filterStatus.add(st);
                              } else {
                                _filterStatus.remove(st);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            // List
          Expanded(
            child: items.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calculate_outlined,
                                  size: 48, color: cs.outline),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isNotEmpty ||
                                        _filterTip.isNotEmpty ||
                                        _filterStatus.isNotEmpty
                                    ? 'Niciun deviz corespunde filtrelor active.'
                                    : 'Niciun deviz tehnic găsit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.outline),
                              ),
                              // Info debug extins — diagnosticare cross-device
                              if (_searchCtrl.text.isEmpty &&
                                  _filterTip.isEmpty &&
                                  _filterStatus.isEmpty) ...[
                                const SizedBox(height: 16),
                                Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: DefaultTextStyle(
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Firebase: '
                                            'init=${FirebaseBootstrap.isInitialized} '
                                            'online=${FirebaseBootstrap.isOnline}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: FirebaseBootstrap.isInitialized
                                                  ? cs.onSurfaceVariant
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Cache local: ${DevizTehnicRepository.lastLocalCount} doc.'
                                            '  |  Firestore: ${DevizTehnicRepository.lastFirestoreCount < 0 ? "eroare/nefinalizat" : "${DevizTehnicRepository.lastFirestoreCount} doc."}',
                                          ),
                                          if (DevizTehnicRepository.lastFirestoreError != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Eroare Firestore: ${DevizTehnicRepository.lastFirestoreError}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red.shade700,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Trage în jos pentru a reîncărca din cloud.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _loading ? null : _load,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Reîncarcă din cloud'),
                                ),
                                const SizedBox(height: 8),
                                // Buton forțare sync: publică documentele locale în Firestore
                                if (DevizTehnicRepository.lastLocalCount > 0)
                                  OutlinedButton.icon(
                                    onPressed: (_loading || _syncing)
                                        ? null
                                        : _forceSyncToCloud,
                                    icon: _syncing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.cloud_upload_outlined,
                                            size: 16),
                                    label: Text(_syncing
                                        ? 'Se trimite la cloud…'
                                        : 'Trimite la cloud (${DevizTehnicRepository.lastLocalCount} doc.)'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final d = items[i];
                        final statusColor = d.status.color;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          // Chenar colorat după status (vizibil ca la programări)
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: statusColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _openForm(existing: d),
                            child: Container(
                              // Fundal colorat subtil după status
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tip document + număr + status + data
                                  Row(
                                    children: [
                                      // Badge tip document
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          d.tipDocument.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: cs.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      if (d.numar.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            d.numar,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: cs.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      // Badge status colorat
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: statusColor
                                                .withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          d.status.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: statusColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (d.isConverted) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.green
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: const Text(
                                            '✓ Lucrare',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        dateFmt.format(d.dataEmiterii),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Titlu
                                  Text(
                                    d.titlu.isNotEmpty
                                        ? d.titlu
                                        : d.tipDocument.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (d.obiectiv.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      d.obiectiv,
                                      style: TextStyle(
                                          fontSize: 13, color: cs.outline),
                                    ),
                                  ],
                                  if (d.clientName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline,
                                            size: 14, color: cs.outline),
                                        const SizedBox(width: 4),
                                        Text(
                                          d.clientName,
                                          style: TextStyle(
                                              fontSize: 13, color: cs.outline),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  // Totaluri + articole count
                                  Row(
                                    children: [
                                      _MiniStat(
                                          label: 'Articole',
                                          value: '${d.articole.length}'),
                                      const SizedBox(width: 12),
                                      _MiniStat(
                                          label: 'Fără TVA',
                                          value:
                                              '${fmt.format(d.totalFaraTva)} RON'),
                                      const SizedBox(width: 12),
                                      _MiniStat(
                                        label: 'TOTAL cu TVA',
                                        value:
                                            '${fmt.format(d.totalCuTva)} RON',
                                        highlight: true,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 18),
                                        tooltip: 'Exportă PDF',
                                        onPressed: () => _exportPdf(d),
                                      ),
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_vert,
                                              size: 20),
                                          tooltip: 'Acțiuni',
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'open':
                                                _openForm(existing: d);
                                              case 'edit':
                                                _openForm(existing: d);
                                              case 'duplicate':
                                                _duplicateDevizTehnic(d);
                                              case 'convert':
                                                _convertDevizToJob(d);
                                              case 'delete':
                                                _confirmDelete(d);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'open',
                                              child: ListTile(
                                                leading: Icon(Icons
                                                    .visibility_outlined),
                                                title:
                                                    Text('Deschide detaliu'),
                                                dense: true,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: ListTile(
                                                leading:
                                                    Icon(Icons.edit_outlined),
                                                title: Text('Editează'),
                                                dense: true,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'duplicate',
                                              child: ListTile(
                                                leading: Icon(Icons
                                                    .content_copy_outlined),
                                                title: Text('Duplică'),
                                                dense: true,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                              ),
                                            ),
                                            if (d.tipDocument !=
                                                DevizTehnicTipDocument
                                                    .situatieLucrari)
                                              PopupMenuItem(
                                                value: 'convert',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.transform_outlined,
                                                    color: d.isConverted
                                                        ? Colors.green
                                                        : null,
                                                  ),
                                                  title: Text(
                                                    d.isConverted
                                                        ? 'Convertit în lucrare'
                                                        : 'Convertește în lucrare',
                                                    style: TextStyle(
                                                      color: d.isConverted
                                                          ? Colors.green
                                                          : null,
                                                    ),
                                                  ),
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red),
                                                title: Text('Șterge',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                                dense: true,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Butoane rapide schimbare status ──────────
                                  const SizedBox(height: 6),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: DevizTehnicStatus.values
                                          .where((s) => s != d.status)
                                          .map(
                                            (s) => Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 6),
                                              child: OutlinedButton(
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  foregroundColor: s.color,
                                                  side: BorderSide(
                                                      color: s.color
                                                          .withValues(
                                                              alpha: 0.5)),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                  minimumSize:
                                                      const Size(0, 28),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  textStyle:
                                                      const TextStyle(
                                                          fontSize: 11),
                                                ),
                                                onPressed: () =>
                                                    _changeStatus(d, s),
                                                child: Text('→ ${s.label}'),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ),
          ],
        );
      },
    );

    final fab = FloatingActionButton.extended(
      onPressed: () => _openForm(),
      icon: const Icon(Icons.add),
      label: const Text('Document nou'),
    );

    if (widget.hideAppBar) {
      return Scaffold(body: body, floatingActionButton: fab);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Devize tehnice')),
      body: body,
      floatingActionButton: fab,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.outline)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: highlight ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }
}
