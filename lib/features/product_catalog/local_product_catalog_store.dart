import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'product_catalog_models.dart';
import 'product_sales_models.dart';

class LocalProductCatalogStore {
  static const String _productsKey = 'ultra_product_catalog_products_v1';
  static const String _supplierPricesKey =
      'ultra_product_catalog_supplier_prices_v1';
  static const String _priceListsKey = 'ultra_product_catalog_price_lists_v1';
  static const String _priceListEntriesKey =
      'ultra_product_catalog_price_list_entries_v1';
  static const String _salesKey = 'ultra_product_catalog_sales_v1';
  static const String _warrantyCertificatesKey =
      'ultra_product_catalog_warranty_certificates_v1';

  Future<List<ProductCatalogRecord>> listProducts() async {
    final rows = _decodeRows(await _readKey(_productsKey));
    final items = rows
        .map(ProductCatalogRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> saveProducts(List<ProductCatalogRecord> rows) async {
    await _writeKey(
      _productsKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<SupplierPriceRecord>> listSupplierPrices() async {
    final rows = _decodeRows(await _readKey(_supplierPricesKey));
    final items = rows
        .map(SupplierPriceRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> saveSupplierPrices(List<SupplierPriceRecord> rows) async {
    await _writeKey(
      _supplierPricesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<PriceListRecord>> listPriceLists() async {
    final rows = _decodeRows(await _readKey(_priceListsKey));
    final items = rows
        .map(PriceListRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> savePriceLists(List<PriceListRecord> rows) async {
    await _writeKey(
      _priceListsKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<PriceListEntryRecord>> listPriceListEntries() async {
    final rows = _decodeRows(await _readKey(_priceListEntriesKey));
    final items = rows
        .map(PriceListEntryRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> savePriceListEntries(List<PriceListEntryRecord> rows) async {
    await _writeKey(
      _priceListEntriesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<ProductSaleRecord>> listSales() async {
    final rows = _decodeRows(await _readKey(_salesKey));
    final items = rows
        .map(ProductSaleRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> saveSales(List<ProductSaleRecord> rows) async {
    await _writeKey(
      _salesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<List<WarrantyCertificateRecord>> listWarrantyCertificates() async {
    final rows = _decodeRows(await _readKey(_warrantyCertificatesKey));
    final items = rows
        .map(WarrantyCertificateRecord.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> saveWarrantyCertificates(
    List<WarrantyCertificateRecord> rows,
  ) async {
    await _writeKey(
      _warrantyCertificatesKey,
      rows.map((item) => item.toMap()).toList(growable: false),
    );
  }

  Future<String?> _readKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _writeKey(String key, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(rows));
  }

  List<Map<String, dynamic>> _decodeRows(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }
    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
