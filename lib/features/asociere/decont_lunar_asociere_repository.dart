import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'asociere_decont_calculator.dart';
import 'asociere_repository.dart';
import 'cost_asociere_models.dart';
import 'cost_asociere_repository.dart';
import 'decont_lunar_asociere_models.dart';
import 'pontaj_asociere_models.dart';
import 'pontaj_asociere_repository.dart';
import 'tarif_asociere_repository.dart';
import 'venit_asociere_repository.dart';

/// Aruncată de [DecontLunarAsociereRepository.genereazaDecontPentruLuna] când
/// există costuri din perioada decontului care necesită aprobare și nu au
/// aprobarea completă. Generarea e blocată până la aprobare.
class DecontAprobareIncompletaException implements Exception {
  DecontAprobareIncompletaException(this.costuriNeaprobate);

  final List<CostAsociereRecord> costuriNeaprobate;

  String get message {
    final n = costuriNeaprobate.length;
    final descrieri = costuriNeaprobate
        .map((c) =>
            '${c.descriere.isEmpty ? '(fără descriere)' : c.descriere} '
            '(${c.valoareFaraTva.toStringAsFixed(2)} RON)')
        .join('; ');
    return 'Nu se poate genera decontul: $n cost'
        '${n == 1 ? '' : 'uri'} necesită aprobare și nu '
        '${n == 1 ? 'este aprobat' : 'sunt aprobate'} integral (PRO TERM și '
        'partener). Aprobă întâi: $descrieri.';
  }

  @override
  String toString() => message;
}

/// Repository pentru deconturi lunare pe asociere. Decontul NU se introduce
/// manual — se generează (vezi [genereazaDecontPentruLuna]).
class DecontLunarAsociereRepository {
  DecontLunarAsociereRepository._();
  static final DecontLunarAsociereRepository instance =
      DecontLunarAsociereRepository._();

  static const String _localKey = 'deconturi_lunare_asociere_v1';

  static String? lastFirestoreError;
  static int lastLocalCount = 0;

  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection(FirebaseCollections.deconturiLunareAsociere);

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> upsertDecont(DecontLunarAsociereRecord r) async {
    await _writeLocal(r);
    await OfflineSyncRuntime.instance.queueDecontLunarAsociere(r);
    if (_isCloud) {
      _col.doc(r.id).set(r.toMap(), SetOptions(merge: true)).catchError((e) {
        lastFirestoreError = e.toString();
      });
    }
  }

  Future<void> deleteDecont(String id) async {
    await _deleteLocal(id);
    await OfflineSyncRuntime.instance.queueDecontLunarAsociereDelete(id);
    if (_isCloud) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  /// Confirmă un decont draft (îl marchează definitiv — nu mai e regenerat).
  Future<DecontLunarAsociereRecord> confirmaDecont(String id) async {
    final all = await listLocal();
    final idx = all.indexWhere((d) => d.id == id);
    if (idx < 0) throw StateError('Decont $id inexistent');
    final current = all[idx];
    final confirmed = DecontLunarAsociereRecord(
      id: current.id,
      asociereId: current.asociereId,
      luna: current.luna,
      an: current.an,
      veniturIncasatTotal: current.veniturIncasatTotal,
      costRecunoscutProTerm: current.costRecunoscutProTerm,
      costRecunoscutPartener: current.costRecunoscutPartener,
      rezultat: current.rezultat,
      rambursareDatorataCatre: current.rambursareDatorataCatre,
      sumaRambursare: current.sumaRambursare,
      sumaRezervaRetinuta: current.sumaRezervaRetinuta,
      sumaDeAchitatAcum: current.sumaDeAchitatAcum,
      status: DecontLunarStatus.confirmat,
      dataGenerare: current.dataGenerare,
    );
    await upsertDecont(confirmed);
    return confirmed;
  }

  // ── Citire ───────────────────────────────────────────────────────────────

  Future<List<DecontLunarAsociereRecord>> listLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = decoded
          .whereType<Map>()
          .map((e) =>
              DecontLunarAsociereRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      lastLocalCount = items.length;
      return items;
    } catch (e) {
      debugPrint('[DecontAsociere] ❌ listLocal: $e');
      return [];
    }
  }

