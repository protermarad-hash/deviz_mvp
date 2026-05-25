import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'product_catalog_cloud_repository.dart';
import 'product_catalog_models.dart';
import 'product_sales_models.dart';

class FirebaseProductCatalogRepository
    implements ProductCatalogCloudRepository {
  FirebaseProductCatalogRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection(FirebaseCollections.productCatalogProducts);

  CollectionReference<Map<String, dynamic>> get _supplierPricesCollection =>
      _firestore.collection(FirebaseCollections.productCatalogSupplierPrices);

  CollectionReference<Map<String, dynamic>> get _priceListsCollection =>
      _firestore.collection(FirebaseCollections.productCatalogPriceLists);

  CollectionReference<Map<String, dynamic>> get _priceListEntriesCollection =>
      _firestore.collection(FirebaseCollections.productCatalogPriceListEntries);

  CollectionReference<Map<String, dynamic>> get _salesCollection =>
      _firestore.collection(FirebaseCollections.productCatalogSales);

  CollectionReference<Map<String, dynamic>>
      get _warrantyCertificatesCollection => _firestore.collection(
            FirebaseCollections.productCatalogWarrantyCertificates,
          );

  @override
  Future<List<ProductCatalogRecord>> listProducts() async {
    final snapshot = await _productsCollection.get();
    final rows = snapshot.docs
        .map((doc) => ProductCatalogRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  @override
  Future<void> saveProduct(ProductCatalogRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _productsCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return;
    await _productsCollection.doc(id).delete();
  }

  @override
  Future<List<SupplierPriceRecord>> listSupplierPrices() async {
    final snapshot = await _supplierPricesCollection.get();
    final rows = snapshot.docs
        .map((doc) => SupplierPriceRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> saveSupplierPrice(SupplierPriceRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _supplierPricesCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteSupplierPrice(String supplierPriceId) async {
    final id = supplierPriceId.trim();
    if (id.isEmpty) return;
    await _supplierPricesCollection.doc(id).delete();
  }

  @override
  Future<List<PriceListRecord>> listPriceLists() async {
    final snapshot = await _priceListsCollection.get();
    final rows = snapshot.docs
        .map((doc) => PriceListRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  @override
  Future<void> savePriceList(PriceListRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _priceListsCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deletePriceList(String priceListId) async {
    final id = priceListId.trim();
    if (id.isEmpty) return;
    await _priceListsCollection.doc(id).delete();
  }

  @override
  Future<List<PriceListEntryRecord>> listPriceListEntries() async {
    final snapshot = await _priceListEntriesCollection.get();
    final rows = snapshot.docs
        .map((doc) => PriceListEntryRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> savePriceListEntry(PriceListEntryRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _priceListEntriesCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deletePriceListEntry(String entryId) async {
    final id = entryId.trim();
    if (id.isEmpty) return;
    await _priceListEntriesCollection.doc(id).delete();
  }

  @override
  Future<List<ProductSaleRecord>> listSales() async {
    final snapshot = await _salesCollection.get();
    final rows = snapshot.docs
        .map((doc) => ProductSaleRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> saveSale(ProductSaleRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _salesCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteSale(String saleId) async {
    final id = saleId.trim();
    if (id.isEmpty) return;
    await _salesCollection.doc(id).delete();
  }

  @override
  Future<List<WarrantyCertificateRecord>> listWarrantyCertificates() async {
    final snapshot = await _warrantyCertificatesCollection.get();
    final rows = snapshot.docs
        .map((doc) => WarrantyCertificateRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> saveWarrantyCertificate(WarrantyCertificateRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _warrantyCertificatesCollection.doc(id).set(
          _withUpdatedAt(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> deleteWarrantyCertificate(String certificateId) async {
    final id = certificateId.trim();
    if (id.isEmpty) return;
    await _warrantyCertificatesCollection.doc(id).delete();
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return <String, dynamic>{...raw};
  }

  Map<String, dynamic> _withUpdatedAt(Map<String, dynamic> raw) {
    return <String, dynamic>{
      ...raw,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
