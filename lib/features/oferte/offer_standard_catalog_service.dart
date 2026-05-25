import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'offer_commercial_package_models.dart';
import 'offer_standard_catalog_models.dart';

class OfferStandardCatalogService {
  static const String _laborTemplatesKey = 'offer_labor_templates_v1';
  static const String _clauseTemplatesKey = 'offer_clause_templates_v1';
  static const String _packageTemplatesKey = 'offer_package_templates_v1';

  String dataSourceLabel = 'local_cache';
  String? fallbackReason;

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  void _setCloudSource() {
    dataSourceLabel = 'cloud';
    fallbackReason = null;
  }

  void _setLocalCacheSource(String? reason) {
    dataSourceLabel = 'local_cache';
    final trimmed = (reason ?? '').trim();
    fallbackReason = trimmed.isEmpty ? null : trimmed;
  }

  List<OfferLaborTemplate> recommendedLaborTemplates() {
    final now = DateTime.now();
    return <OfferLaborTemplate>[
      OfferLaborTemplate(
        id: 'system-montaj-ac-9000-12000',
        name: 'Montaj standard AC 9000-12000 BTU',
        category: 'montaj',
        description:
            'Montaj standard pentru aparat split de perete 9000-12000 BTU.',
        unit: 'serv',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Prindere unitati, vacuumare, probe functionale si punere in functiune standard.',
        notes:
            'Completeaza pretul tau final. Agentul din teren poate modifica doar cantitatea si discountul aprobat.',
        suggestedProductKeywords:
            'aer conditionat, ac, split, inverter, 9000 btu, 12000 btu',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-montaj-ac-18000-24000',
        name: 'Montaj standard AC 18000-24000 BTU',
        category: 'montaj',
        description:
            'Montaj standard pentru aparat split de perete 18000-24000 BTU.',
        unit: 'serv',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Prindere unitati, vacuumare, probe functionale si punere in functiune standard.',
        notes: 'Ajusteaza pretul dupa politica ta comerciala pentru gama mare.',
        suggestedProductKeywords:
            'aer conditionat, ac, split, inverter, 18000 btu, 24000 btu',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-montaj-ac-multi-split',
        name: 'Montaj unitate interioara multi-split',
        category: 'montaj',
        description:
            'Serviciu dedicat pentru fiecare unitate interioara din sistem multi-split.',
        unit: 'buc',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Montaj unitate interioara, racordare, vacuumare si verificari pentru circuitul aferent.',
        notes:
            'Se foloseste pe unitate interioara; traseul frigorific se adauga separat.',
        suggestedProductKeywords:
            'multi split, multisplit, unitate interioara, aer conditionat',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-traseu-frigorific-standard',
        name: 'Traseu frigorific standard',
        category: 'traseu_frigorific',
        description:
            'Metru liniar de traseu frigorific standard pentru montaj split.',
        unit: 'ml',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Teava cupru, izolatie, cablu comanda si consumabilele standard din kitul definit de tine.',
        notes: 'Seteaza pretul standard pe ml conform structurii tale de cost.',
        suggestedProductKeywords:
            'aer conditionat, ac, split, kit instalare, traseu',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-traseu-frigorific-canal',
        name: 'Traseu frigorific cu canal mascare',
        category: 'traseu_frigorific',
        description:
            'Metru liniar de traseu frigorific executat cu canal de mascare.',
        unit: 'ml',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Traseu frigorific complet si canal PVC de mascare in varianta standard.',
        notes:
            'Separat de montajul de baza; foloseste-l cand vrei pret diferit pentru traseu aparent mascat.',
        suggestedProductKeywords:
            'aer conditionat, ac, split, canal pvc, traseu',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-pif-ac-standard',
        name: 'PIF standard aparat AC',
        category: 'pif',
        description:
            'Punere in functiune standard pentru aparat de aer conditionat.',
        unit: 'serv',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices:
            'Verificari electrice de baza, vacuumare, pornire, setari initiale si instructaj de utilizare.',
        notes:
            'Poate fi folosit separat cand montajul nu este executat de echipa ta.',
        suggestedProductKeywords:
            'aer conditionat, ac, split, pif, punere in functiune',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-servicii-baza-demontare-ac',
        name: 'Demontare aparat existent',
        category: 'servicii_baza',
        description: 'Demontarea unui aparat existent inainte de montajul nou.',
        unit: 'serv',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices: 'Demontare unitati si manipulare locala in santier.',
        notes:
            'Evacuarea aparatului vechi sau valorificarea lui se trateaza separat, daca este cazul.',
        suggestedProductKeywords:
            'aer conditionat, inlocuire, demontare, split',
        createdAt: now,
        updatedAt: now,
      ),
      OfferLaborTemplate(
        id: 'system-servicii-baza-gaurire-carota',
        name: 'Gaurire suplimentara cu carota',
        category: 'servicii_baza',
        description:
            'Executie gaurire suplimentara pentru trecere traseu sau evacuare.',
        unit: 'buc',
        defaultQuantity: 1,
        defaultUnitPrice: 0,
        isActive: true,
        includedServices: 'Executie gaurire si curatare locala de baza.',
        notes:
            'Foloseste-l separat fata de montajul standard cand situatia din teren cere lucrari suplimentare.',
        suggestedProductKeywords:
            'aer conditionat, ac, gaurire, carota, zid gros',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  Future<List<OfferLaborTemplate>> listLaborTemplates() async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    if (firestore == null) {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
      final items = await _readLaborTemplatesLocal();
      if (items.isNotEmpty) {
        return items;
      }
      return _seedRecommendedLaborTemplatesIfEmpty();
    }
    try {
      final snapshot = await firestore
          .collection(FirebaseCollections.offerLaborTemplates)
          .get();
      var items = snapshot.docs
          .map((doc) => OfferLaborTemplate.fromMap(doc.data()))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      if (items.isEmpty) {
        items = await _seedRecommendedLaborTemplatesIfEmpty(
          firestore: firestore,
        );
      }
      _setCloudSource();
      await _writeLaborTemplatesLocal(items);
      return items;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _setLocalCacheSource(_shortCloudError(error));
      final items = await _readLaborTemplatesLocal();
      if (items.isNotEmpty) {
        return items;
      }
      return _seedRecommendedLaborTemplatesIfEmpty();
    }
  }

  Future<int> mergeRecommendedLaborTemplates() async {
    final current = await listLaborTemplates();
    final existingIds = current.map((item) => item.id).toSet();
    final missing = recommendedLaborTemplates()
        .where((item) => !existingIds.contains(item.id))
        .toList(growable: false);
    for (final item in missing) {
      await upsertLaborTemplate(item);
    }
    return missing.length;
  }

  Future<void> upsertLaborTemplate(OfferLaborTemplate item) async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    final normalized = item.copyWith(updatedAt: DateTime.now());
    if (firestore != null) {
      try {
        await firestore
            .collection(FirebaseCollections.offerLaborTemplates)
            .doc(normalized.id)
            .set(normalized.toMap(), SetOptions(merge: true));
        _setCloudSource();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _setLocalCacheSource(_shortCloudError(error));
      }
    } else {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
    }

    final current = [...await _readLaborTemplatesLocal()];
    final index =
        current.indexWhere((existing) => existing.id == normalized.id);
    if (index >= 0) {
      current[index] = normalized;
    } else {
      current.add(normalized);
    }
    await _writeLaborTemplatesLocal(current);
  }

  Future<List<OfferCommercialClauseTemplate>> listClauseTemplates() async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    if (firestore == null) {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
      return _readClauseTemplatesLocal();
    }
    try {
      final snapshot = await firestore
          .collection(FirebaseCollections.offerCommercialClauseTemplates)
          .get();
      final items = snapshot.docs
          .map((doc) => OfferCommercialClauseTemplate.fromMap(doc.data()))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      _setCloudSource();
      await _writeClauseTemplatesLocal(items);
      return items;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _setLocalCacheSource(_shortCloudError(error));
      return _readClauseTemplatesLocal();
    }
  }