  Future<List<DecontLunarAsociereRecord>> listMerged() async {
    final locals = await listLocal();
    if (!_isCloud) return _sort(locals);
    try {
      final snap = await _col.get();
      final cloud = snap.docs
          .map((d) =>
              DecontLunarAsociereRecord.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final cloudIds = cloud.map((c) => c.id).toSet();
      final localOnly = locals.where((l) => !cloudIds.contains(l.id)).toList();
      for (final r in localOnly) {
        await OfflineSyncRuntime.instance.queueDecontLunarAsociere(r);
      }
      lastFirestoreError = null;
      return _sort([...cloud, ...localOnly]);
    } catch (e) {
      lastFirestoreError = e.toString();
      return _sort(locals);
    }
  }

  Future<List<DecontLunarAsociereRecord>> listByAsociere(
      String asociereId) async {
    final all = await listLocal();
    return _sort(all.where((r) => r.asociereId == asociereId).toList());
  }

  Future<DecontLunarAsociereRecord?> getPentruLuna(
      String asociereId, int luna, int an) async {
    final all = await listLocal();
    for (final d in all) {
      if (d.asociereId == asociereId && d.luna == luna && d.an == an) return d;
    }
    return null;
  }

  // ── Generare decont ───────────────────────────────────────────────────────

  /// Generează (sau regenerează) decontul lunar pentru o asociere.
  ///
  /// Reguli de recunoaștere (vezi comentariile din modele):
  /// - VENIT recunoscut: VenitAsociere cu `dataIncasare` în (luna, an) —
  ///   facturile emise dar neîncasate NU contează.
  /// - COST MANOPERĂ: se calculează din pontaje (ore × tarif RON/oră pe
  ///   calificare), DOAR pentru pontaje confirmate integral, încadrate după
  ///   `PontajAsociereRecord.dataRecunoastereCost` (data confirmării).
  ///   Manopera este atribuită părții = `pontaj.angajator`.
  /// - ALTE COSTURI: CostAsociere încadrate după `dataRecunoastereCost`
  ///   (imediat dacă nu necesită aprobare; altfel data aprobării integrale).
  ///   Atribuite părții = `cost.asociatPlatitor` (cine a plătit efectiv).
  ///   Categoria `manoperaCalculata` este EXCLUSĂ aici — manopera vine
  ///   exclusiv din pontaje, ca să nu fie contorizată dublu.
  ///
  /// Settle-up (împărțire pe cote %):
  ///   rezultat = venituri − (costPT + costPartener)  (poate fi negativ)
  ///   Presupunere: PRO TERM încasează veniturile (contractant principal) și
  ///   deține numerarul; fiecare parte a plătit din buzunar costurile proprii.
  ///   Suma pe care PRO TERM o datorează partenerului ca să ajungă fiecare la
  ///   cota lui din rezultat:
  ///     T = costPartener + (cotaPartener/100) × rezultat
  ///   T > 0 → PRO TERM datorează partenerului; T < 0 → partenerul datorează
  ///   PRO TERM; T ≈ 0 → nimeni.
  ///
  /// Reținere rezervă de garanție (DOAR din rambursarea CĂTRE partener):
  ///   sumaRezervaRetinuta = sumaRambursare × procentRezervaGarantie/100
  ///   sumaDeAchitatAcum   = sumaRambursare − sumaRezervaRetinuta (restul, ~70%)
  ///   Pentru rambursare către PRO TERM nu se reține rezervă
  ///   (rezerva = 0, sumaDeAchitatAcum = sumaRambursare integral).
  ///
  /// Idempotent: un decont deja CONFIRMAT pentru luna respectivă NU se
  /// regenerează (se întoarce cel existent). ID determinist per (asociere, an,
  /// lună) → regenerarea unui draft îl suprascrie.
  Future<DecontLunarAsociereRecord> genereazaDecontPentruLuna({
    required String asociereId,
    required int luna,
    required int an,
  }) async {
    final asociere = await AsociereRepository.instance.getById(asociereId);
    if (asociere == null) {
      throw StateError('Asociere $asociereId inexistentă');
    }

    // Nu regenera un decont deja confirmat.
    final existing = await getPentruLuna(asociereId, luna, an);
    if (existing != null && existing.status == DecontLunarStatus.confirmat) {
      return existing;
    }

    // 1. Venituri încasate în lună.
    final venituri =
        await VenitAsociereRepository.instance.listByAsociere(asociereId);
    double veniturIncasatTotal = 0;
    for (final v in venituri) {
      if (_inMonth(v.dataIncasare, luna, an)) {
        veniturIncasatTotal += v.valoareFaraTva;
      }
    }

    // 2. Cost manoperă din pontaje confirmate, pe părți.
    final tarife =
        await TarifAsociereRepository.instance.listByAsociere(asociereId);
    final tarifByCalificare = <String, double>{
      for (final t in tarife) t.calificare.trim().toLowerCase(): t.tarifRonOra,
    };
    final pontaje =
        await PontajAsociereRepository.instance.listByAsociere(asociereId);
    double costPT = 0;
    double costPartener = 0;
    for (final p in pontaje) {
      if (!_inMonth(p.dataRecunoastereCost, luna, an)) continue;
      final tarif = tarifByCalificare[p.calificare.trim().toLowerCase()] ?? 0;
      final cost = p.ore * tarif;
      if (p.angajator == AsociereAngajator.proTerm) {
        costPT += cost;
      } else {
        costPartener += cost;
      }
    }

    // 3. Alte costuri (fără manopera calculată), pe părți.
    final costuri =
        await CostAsociereRepository.instance.listByAsociere(asociereId);

    // BLOCARE: costuri din perioadă care necesită aprobare și nu o au completă
    // → decontul ar fi incomplet. Se aruncă înainte de orice scriere.
    final blocante = costuriCareBlocheazaDecont(costuri, luna, an);
    if (blocante.isNotEmpty) {
      throw DecontAprobareIncompletaException(blocante);
    }

    for (final c in costuri) {
      if (c.categorie == AsociereCostCategorie.manoperaCalculata) continue;
      if (!_inMonth(c.dataRecunoastereCost, luna, an)) continue;
      if (c.asociatPlatitor == AsociereParte.proTerm) {
        costPT += c.valoareFaraTva;
      } else {
        costPartener += c.valoareFaraTva;
      }
    }

    // 4. Rezultat + settle-up pe cote + reținere rezervă (funcție pură testată).
    final settle = calculeazaDecontSettleUp(
      veniturIncasatTotal: veniturIncasatTotal,
      costRecunoscutProTerm: costPT,
      costRecunoscutPartener: costPartener,
      cotaProTerm: asociere.cotaProTerm,
      cotaPartener: asociere.cotaPartener,
      incasator: asociere.cineFactureazaBeneficiarul,
      procentRezervaGarantie: asociere.procentRezervaGarantie,
    );

    final record = DecontLunarAsociereRecord(
      id: existing?.id ?? _decontId(asociereId, luna, an),
      asociereId: asociereId,
      luna: luna,
      an: an,
      veniturIncasatTotal: _round2(veniturIncasatTotal),
      costRecunoscutProTerm: _round2(costPT),
      costRecunoscutPartener: _round2(costPartener),
      rezultat: settle.rezultat,
      rambursareDatorataCatre: settle.rambursareDatorataCatre,
      sumaRambursare: settle.sumaRambursare,
      sumaRezervaRetinuta: settle.sumaRezervaRetinuta,
      sumaDeAchitatAcum: settle.sumaDeAchitatAcum,
      status: DecontLunarStatus.draft,
      dataGenerare: DateTime.now(),
    );

    await upsertDecont(record);
    return record;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _inMonth(DateTime? d, int luna, int an) {
    if (d == null) return false;
    return d.year == an && d.month == luna;
  }

  String _decontId(String asociereId, int luna, int an) =>
      '${asociereId}_${an}_${luna.toString().padLeft(2, '0')}';

  double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  // ── Persistență ───────────────────────────────────────────────────────────

  Future<void> _writeLocal(DecontLunarAsociereRecord r) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    final idx = all.indexWhere((item) => item.id == r.id);
    if (idx >= 0) {
      all[idx] = r;
    } else {
      all.add(r);
    }
    await prefs.setString(
        _localKey, jsonEncode(all.map((item) => item.toMap()).toList()));
  }

  Future<void> _deleteLocal(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await listLocal();
    all.removeWhere((r) => r.id == id);
    await prefs.setString(
        _localKey, jsonEncode(all.map((r) => r.toMap()).toList()));
  }

  List<DecontLunarAsociereRecord> _sort(List<DecontLunarAsociereRecord> list) {
    return list
      ..sort((a, b) {
        final byAn = b.an.compareTo(a.an);
        if (byAn != 0) return byAn;
        return b.luna.compareTo(a.luna);
      });
  }
}
