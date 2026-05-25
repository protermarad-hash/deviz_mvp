import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_product_catalog_repository.dart';
import 'local_product_catalog_store.dart';
import 'product_catalog_cloud_repository.dart';
import 'product_catalog_models.dart';
import 'product_sales_models.dart';

/// Rounds a price UP to the nearest 10
/// Examples: 1919.45 -> 1920, 2510.08 -> 2520, 1000 -> 1000
double _roundPriceUpToTen(double price) {
  if (price <= 0) return price;
  return ((price / 10).ceil() * 10).toDouble();
}

class ProductCatalogService {
  ProductCatalogService({
    ProductCatalogCloudRepository? cloudRepository,
    LocalProductCatalogStore? localStore,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseProductCatalogRepository()
                : null),
        _localStore = localStore ?? LocalProductCatalogStore();

  final ProductCatalogCloudRepository? _cloudRepository;
  final LocalProductCatalogStore _localStore;

  String dataSourceLabel = 'local_cache';
  String? fallbackReason;

  static final List<PriceListRecord> _defaultPriceLists = <PriceListRecord>[
    PriceListRecord(
      id: 'catalog_pricelist_standard',
      name: 'Lista standard',
      code: 'STANDARD',
      scope: PriceListScope.standard,
      currency: 'RON',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    PriceListRecord(
      id: 'catalog_pricelist_collaborator',
      name: 'Lista colaborator',
      code: 'COLAB',
      scope: PriceListScope.collaborator,
      currency: 'RON',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    PriceListRecord(
      id: 'catalog_pricelist_dedicated_client',
      name: 'Lista client dedicat',
      code: 'CLIENT',
      scope: PriceListScope.dedicatedClient,
      currency: 'RON',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  static const String defaultWarrantyTerms = '''
Condițiile de garanție se aplică produsului instalat și utilizat conform instrucțiunilor producătorului.
Garanția comercială acoperă defectele de fabricație apărute în perioada declarată, în condițiile unei exploatări normale.
Intervențiile efectuate de persoane neautorizate, utilizarea improprie, alimentarea electrică necorespunzătoare sau lipsa întreținerii pot conduce la pierderea garanției.
Beneficiarul are obligația să păstreze documentele de achiziție și prezentul certificat pentru orice solicitare de garanție.
Operațiunile de service și punere în funcțiune se consemnează în taloanele de service ale certificatului.
''';

  void _markCloud() {
    dataSourceLabel = 'cloud';
    fallbackReason = null;
  }

  void _markLocalFallback([Object? error]) {
    dataSourceLabel = 'local_cache';
    fallbackReason =
        error == null ? 'cloud indisponibil' : _shortCloudError(error);
  }

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  Future<List<ProductCatalogRecord>> listProducts() async {
    final localRows = await _localStore.listProducts();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listProducts();
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.saveProduct(row);
          }
        }
        cloudRows = await cloud.listProducts();
      }
      _markCloud();
      await _localStore.saveProducts(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveProduct(ProductCatalogRecord item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveProduct(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listProducts()];
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      rows[index] = item;
    } else {
      rows.add(item);
    }
    await _localStore.saveProducts(rows);
  }

  Future<void> deleteProduct(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteProduct(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }

    final rows = [...await _localStore.listProducts()]
      ..removeWhere((row) => row.id == id);
    await _localStore.saveProducts(rows);

    final supplierPrices = [...await _localStore.listSupplierPrices()]
      ..removeWhere((row) => row.productId == id);
    await _localStore.saveSupplierPrices(supplierPrices);

    final entries = [...await _localStore.listPriceListEntries()]
      ..removeWhere((row) => row.productId == id);
    await _localStore.savePriceListEntries(entries);
  }

  Future<List<SupplierPriceRecord>> listSupplierPrices() async {
    final localRows = await _localStore.listSupplierPrices();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listSupplierPrices();
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.saveSupplierPrice(row);
          }
        }
        cloudRows = await cloud.listSupplierPrices();
      }
      _markCloud();
      await _localStore.saveSupplierPrices(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveSupplierPrice(SupplierPriceRecord item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveSupplierPrice(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listSupplierPrices()];
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      rows[index] = item;
    } else {
      rows.add(item);
    }
    await _localStore.saveSupplierPrices(rows);
  }

  Future<void> deleteSupplierPrice(String supplierPriceId) async {
    final id = supplierPriceId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteSupplierPrice(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listSupplierPrices()]
      ..removeWhere((row) => row.id == id);
    await _localStore.saveSupplierPrices(rows);
  }

  Future<List<PriceListRecord>> listPriceLists() async {
    var localRows = await _localStore.listPriceLists();
    if (localRows.isEmpty) {
      localRows = _defaultPriceLists;
      await _localStore.savePriceLists(localRows);
    }

    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listPriceLists();
      if (cloudRows.isEmpty) {
        for (final item in _defaultPriceLists) {
          await cloud.savePriceList(item);
        }
        cloudRows = await cloud.listPriceLists();
      }
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.savePriceList(row);
          }
        }
        cloudRows = await cloud.listPriceLists();
      }
      _markCloud();
      await _localStore.savePriceLists(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> savePriceList(PriceListRecord item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.savePriceList(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listPriceLists()];
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      rows[index] = item;
    } else {
      rows.add(item);
    }
    await _localStore.savePriceLists(rows);
  }

  Future<void> deletePriceList(String priceListId) async {
    final id = priceListId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deletePriceList(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listPriceLists()]
      ..removeWhere((row) => row.id == id);
    await _localStore.savePriceLists(rows);
    final entries = [...await _localStore.listPriceListEntries()]
      ..removeWhere((row) => row.priceListId == id);
    await _localStore.savePriceListEntries(entries);
  }

  Future<List<PriceListEntryRecord>> listPriceListEntries() async {
    final localRows = await _localStore.listPriceListEntries();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listPriceListEntries();
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.savePriceListEntry(row);
          }
        }
        cloudRows = await cloud.listPriceListEntries();
      }
      _markCloud();
      await _localStore.savePriceListEntries(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> savePriceListEntry(PriceListEntryRecord item) async {
    final hydratedItem = await _hydratePriceListEntry(item);
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.savePriceListEntry(hydratedItem);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listPriceListEntries()];
    final index = rows.indexWhere((row) => row.id == hydratedItem.id);
    if (index >= 0) {
      rows[index] = hydratedItem;
    } else {
      rows.add(hydratedItem);
    }
    await _localStore.savePriceListEntries(rows);
  }

  Future<void> deletePriceListEntry(String entryId) async {
    final id = entryId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deletePriceListEntry(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listPriceListEntries()]
      ..removeWhere((row) => row.id == id);
    await _localStore.savePriceListEntries(rows);
  }

  Future<List<ProductSaleRecord>> listSales() async {
    final localRows = await _localStore.listSales();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listSales();
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.saveSale(row);
          }
        }
        cloudRows = await cloud.listSales();
      }
      _markCloud();
      await _localStore.saveSales(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveSale(ProductSaleRecord item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveSale(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listSales()];
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      rows[index] = item;
    } else {
      rows.add(item);
    }
    await _localStore.saveSales(rows);
  }

  Future<void> deleteSale(String saleId) async {
    final id = saleId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteSale(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listSales()]
      ..removeWhere((row) => row.id == id);
    await _localStore.saveSales(rows);
  }

  Future<List<WarrantyCertificateRecord>> listWarrantyCertificates() async {
    final localRows = await _localStore.listWarrantyCertificates();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listWarrantyCertificates();
      if (localRows.isNotEmpty) {
        final ids = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!ids.contains(row.id)) {
            await cloud.saveWarrantyCertificate(row);
          }
        }
        cloudRows = await cloud.listWarrantyCertificates();
      }
      _markCloud();
      await _localStore.saveWarrantyCertificates(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveWarrantyCertificate(WarrantyCertificateRecord item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveWarrantyCertificate(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listWarrantyCertificates()];
    final index = rows.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      rows[index] = item;
    } else {
      rows.add(item);
    }
    await _localStore.saveWarrantyCertificates(rows);
  }

  Future<void> deleteWarrantyCertificate(String certificateId) async {
    final id = certificateId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteWarrantyCertificate(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final rows = [...await _localStore.listWarrantyCertificates()]
      ..removeWhere((row) => row.id == id);
    await _localStore.saveWarrantyCertificates(rows);
  }

  ({String series, String number}) nextCertificateIdentity(
    List<WarrantyCertificateRecord> existing, {
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final series = 'CG-${anchor.year}';
    var max = 0;
    for (final item in existing) {
      if (item.certificateSeries.trim().toUpperCase() != series.toUpperCase()) {
        continue;
      }
      final parsed = int.tryParse(item.certificateNumber.trim());
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return (
      series: series,
      number: (max + 1).toString().padLeft(4, '0'),
    );
  }

  DateTime? effectiveWarrantyStartDate(WarrantyCertificateRecord certificate) {
    return certificate.warrantyStartDate ??
        certificate.installationDate ??
        certificate.saleDate ??
        certificate.documentDate;
  }

  DateTime? effectiveWarrantyEndDate(WarrantyCertificateRecord certificate) {
    if (certificate.warrantyEndDate != null) {
      return certificate.warrantyEndDate;
    }
    final startDate = effectiveWarrantyStartDate(certificate);
    if (startDate == null || certificate.warrantyMonths <= 0) {
      return null;
    }
    return DateTime(
      startDate.year,
      startDate.month + certificate.warrantyMonths,
      startDate.day,
    );
  }

  WarrantyCoverageStatus coverageStatusForCertificate(
    WarrantyCertificateRecord certificate, {
    DateTime? now,
  }) {
    final startDate = effectiveWarrantyStartDate(certificate);
    final endDate = effectiveWarrantyEndDate(certificate);
    if (startDate == null || endDate == null) {
      return WarrantyCoverageStatus.unknown;
    }
    final anchor = now ?? DateTime.now();
    return anchor.isAfter(endDate)
        ? WarrantyCoverageStatus.postWarranty
        : WarrantyCoverageStatus.inWarranty;
  }

  SupplierCostBreakdown computeSupplierCost(SupplierPriceRecord item) {
    final basePrice = item.basePrice < 0 ? 0.0 : item.basePrice;
    final percentDiscountValue =
        basePrice * (item.supplierDiscountPercent / 100);
    final discountValue = item.supplierDiscountValue > 0
        ? item.supplierDiscountValue
        : percentDiscountValue;
    final appliedDiscount = discountValue.clamp(0, basePrice).toDouble();
    final discountedPrice =
        (basePrice - appliedDiscount).clamp(0, double.infinity).toDouble();
    final vatValueIncluded = item.priceIncludesVat && item.vatPercent > 0
        ? discountedPrice - (discountedPrice / (1 + item.vatPercent / 100))
        : 0.0;
    final netSupplierCost = item.priceIncludesVat && item.vatPercent > 0
        ? discountedPrice / (1 + item.vatPercent / 100)
        : discountedPrice;
    final greenStampCost = item.greenStampIncluded ? 0.0 : item.greenStampValue;
    final transportCost = item.transportIncluded ? 0.0 : item.transportValue;
    final finalEntryCost =
        netSupplierCost + greenStampCost + transportCost + item.otherCostValue;

    return SupplierCostBreakdown(
      baseSupplierPrice: basePrice,
      discountValueApplied: appliedDiscount,
      discountedPrice: discountedPrice,
      netSupplierCost: netSupplierCost,
      greenStampCost: greenStampCost,
      transportCost: transportCost,
      otherCosts: item.otherCostValue,
      finalEntryCost: finalEntryCost,
      vatValueIncluded: vatValueIncluded,
    );
  }

  SalePriceBreakdown computeSalePrice({
    required SupplierCostBreakdown cost,
    required PriceListEntryRecord entry,
  }) {
    final costValue = cost.finalEntryCost < 0 ? 0.0 : cost.finalEntryCost;
    final configValue = entry.pricingValue < 0 ? 0.0 : entry.pricingValue;
    var saleNet = entry.manualSalePrice > 0 ? entry.manualSalePrice : costValue;

    switch (entry.pricingMode) {
      case SalePricingMode.markupPercent:
        saleNet = costValue + (costValue * configValue / 100);
        break;
      case SalePricingMode.markupValue:
        saleNet = costValue + configValue;
        break;
      case SalePricingMode.targetProfitValue:
        saleNet = costValue + configValue;
        break;
      case SalePricingMode.targetProfitPercent:
        if (entry.percentageBasis == PercentageBasis.onSalePrice) {
          final marginPercent = configValue.clamp(0, 99.99).toDouble();
          saleNet = marginPercent >= 100
              ? costValue
              : costValue / (1 - marginPercent / 100);
        } else {
          saleNet = costValue + (costValue * configValue / 100);
        }
        break;
    }

    if (entry.manualSalePrice > 0) {
      saleNet = entry.manualSalePrice;
    }

    // Round final prices UP to nearest 10
    saleNet = _roundPriceUpToTen(saleNet);

    final saleGross = entry.priceIncludesVat && entry.vatPercent > 0
        ? _roundPriceUpToTen(saleNet * (1 + entry.vatPercent / 100))
        : saleNet;
    final profitValue = saleNet - costValue;
    final profitPercentOnCost =
        costValue <= 0 ? 0.0 : (profitValue / costValue) * 100;

    return SalePriceBreakdown(
      costBeforePricing: costValue,
      saleNetPrice: saleNet,
      saleGrossPrice: saleGross,
      profitValue: profitValue,
      profitPercentOnCost: profitPercentOnCost,
      pricingMode: entry.pricingMode,
      pricingValue: configValue,
    );
  }

  bool isSupplierPriceActiveNow(SupplierPriceRecord item, {DateTime? now}) {
    final anchor = now ?? DateTime.now();
    if (item.validFrom != null && item.validFrom!.isAfter(anchor)) {
      return false;
    }
    if (item.validTo != null) {
      final validToInclusiveEnd = DateTime(
        item.validTo!.year,
        item.validTo!.month,
        item.validTo!.day,
        23,
        59,
        59,
        999,
      );
      if (validToInclusiveEnd.isBefore(anchor)) {
        return false;
      }
    }
    return true;
  }

  Future<PriceListEntryRecord> _hydratePriceListEntry(
    PriceListEntryRecord item,
  ) async {
    final referencePrice = await _referencePriceForProduct(item.productId);
    if (referencePrice == null) {
      return item.copyWith(
        referenceSupplierPriceId: '',
        referenceSupplierCost: 0,
        calculatedSaleNetPrice: 0,
        calculatedSaleGrossPrice: 0,
        calculatedProfitValue: 0,
        calculatedProfitPercentOnCost: 0,
        updatedAt: DateTime.now(),
      );
    }
    final cost = computeSupplierCost(referencePrice);
    final sale = computeSalePrice(cost: cost, entry: item);
    return item.copyWith(
      referenceSupplierPriceId: referencePrice.id,
      referenceSupplierCost: cost.finalEntryCost,
      calculatedSaleNetPrice: sale.saleNetPrice,
      calculatedSaleGrossPrice: sale.saleGrossPrice,
      calculatedProfitValue: sale.profitValue,
      calculatedProfitPercentOnCost: sale.profitPercentOnCost,
      updatedAt: DateTime.now(),
    );
  }

  Future<SupplierPriceRecord?> _referencePriceForProduct(
      String productId) async {
    final rows = (await listSupplierPrices())
        .where((item) => item.productId == productId)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final row in rows) {
      if (isSupplierPriceActiveNow(row)) {
        return row;
      }
    }
    return rows.isEmpty ? null : rows.first;
  }
}