  Future<void> upsertClauseTemplate(OfferCommercialClauseTemplate item) async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    final normalized = item.copyWith(updatedAt: DateTime.now());
    if (firestore != null) {
      try {
        await firestore
            .collection(FirebaseCollections.offerCommercialClauseTemplates)
            .doc(normalized.id)
            .set(normalized.toMap(), SetOptions(merge: true));
        _setCloudSource();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _setLocalCacheSource(_shortCloudError(error));
      }
    } else {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
    }

    final current = [...await _readClauseTemplatesLocal()];
    final index =
        current.indexWhere((existing) => existing.id == normalized.id);
    if (index >= 0) {
      current[index] = normalized;
    } else {
      current.add(normalized);
    }
    await _writeClauseTemplatesLocal(current);
  }

  Future<List<OfferCommercialPackageTemplate>> listPackageTemplates() async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    if (firestore == null) {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
      return _readPackageTemplatesLocal();
    }
    try {
      final snapshot = await firestore
          .collection(FirebaseCollections.offerCommercialPackageTemplates)
          .get();
      final items = snapshot.docs
          .map((doc) => OfferCommercialPackageTemplate.fromMap(doc.data()))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      _setCloudSource();
      await _writePackageTemplatesLocal(items);
      return items;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _setLocalCacheSource(_shortCloudError(error));
      return _readPackageTemplatesLocal();
    }
  }

  Future<void> upsertPackageTemplate(
      OfferCommercialPackageTemplate item) async {
    final firestore =
        FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null;
    final normalized = item.copyWith(updatedAt: DateTime.now());
    if (firestore != null) {
      try {
        await firestore
            .collection(FirebaseCollections.offerCommercialPackageTemplates)
            .doc(normalized.id)
            .set(normalized.toMap(), SetOptions(merge: true));
        _setCloudSource();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _setLocalCacheSource(_shortCloudError(error));
      }
    } else {
      _setLocalCacheSource(FirebaseBootstrap.lastErrorMessage);
    }

    final current = [...await _readPackageTemplatesLocal()];
    final index =
        current.indexWhere((existing) => existing.id == normalized.id);
    if (index >= 0) {
      current[index] = normalized;
    } else {
      current.add(normalized);
    }
    await _writePackageTemplatesLocal(current);
  }

  Future<List<OfferLaborTemplate>> _readLaborTemplatesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_laborTemplatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OfferLaborTemplate>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <OfferLaborTemplate>[];
    return decoded
        .whereType<Map>()
        .map(
            (row) => OfferLaborTemplate.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _writeLaborTemplatesLocal(List<OfferLaborTemplate> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _laborTemplatesKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<OfferLaborTemplate>> _seedRecommendedLaborTemplatesIfEmpty({
    FirebaseFirestore? firestore,
  }) async {
    final recommended = recommendedLaborTemplates();
    final targetFirestore = firestore ??
        (FirebaseBootstrap.isInitialized ? FirebaseFirestore.instance : null);
    if (targetFirestore != null) {
      for (final item in recommended) {
        try {
          await targetFirestore
              .collection(FirebaseCollections.offerLaborTemplates)
              .doc(item.id)
              .set(item.toMap(), SetOptions(merge: true));
        } catch (error) {
          FirebaseBootstrap.registerRuntimeError(error);
          _setLocalCacheSource(_shortCloudError(error));
        }
      }
    }
    await _writeLaborTemplatesLocal(recommended);
    return recommended;
  }

  Future<List<OfferCommercialClauseTemplate>>
      _readClauseTemplatesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clauseTemplatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OfferCommercialClauseTemplate>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <OfferCommercialClauseTemplate>[];
    return decoded
        .whereType<Map>()
        .map(
          (row) => OfferCommercialClauseTemplate.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _writeClauseTemplatesLocal(
    List<OfferCommercialClauseTemplate> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clauseTemplatesKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<OfferCommercialPackageTemplate>>
      _readPackageTemplatesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_packageTemplatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OfferCommercialPackageTemplate>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <OfferCommercialPackageTemplate>[];
    }
    return decoded
        .whereType<Map>()
        .map(
          (row) => OfferCommercialPackageTemplate.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _writePackageTemplatesLocal(
    List<OfferCommercialPackageTemplate> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _packageTemplatesKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
