import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../features/product_catalog/product_catalog_models.dart';
import '../../features/product_catalog/product_catalog_service.dart';
import '../../features/product_catalog/product_sales_models.dart';
import 'field_sales_models.dart';

class FieldCommercialProductView {
  const FieldCommercialProductView({
    required this.product,
    required this.priceList,
    required this.hasPriceEntry,
    required this.salePrice,
    required this.currency,
    required this.availableStockQuantity,
    required this.allocatedStockQuantity,
  });

  final ProductCatalogRecord product;
  final PriceListRecord? priceList;
  final bool hasPriceEntry;
  final double salePrice;
  final String currency;
  final double availableStockQuantity;
  final double allocatedStockQuantity;
}

class FieldSalesService {
  FieldSalesService({
    FirebaseFirestore? firestore,
    ProductCatalogService? productCatalogService,
  })  : _firestore = firestore ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseFirestore.instance
                : null),
        _productCatalogService =
            productCatalogService ?? ProductCatalogService();

  static const String _leadsKey = 'field_sales_leads_v1';
  static const String _requestsKey = 'field_sales_requests_v1';

  final FirebaseFirestore? _firestore;
  final ProductCatalogService _productCatalogService;

  bool get _isCloudAvailable =>
      FirebaseBootstrap.isInitialized && _firestore != null;

  CollectionReference<Map<String, dynamic>> get _leadsCollection =>
      _firestore!.collection(FirebaseCollections.fieldSalesLeads);

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      _firestore!.collection(FirebaseCollections.fieldSalesRequests);

  Future<List<FieldLeadRecord>> listLeads() async {
    final localItems = await _readLocalLeadsOnly();
    if (!_isCloudAvailable) {
      return localItems..sort(_compareLeads);
    }
    try {
      var cloudItems = await _leadsCollection.get().then(
            (snapshot) => snapshot.docs
                .map((doc) => FieldLeadRecord.fromMap(doc.data()))
                .where((item) => item.id.trim().isNotEmpty)
                .toList(growable: false),
          );
      if (localItems.isNotEmpty) {
        final ids = cloudItems.map((item) => item.id).toSet();
        for (final item in localItems) {
          if (item.id.trim().isEmpty || ids.contains(item.id)) {
            continue;
          }
          await _leadsCollection.doc(item.id).set(
                item.toMap(),
                SetOptions(merge: true),
              );
          ids.add(item.id);
          cloudItems = <FieldLeadRecord>[...cloudItems, item];
        }
      }
      final merged = [...cloudItems]..sort(_compareLeads);
      await _writeLeads(merged);
      return merged;
    } catch (_) {
      return localItems..sort(_compareLeads);
    }
  }

  Future<void> saveLead(FieldLeadRecord lead) async {
    final items = [...await _readLocalLeadsOnly()];
    final index = items.indexWhere((item) => item.id == lead.id);
    final next = lead.copyWith(
      createdAt: index >= 0 ? items[index].createdAt : lead.createdAt,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      items[index] = next;
    } else {
      items.add(next);
    }
    if (_isCloudAvailable) {
      try {
        await _leadsCollection.doc(next.id).set(
              next.toMap(),
              SetOptions(merge: true),
            );
      } catch (_) {}
    }
    await _writeLeads(items..sort(_compareLeads));
  }

  Future<List<FieldSalesRequestRecord>> listRequests() async {
    final localItems = await _readLocalRequestsOnly();
    if (!_isCloudAvailable) {
      return localItems..sort(_compareRequests);
    }
    try {
      var cloudItems = await _requestsCollection.get().then(
            (snapshot) => snapshot.docs
                .map((doc) => FieldSalesRequestRecord.fromMap(doc.data()))
                .where((item) => item.id.trim().isNotEmpty)
                .toList(growable: false),
          );
      if (localItems.isNotEmpty) {
        final ids = cloudItems.map((item) => item.id).toSet();
        for (final item in localItems) {
          if (item.id.trim().isEmpty || ids.contains(item.id)) {
            continue;
          }
          await _requestsCollection.doc(item.id).set(
                item.toMap(),
                SetOptions(merge: true),
              );
          ids.add(item.id);
          cloudItems = <FieldSalesRequestRecord>[...cloudItems, item];
        }
      }
      final merged = [...cloudItems]..sort(_compareRequests);
      await _writeRequests(merged);
      return merged;
    } catch (_) {
      return localItems..sort(_compareRequests);
    }
  }

  Future<void> saveRequest(FieldSalesRequestRecord request) async {
    final items = [...await _readLocalRequestsOnly()];
    final index = items.indexWhere((item) => item.id == request.id);
    final next = request.copyWith(
      createdAt: index >= 0 ? items[index].createdAt : request.createdAt,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      items[index] = next;
    } else {
      items.add(next);
    }
    if (_isCloudAvailable) {
      try {
        await _requestsCollection.doc(next.id).set(
              next.toMap(),
              SetOptions(merge: true),
            );
      } catch (_) {}
    }
    await _writeRequests(items..sort(_compareRequests));
  }

  Future<List<FieldCommercialProductView>> buildCommercialCatalog({
    String priceListId = '',
    bool restrictToStandardOnly = false,
  }) async {
    final products = (await _productCatalogService.listProducts())
        .where((item) => item.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final allPriceLists = (await _productCatalogService.listPriceLists())
        .where((item) => item.isActive)
        .toList(growable: false);
    final standardPriceList = _resolveStandardPriceList(allPriceLists);
    final priceLists = restrictToStandardOnly
        ? (standardPriceList == null
            ? const <PriceListRecord>[]
            : <PriceListRecord>[standardPriceList])
        : allPriceLists;
    final entries = await _productCatalogService.listPriceListEntries();
    final supplierPrices = await _productCatalogService.listSupplierPrices();
    final sales = await _productCatalogService.listSales();
    PriceListRecord? selectedPriceList;
    if (restrictToStandardOnly) {
      selectedPriceList = standardPriceList;
    } else if (priceListId.trim().isNotEmpty) {
      for (final item in priceLists) {
        if (item.id == priceListId.trim()) {
          selectedPriceList = item;
          break;
        }
      }
    }
    selectedPriceList ??= priceLists.isEmpty ? null : priceLists.first;

    final views = <FieldCommercialProductView>[];
    for (final product in products) {
      PriceListEntryRecord? entry;
      if (selectedPriceList != null) {
        for (final item in entries) {
          if (item.priceListId == selectedPriceList.id &&
              item.productId == product.id) {
            entry = item;
            break;
          }
        }
      }
      final salePrice = _resolvePresentationPrice(
        entry: entry,
        supplierPrices: supplierPrices,
      );
      final allocatedStockQuantity = sales
          .where((item) =>
              item.productId == product.id &&
              (item.saleStatus == ProductSaleStatus.rezervat ||
                  item.saleStatus == ProductSaleStatus.vandut))
          .fold<double>(0, (total, _) => total + 1);
      views.add(
        FieldCommercialProductView(
          product: product,
          priceList: selectedPriceList,
          hasPriceEntry: entry != null,
          salePrice: salePrice,
          currency: selectedPriceList?.currency.trim().isNotEmpty == true
              ? selectedPriceList!.currency.trim()
              : (entry?.currency.trim().isNotEmpty == true
                  ? entry!.currency.trim()
                  : 'RON'),
          availableStockQuantity:
              product.stockQuantity - allocatedStockQuantity,
          allocatedStockQuantity: allocatedStockQuantity,
        ),
      );
    }
    return views;
  }

  PriceListRecord? resolveStandardPriceList(List<PriceListRecord> priceLists) {
    return _resolveStandardPriceList(priceLists);
  }

  String normalizeRequestedPriceListId(
    String requestedPriceListId,
    List<PriceListRecord> availablePriceLists, {
    bool restrictToStandardOnly = false,
  }) {
    final standardPriceList = _resolveStandardPriceList(availablePriceLists);
    if (restrictToStandardOnly) {
      return standardPriceList?.id ?? '';
    }
    final normalizedRequestedId = requestedPriceListId.trim();
    if (normalizedRequestedId.isEmpty) {
      return standardPriceList?.id ??
          (availablePriceLists.isNotEmpty ? availablePriceLists.first.id : '');
    }
    for (final item in availablePriceLists) {
      if (item.id == normalizedRequestedId) {
        return item.id;
      }
    }
    return standardPriceList?.id ??
        (availablePriceLists.isNotEmpty ? availablePriceLists.first.id : '');
  }

  PriceListRecord? _resolveStandardPriceList(List<PriceListRecord> priceLists) {
    for (final item in priceLists) {
      if (item.scope == PriceListScope.standard) {
        return item;
      }
    }
    for (final item in priceLists) {
      final code = item.code.trim().toLowerCase();
      final name = item.name.trim().toLowerCase();
      if (code == 'standard' || name.contains('standard')) {
        return item;
      }
    }
    return null;
  }

  double _resolvePresentationPrice({
    required PriceListEntryRecord? entry,
    required List<SupplierPriceRecord> supplierPrices,
  }) {
    if (entry == null) return 0.0;

    final referencePrice = _resolveReferenceSupplierPrice(
      productId: entry.productId,
      supplierPrices: supplierPrices,
    );
    if (referencePrice != null) {
      final cost = _productCatalogService.computeSupplierCost(referencePrice);
      final sale = _productCatalogService.computeSalePrice(
        cost: cost,
        entry: entry,
      );
      if (sale.saleGrossPrice > 0) {
        return sale.saleGrossPrice;
      }
      if (sale.saleNetPrice > 0) {
        return sale.saleNetPrice;
      }
    }

    if (entry.calculatedSaleGrossPrice > 0) {
      return entry.calculatedSaleGrossPrice;
    }
    if (entry.calculatedSaleNetPrice > 0) {
      return entry.calculatedSaleNetPrice;
    }
    if (entry.manualSalePrice > 0) {
      return entry.manualSalePrice;
    }
    return 0.0;
  }

  SupplierPriceRecord? _resolveReferenceSupplierPrice({
    required String productId,
    required List<SupplierPriceRecord> supplierPrices,
  }) {
    final matches = supplierPrices
        .where((item) => item.productId == productId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final item in matches) {
      if (_productCatalogService.isSupplierPriceActiveNow(item)) {
        return item;
      }
    }
    return matches.isEmpty ? null : matches.first;
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<FieldLeadRecord>> _readLocalLeadsOnly() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_leadsKey);
    if (raw == null || raw.trim().isEmpty) return const <FieldLeadRecord>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <FieldLeadRecord>[];
    return decoded
        .whereType<Map>()
        .map((item) => FieldLeadRecord.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> _writeLeads(List<FieldLeadRecord> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _leadsKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<FieldSalesRequestRecord>> _readLocalRequestsOnly() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_requestsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <FieldSalesRequestRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <FieldSalesRequestRecord>[];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              FieldSalesRequestRecord.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> _writeRequests(List<FieldSalesRequestRecord> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      _requestsKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  int _compareLeads(FieldLeadRecord a, FieldLeadRecord b) =>
      b.updatedAt.compareTo(a.updatedAt);

  int _compareRequests(FieldSalesRequestRecord a, FieldSalesRequestRecord b) =>
      b.updatedAt.compareTo(a.updatedAt);
}
