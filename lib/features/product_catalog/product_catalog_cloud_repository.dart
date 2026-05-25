import 'product_catalog_models.dart';
import 'product_sales_models.dart';

abstract class ProductCatalogCloudRepository {
  Future<List<ProductCatalogRecord>> listProducts();
  Future<void> saveProduct(ProductCatalogRecord item);
  Future<void> deleteProduct(String productId);

  Future<List<SupplierPriceRecord>> listSupplierPrices();
  Future<void> saveSupplierPrice(SupplierPriceRecord item);
  Future<void> deleteSupplierPrice(String supplierPriceId);

  Future<List<PriceListRecord>> listPriceLists();
  Future<void> savePriceList(PriceListRecord item);
  Future<void> deletePriceList(String priceListId);

  Future<List<PriceListEntryRecord>> listPriceListEntries();
  Future<void> savePriceListEntry(PriceListEntryRecord item);
  Future<void> deletePriceListEntry(String entryId);

  Future<List<ProductSaleRecord>> listSales();
  Future<void> saveSale(ProductSaleRecord item);
  Future<void> deleteSale(String saleId);

  Future<List<WarrantyCertificateRecord>> listWarrantyCertificates();
  Future<void> saveWarrantyCertificate(WarrantyCertificateRecord item);
  Future<void> deleteWarrantyCertificate(String certificateId);
}
