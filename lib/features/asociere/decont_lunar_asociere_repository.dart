import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'asociere_decont_calculator.dart';
import 'asociere_operational_common.dart';
import 'asociere_repository.dart';
import 'cost_asociere_models.dart';
import 'cost_asociere_repository.dart';
import 'decont_lunar_asociere_models.dart';
import 'lucrare_asociere_cloud_repository.dart';
import 'pontaj_asociere_repository.dart';
import 'venit_asociere_models.dart';
import 'venit_asociere_repository.dart';

class DecontAprobareIncompletaException implements Exception {
  const DecontAprobareIncompletaException(this.costuriNeaprobate);
  final List<CostAsociereRecord> costuriNeaprobate;
  @override
  String toString() =>
      'Decont blocat: ${costuriNeaprobate.length} costuri nu sunt aprobate.';
}

class DecontLunarAsociereRepository {
  DecontLunarAsociereRepository._();
  static final instance = DecontLunarAsociereRepository._();
  static const _localKey = 'deconturi_lunare_asociere_v1';
  static String? lastFirestoreError;
  static DateTime? lastSyncAt;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.deconturiLunareAsociere);

  Future<List<DecontLunarAsociereRecord>> listLocal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_localKey) ?? '[]');
      if (raw is! List) return const [];
      return _sort(raw
          .whereType<Map>()
          .map((item) => DecontLunarAsociereRecord.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList());
    } catch (_) {
      return const [];
    }
  }

  Future<List<DecontLunarAsociereRecord>> listMerged() async {
    final local = await listLocal();
    if (!FirebaseBootstrap.isInitialized) return local;
    try {
      final snapshot = await _collection.get();
      final remote = snapshot.docs
          .map((doc) => DecontLunarAsociereRecord.fromMap({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
      final pending = await OfflineSyncRuntime.instance.pendingUpsertEntityIds(
        CloudEntityType.deconturiLunareAsociere,
      );
      final localById = {for (final item in local) item.id: item};
      final merged = <String, DecontLunarAsociereRecord>{};
      for (final remoteItem in remote) {
        final localItem = localById[remoteItem.id];
        merged[remoteItem.id] = localItem != null &&
                (pending.contains(remoteItem.id) ||
                    localItem.revision > remoteItem.revision)
            ? localItem
            : remoteItem;
      }
      for (final localItem in local) {
        if (!merged.containsKey(localItem.id)) {
          merged[localItem.id] = localItem;
          await OfflineSyncRuntime.instance.queueDecontLunarAsociere(localItem);
        }
      }
      final result = _sort(merged.values.toList());
      await _writeAll(result);
      lastFirestoreError = null;
      lastSyncAt = DateTime.now();
      return result;
    } catch (error) {
      lastFirestoreError = '$error';
      return local;
    }
  }

  Future<List<DecontLunarAsociereRecord>> listByProject(
      String projectId) async {
    final all = await listMerged();
    return _sort(all.where((item) => item.projectId == projectId).toList());
  }

  Future<DecontLunarAsociereRecord?> getPentruLuna(
    String projectId,
    String contractId,
    int luna,
    int an,
  ) async {
    final items = await listLocal();
    for (final item in items) {
      if (item.projectId == projectId &&
          item.contractId == contractId &&
          item.luna == luna &&
          item.an == an) {
        return item;
      }
    }
    return null;
  }

  Future<DecontLunarAsociereRecord> genereazaDecontPentruLuna({
    required String projectId,
    required String contractId,
    required int luna,
    required int an,
    required String actor,
  }) async {
    final project = (await LucrareAsociereCloudRepository.instance.listLocal())
        .where((item) => item.id == projectId)
        .firstOrNull;
    if (project == null) throw StateError('Proiectul Asociere nu există.');
    final contract = await AsociereRepository.instance.getById(contractId);
    if (contract == null || contract.lucrareAsociereId != projectId) {
      throw StateError('Configurația contractuală nu aparține proiectului.');
    }
    final existing = await getPentruLuna(projectId, contractId, luna, an);
    if (existing?.status == DecontLunarStatus.confirmat) return existing!;

    final venituri =
        await VenitAsociereRepository.instance.listByProject(projectId);
    final pontaje =
        await PontajAsociereRepository.instance.listByProject(projectId);
    final costuri =
        await CostAsociereRepository.instance.listByProject(projectId);
    final blocante = costuri
        .where((cost) =>
            _inMonth(cost.dataApartenentaLuna, luna, an) && !cost.esteAprobat)
        .toList();
    if (blocante.isNotEmpty) throw DecontAprobareIncompletaException(blocante);

    final inputIds = <String>[];
    final seen = <String>{};
    double venitTotal = 0;
    for (final venit in venituri) {
      if (venit.contractId != null && venit.contractId != contractId) continue;
      if (!venit.eligibil ||
          venit.status == AsociereOperationalStatus.respins) {
        continue;
      }
      if (venit.etapa != VenitAsociereEtapa.incasat ||
          !_inMonth(venit.dataIncasarii, luna, an)) {
        continue;
      }
      if (!seen.add(venit.idempotencyKey)) continue;
      venitTotal += venit.valoareProiect;
      inputIds.add('venit:${venit.id}');
    }

    double costProTerm = 0;
    double costPartener = 0;
    for (final pontaj in pontaje) {
      if (pontaj.contractId.isNotEmpty && pontaj.contractId != contractId) {
        continue;
      }
      if (!pontaj.esteConfirmatIntegral ||
          !_inMonth(pontaj.dataRecunoastereCost, luna, an)) {
        continue;
      }
      if (!seen.add(pontaj.idempotencyKey)) continue;
      if (pontaj.angajator.name == 'proTerm') {
        costProTerm += pontaj.costCalculat;
      } else {
        costPartener += pontaj.costCalculat;
      }
      inputIds.add('pontaj:${pontaj.id}');
    }
    for (final cost in costuri) {
      if (cost.contractId != null && cost.contractId != contractId) continue;
      if (!cost.eligibil ||
          !cost.esteAprobat ||
          !_inMonth(cost.aprobatLa, luna, an)) {
        continue;
      }
      if (!seen.add(cost.idempotencyKey)) continue;
      if (cost.platitor == AsociereParte.proTerm) {
        costProTerm += cost.valoareProiect;
      } else if (cost.platitor == AsociereParte.partener) {
        costPartener += cost.valoareProiect;
      }
      inputIds.add('cost:${cost.id}');
    }

    final settle = calculeazaDecontSettleUp(
      veniturIncasatTotal: venitTotal,
      costRecunoscutProTerm: costProTerm,
      costRecunoscutPartener: costPartener,
      cotaProTerm: contract.cotaProTerm,
      cotaPartener: contract.cotaPartener,
      incasator: contract.cineFactureazaBeneficiarul,
      procentRezervaGarantie: contract.procentRezervaGarantie,
    );
    final record = DecontLunarAsociereRecord(
      id: existing?.id ??
          '${projectId}_${contractId}_${an}_${luna.toString().padLeft(2, '0')}',
      projectId: projectId,
      contractId: contractId,
      luna: luna,
      an: an,
      projectSnapshot: {
        'id': project.id,
        'numar': project.numar,
        'denumire': project.denumire,
        'moneda': project.moneda,
      },
      contractSnapshot: {
        'id': contract.id,
        'cota_pro_term': contract.cotaProTerm,
        'cota_partener': contract.cotaPartener,
        'rezerva': contract.procentRezervaGarantie,
      },
      inputIds: inputIds..sort(),
      veniturIncasatTotal: _round2(venitTotal),
      costRecunoscutProTerm: _round2(costProTerm),
      costRecunoscutPartener: _round2(costPartener),
      rezultat: settle.rezultat,
      rambursareDatorataCatre: settle.rambursareDatorataCatre,
      rambursareCosturi: settle.rambursareCosturi,
      distribuireProfitImediata: settle.distribuireProfitImediata,
      sumaRambursare: settle.sumaRambursare,
      sumaRezervaRetinuta: settle.sumaRezervaRetinuta,
      sumaDeAchitatAcum: settle.sumaDeAchitatAcum,
      dataGenerare: DateTime.now(),
      generatDe: actor,
      revision: (existing?.revision ?? 0) + 1,
    );
    await upsert(record);
    return record;
  }

  Future<DecontLunarAsociereRecord> confirma(String id, String actor) async {
    final items = await listLocal();
    final current = items.where((item) => item.id == id).firstOrNull;
    if (current == null) throw StateError('Decontul nu există.');
    final confirmed = current.confirma(actor, DateTime.now());
    await upsert(confirmed);
    return confirmed;
  }

  Future<void> upsert(DecontLunarAsociereRecord record) async {
    final items = await listLocal();
    final index = items.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      items.add(record);
    } else {
      items[index] = record;
    }
    await _writeAll(items);
    await OfflineSyncRuntime.instance.queueDecontLunarAsociere(record);
  }

  Future<void> _writeAll(List<DecontLunarAsociereRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localKey, jsonEncode(items.map((item) => item.toMap()).toList()));
  }

  bool _inMonth(DateTime? value, int month, int year) =>
      value != null && value.month == month && value.year == year;
  double _round2(double value) => (value * 100).roundToDouble() / 100;
  List<DecontLunarAsociereRecord> _sort(
          List<DecontLunarAsociereRecord> items) =>
      items
        ..sort((a, b) =>
            b.an == a.an ? b.luna.compareTo(a.luna) : b.an.compareTo(a.an));
}
