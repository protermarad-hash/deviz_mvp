import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../notifications/send_document_dialog.dart';
import '../notifications/document_email_templates.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_models.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/company_profile.dart';
import '../../core/document_file_service.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_viewport_guard.dart';
import '../clients/client_models.dart';
import '../partners/partner_models.dart';
import '../registratura/registry_models.dart';
import 'product_catalog_models.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';
import 'product_catalog_pricelist_pdf_service.dart';
import 'product_catalog_service.dart';
import 'product_sales_models.dart';
import 'warranty_certificate_pdf_service.dart';

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage>
    with SingleTickerProviderStateMixin {
  static const int _maxInlineAttachmentBytes = 550 * 1024;
  final ProductCatalogService _service = ProductCatalogService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  double _defaultVatPercent = 21.0;
  List<ProductCatalogRecord> _products = const <ProductCatalogRecord>[];
  List<SupplierPriceRecord> _supplierPrices = const <SupplierPriceRecord>[];
  List<PriceListRecord> _priceLists = const <PriceListRecord>[];
  List<PriceListEntryRecord> _priceListEntries = const <PriceListEntryRecord>[];
  List<PartnerRecord> _suppliers = const <PartnerRecord>[];
  List<ProductSaleRecord> _sales = const <ProductSaleRecord>[];
  List<WarrantyCertificateRecord> _certificates =
      const <WarrantyCertificateRecord>[];
  List<ClientRecord> _clients = const <ClientRecord>[];
  String _categoryFilter = '';
  String? _selectedProductId;
  bool _filtersVisible = false;

  // Liste de prețuri rapide
  late final TabController _tabController;
  int _priceListMode = 0; // 0=pachete, 1=produse, 2=servicii
  String _capacityFilter = ''; // buton rapid de capacitate

  /// Mapare cod categorie → nume complet pentru afișare
  static String _categoryDisplayName(String code) {
    const map = <String, String>{
      'AP': 'Aparate AC',
      'AR': 'Accesorii Refrigerare',
      'AT': 'Accesorii Tehnice',
      'AF': 'Accesorii Frigorifice',
    };
    return map[code.trim().toUpperCase()] ?? code;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_categoryFilter.isNotEmpty) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _service.listProducts(),
      _service.listSupplierPrices(),
      _service.listPriceLists(),
      _service.listPriceListEntries(),
      _service.listSales(),
      _service.listWarrantyCertificates(),
      widget.repository.listPartners(),
      widget.repository.listClients(),
      widget.repository.loadCompanyProfile(),
    ]);

    if (!mounted) return;
    final products = results[0] as List<ProductCatalogRecord>;
    final companyProfile = results[8] as CompanyProfile;
    final selectedId = _selectedProductId;
    final resolvedSelected =
        selectedId != null && products.any((item) => item.id == selectedId)
            ? selectedId
            : (products.isEmpty ? null : products.first.id);
    setState(() {
      _products = products;
      _supplierPrices = results[1] as List<SupplierPriceRecord>;
      _priceLists = results[2] as List<PriceListRecord>;
      _priceListEntries = results[3] as List<PriceListEntryRecord>;
      _sales = results[4] as List<ProductSaleRecord>;
      _certificates = results[5] as List<WarrantyCertificateRecord>;
      _suppliers = results[6] as List<PartnerRecord>;
      _clients = results[7] as List<ClientRecord>;
      _defaultVatPercent = companyProfile.defaultVatPercent;
      _selectedProductId = resolvedSelected;
      _loading = false;
    });
  }

  List<String> get _categories {
    final values = _products
        .map((item) => item.category.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _brands {
    final values = _products
        .map((item) => item.brand.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _models {
    final values = _products
        .map((item) => item.model.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _capacities {
    final predefined = <String>[
      '1 kW',
      '2 kW',
      '3 kW',
      '5 kW',
      '7 kW',
      '9 kW',
      '10 kW',
      '12 kW',
      '15 kW',
      '18 kW',
      '2000 BTU',
      '3000 BTU',
      '5000 BTU',
      '7000 BTU',
      '9000 BTU',
      '12000 BTU',
      '15000 BTU',
      '18000 BTU',
      '24000 BTU',
    ];
    final fromProducts = _products
        .map((item) => item.capacity.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final merged = <String>[
      ...predefined,
      ...fromProducts.where((item) => !predefined.contains(item)),
    ];
    merged.sort();
    return merged;
  }

  List<ProductCatalogRecord> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((item) {
      if (_categoryFilter.isNotEmpty && item.category != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query) ||
          item.sku.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.capacity.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  ProductCatalogRecord? get _selectedProduct {
    final id = _selectedProductId;
    if (id == null) return null;
    for (final item in _products) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<SupplierPriceRecord> _pricesForProduct(String productId) {
    final rows = _supplierPrices
        .where((item) => item.productId == productId)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  SupplierPriceRecord? _referencePriceForProduct(String productId) {
    final rows = _pricesForProduct(productId);
    for (final row in rows) {
      if (_service.isSupplierPriceActiveNow(row)) {
        return row;
      }
    }
    return rows.isEmpty ? null : rows.first;
  }

  SalePriceBreakdown? _resolvedSaleBreakdown({
    required PriceListEntryRecord? entry,
    required SupplierCostBreakdown? referenceCost,
  }) {
    if (entry == null) {
      return null;
    }
    if (referenceCost != null) {
      return _service.computeSalePrice(cost: referenceCost, entry: entry);
    }
    if (entry.calculatedSaleNetPrice <= 0 &&
        entry.calculatedSaleGrossPrice <= 0 &&
        entry.referenceSupplierCost <= 0) {
      return null;
    }
    return SalePriceBreakdown(
      costBeforePricing: entry.referenceSupplierCost,
      saleNetPrice: entry.calculatedSaleNetPrice,
      saleGrossPrice: entry.calculatedSaleGrossPrice,
      profitValue: entry.calculatedProfitValue,
      profitPercentOnCost: entry.calculatedProfitPercentOnCost,
      pricingMode: entry.pricingMode,
      pricingValue: entry.pricingValue,
    );
  }

  PriceListEntryRecord? _entryFor(String priceListId, String productId) {
    for (final item in _priceListEntries) {
      if (item.priceListId == priceListId && item.productId == productId) {
        return item;
      }
    }
    return null;
  }

  List<ProductSaleRecord> _salesForProduct(String productId) {
    final rows = _sales
        .where((item) => item.productId == productId)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  double _allocatedStockForProduct(String productId) {
    return _salesForProduct(productId)
        .where((item) =>
            item.saleStatus == ProductSaleStatus.rezervat ||
            item.saleStatus == ProductSaleStatus.vandut)
        .fold<double>(0, (sum, _) => sum + 1);
  }

  double _availableStockForProduct(ProductCatalogRecord product) {
    return product.stockQuantity - _allocatedStockForProduct(product.id);
  }

  Future<void> _adjustProductStock(ProductCatalogRecord product) async {
    final adjusted = await showDialog<ProductCatalogRecord>(
      context: context,
      builder: (context) => _ProductStockAdjustDialog(product: product),
    );
    if (adjusted == null) return;
    await _service.saveProduct(adjusted);
    await _load();
  }

  WarrantyCertificateRecord? _certificateForSale(ProductSaleRecord sale) {
    for (final item in _certificates) {
      if (sale.warrantyCertificateId.trim().isNotEmpty &&
          item.id == sale.warrantyCertificateId) {
        return item;
      }
      if (item.saleId == sale.id) {
        return item;
      }
    }
    return null;
  }

  ClientRecord? _clientById(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) return null;
    for (final item in _clients) {
      if (item.id == id) return item;
    }
    return null;
  }

  PartnerRecord? _partnerById(String partnerId) {
    final id = partnerId.trim();
    if (id.isEmpty) return null;
    for (final item in _suppliers) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _generateCatalogPdf({
    required bool share,
    bool saveAs = false,
  }) async {
    if (_priceLists.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu exista liste comerciale definite pentru catalog.'),
        ),
      );
      return;
    }

    final request = await showDialog<_CatalogPdfRequest>(
      context: context,
      builder: (context) => _CatalogPdfDialog(
        priceLists: _priceLists,
        products: _products,
        filteredProductIds: _filteredProducts.map((item) => item.id).toSet(),
        initiallySelectedProductId: _selectedProductId,
      ),
    );
    if (request == null) {
      return;
    }

    final selectedProducts = _products
        .where((item) => request.productIds.contains(item.id) && item.isActive)
        .toList(growable: false);
    if (selectedProducts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu exista produse active selectate pentru PDF.'),
        ),
      );
      return;
    }

    final items = selectedProducts.map((product) {
      final entry = _entryFor(request.priceList.id, product.id);
      final referencePrice = _referencePriceForProduct(product.id);
      final referenceCost = referencePrice == null
          ? null
          : _service.computeSupplierCost(referencePrice);
      final sale = _resolvedSaleBreakdown(
        entry: entry,
        referenceCost: referenceCost,
      );
      final firstImage = product.imagePaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .fold<String>(
              '', (previous, path) => previous.isEmpty ? path : previous);
      final firstPdf = product.pdfPaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .fold<String>(
              '', (previous, path) => previous.isEmpty ? path : previous);
      return ProductCatalogPricelistPdfItem(
        productName: product.name,
        category: product.category,
        brand: product.brand,
        model: product.model,
        capacity: product.capacity,
        sku: product.sku,
        commercialDescription: product.commercialDescription.trim().isNotEmpty
            ? product.commercialDescription
            : product.description,
        priceLabel: sale == null
            ? 'Pret la cerere'
            : _formatMoney(
                sale.saleGrossPrice > 0
                    ? sale.saleGrossPrice
                    : sale.saleNetPrice,
                entry?.currency ?? request.priceList.currency,
              ),
        imagePath: firstImage,
        pdfReferenceLabel: firstPdf.isEmpty ? '' : _fileNameFromPath(firstPdf),
      );
    }).toList(growable: false);

    try {
      final filePath = await ProductCatalogPricelistPdfService.export(
        repository: widget.repository,
        priceList: request.priceList,
        items: items,
        saveAs: saveAs,
      );
      await widget.repository.registerGeneratedDocument(
        registryType: RegistryType.iesire,
        documentCategory: 'Catalog produse',
        documentTitle: 'Catalog comercial ${request.priceList.name}',
        documentNumber:
            'CAT-${request.priceList.id}-${DateTime.now().millisecondsSinceEpoch}',
        documentDate: DateTime.now(),
        issuerName: (await widget.repository.loadCompanyProfile()).companyName,
        recipientName: request.priceList.clientName.trim().isNotEmpty
            ? request.priceList.clientName
            : request.priceList.collaboratorName,
        filePath: filePath,
        fileName: _fileNameFromPath(filePath),
        notes:
            'Catalog / lista de pret generata din modulul Catalog produse pentru ${items.length} produse.',
        status: 'emis',
      );
      if (share) {
        await DocumentFileService.shareFile(
          filePath,
          subject: 'Catalog produse - ${request.priceList.name}',
          text: 'Catalog comercial generat din aplicatie.',
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalog PDF generat.')),
      );
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: filePath,
        title: 'Catalog produse PDF generat',
        shareSubject: 'Catalog produse',
        shareText: 'Catalog comercial generat din aplicație.',
      );
    } on PdfSaveCanceledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea catalogului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nu am putut genera catalogul PDF: $error'),
        ),
      );
    }
  }

  Future<void> _editProduct({ProductCatalogRecord? existing}) async {
    final saved = await showDialog<ProductCatalogRecord>(
      context: context,
      builder: (context) => _ProductDialog(
        existing: existing,
        existingCategories: _categories,
        existingBrands: _brands,
        existingModels: _models,
        existingCapacities: _capacities,
      ),
    );
    if (saved == null) return;
    await _service.saveProduct(saved);
    await _load();
  }

  Future<void> _deleteProduct(ProductCatalogRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere produs'),
        content: Text('Stergi produsul ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteProduct(item.id);
    await _load();
  }

  Future<void> _editSupplierPrice(ProductCatalogRecord product,
      {SupplierPriceRecord? existing}) async {
    final saved = await showDialog<SupplierPriceRecord>(
      context: context,
      builder: (context) => _SupplierPriceDialog(
        product: product,
        suppliers: _suppliers,
        existing: existing,
        defaultVatPercent: _defaultVatPercent,
      ),
    );
    if (saved == null) return;
    await _service.saveSupplierPrice(saved);
    await _load();
  }

  Future<void> _deleteSupplierPrice(SupplierPriceRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere preț furnizor'),
        content: Text(
          'Stergi inregistrarea de pret pentru ${item.supplierName.isEmpty ? 'furnizor' : item.supplierName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteSupplierPrice(item.id);
    await _load();
  }

  Future<void> _editSale(
    ProductCatalogRecord product, {
    ProductSaleRecord? existing,
  }) async {
    final saved = await showDialog<ProductSaleRecord>(
      context: context,
      builder: (context) => _SaleDialog(
        product: product,
        clients: _clients,
        partners: _suppliers,
        existing: existing,
      ),
    );
    if (saved == null) return;
    await _service.saveSale(saved);
    await _load();
  }

  Future<void> _deleteSale(ProductSaleRecord sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere vânzare'),
        content: Text('Stergi vanzarea pentru ${sale.productName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final certificate = _certificateForSale(sale);
    if (certificate != null) {
      await _service.deleteWarrantyCertificate(certificate.id);
    }
    await _service.deleteSale(sale.id);
    await _load();
  }

  Future<WarrantyCertificateRecord> _buildPrefilledCertificate({
    required ProductSaleRecord sale,
    required ProductCatalogRecord product,
    WarrantyCertificateRecord? existing,
  }) async {
    final now = DateTime.now();
    final identity = existing == null
        ? _service.nextCertificateIdentity(_certificates, now: now)
        : (
            series: existing.certificateSeries,
            number: existing.certificateNumber,
          );
    final company = await widget.repository.loadCompanyProfile();
    final client = _clientById(sale.clientId);
    final installerPartner = sale.installerType == InstallerType.partner
        ? _partnerById(sale.installerPartnerId)
        : null;

    String companyDisplayName(CompanyProfile item) {
      if (item.companyName.trim().isNotEmpty) return item.companyName.trim();
      return item.contactName.trim();
    }

    String buildClientAddress(ClientRecord? item) {
      if (item == null) return '';
      final parts = <String>[
        item.address.trim(),
        item.city.trim(),
        item.county.trim(),
      ]..removeWhere((part) => part.isEmpty);
      return parts.join(', ');
    }

    String buildPartnerAddress(PartnerRecord? item) {
      if (item == null) return '';
      final parts = <String>[
        item.address.trim(),
        item.city.trim(),
        item.county.trim(),
      ]..removeWhere((part) => part.isEmpty);
      return parts.join(', ');
    }

    final defaultSellerName = companyDisplayName(company);
    final defaultBuyerName = client?.name.trim().isNotEmpty == true
        ? client!.name.trim()
        : sale.clientName.trim();
    final defaultInstallerName = sale.installerType == InstallerType.ownCompany
        ? (sale.installerDisplayName.trim().isNotEmpty
            ? sale.installerDisplayName.trim()
            : defaultSellerName)
        : (sale.installerDisplayName.trim().isNotEmpty
            ? sale.installerDisplayName.trim()
            : installerPartner?.name.trim() ?? '');

    return WarrantyCertificateRecord(
      id: existing?.id ?? 'warranty-certificate-${now.microsecondsSinceEpoch}',
      saleId: sale.id,
      sourceType: existing?.sourceType ?? WarrantyCertificateSourceType.sale,
      jobId: existing?.jobId ?? '',
      jobTitle: existing?.jobTitle ?? '',
      sourceEquipmentId: existing?.sourceEquipmentId ?? product.id,
      sourceEquipmentLabel:
          existing?.sourceEquipmentLabel ?? product.name.trim(),
      certificateSeries: identity.series.trim(),
      certificateNumber: identity.number.trim(),
      documentDate: existing?.documentDate ?? now,
      equipmentType: existing?.equipmentType ?? product.category.trim(),
      brand: existing?.brand ?? product.brand.trim(),
      model: existing?.model ?? product.model.trim(),
      serialNumberIndoor:
          existing?.serialNumberIndoor ?? sale.serialNumberIndoor.trim(),
      serialNumberOutdoor:
          existing?.serialNumberOutdoor ?? sale.serialNumberOutdoor.trim(),
      invoiceNumber: existing?.invoiceNumber ?? sale.invoiceNumber.trim(),
      saleDate: existing?.saleDate ?? sale.saleDate,
      warrantyMonths: existing?.warrantyMonths ?? sale.warrantyMonths,
      warrantyStartDate: existing?.warrantyStartDate ?? sale.saleDate ?? now,
      warrantyEndDate: existing?.warrantyEndDate ??
          DateTime(
            (existing?.warrantyStartDate ?? sale.saleDate ?? now).year,
            (existing?.warrantyStartDate ?? sale.saleDate ?? now).month +
                (existing?.warrantyMonths ?? sale.warrantyMonths),
            (existing?.warrantyStartDate ?? sale.saleDate ?? now).day,
          ),
      sellerName: existing?.sellerName ?? defaultSellerName,
      sellerAddress: existing?.sellerAddress ?? company.address.trim(),
      sellerEmail: existing?.sellerEmail ?? company.email.trim(),
      sellerPhone: existing?.sellerPhone ?? company.phone.trim(),
      sellerTaxId: existing?.sellerTaxId ?? company.cui.trim(),
      buyerClientId: existing?.buyerClientId ?? sale.clientId,
      buyerName: existing?.buyerName ?? defaultBuyerName,
      buyerAddress: existing?.buyerAddress ?? buildClientAddress(client),
      buyerPhone: existing?.buyerPhone ?? client?.phone.trim() ?? '',
      buyerTaxOrCnp: existing?.buyerTaxOrCnp ?? client?.cui.trim() ?? '',
      installerName: existing?.installerName ?? defaultInstallerName,
      installerAddress: existing?.installerAddress ??
          (sale.installerType == InstallerType.ownCompany
              ? company.address.trim()
              : buildPartnerAddress(installerPartner)),
      installerEmail: existing?.installerEmail ??
          (sale.installerType == InstallerType.ownCompany
              ? company.email.trim()
              : installerPartner?.email.trim() ?? ''),
      installerPhone: existing?.installerPhone ??
          (sale.installerType == InstallerType.ownCompany
              ? company.phone.trim()
              : installerPartner?.phone.trim() ?? ''),
      installerTaxId: existing?.installerTaxId ??
          (sale.installerType == InstallerType.ownCompany
              ? company.cui.trim()
              : installerPartner?.cui.trim() ?? ''),
      installerPersons: existing?.installerPersons ??
          (sale.installerType == InstallerType.ownCompany
              ? company.contactName.trim()
              : installerPartner?.contactPerson.trim() ?? ''),
      installationDate: existing?.installationDate ?? sale.saleDate,
      termsText:
          existing?.termsText ?? ProductCatalogService.defaultWarrantyTerms,
      registryEntryId: existing?.registryEntryId ?? '',
      documentType: existing?.documentType ?? 'warranty_certificate',
      sourceModule: existing?.sourceModule ?? 'product_catalog_sales',
      generatedDocumentPath: existing?.generatedDocumentPath ?? '',
      generatedDocumentFileName: existing?.generatedDocumentFileName ?? '',
      warrantyServiceHistoryIds:
          existing?.warrantyServiceHistoryIds ?? const <String>[],
      complaintIds: existing?.complaintIds ?? const <String>[],
      warrantyServiceTickets: existing?.warrantyServiceTickets ??
          const <WarrantyServiceTicketRecord>[],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _editCertificate(
    ProductSaleRecord sale,
    ProductCatalogRecord product, {
    WarrantyCertificateRecord? existing,
  }) async {
    final initial = await _buildPrefilledCertificate(
      sale: sale,
      product: product,
      existing: existing,
    );
    if (!mounted) return;
    final saved = await showDialog<WarrantyCertificateRecord>(
      context: context,
      builder: (context) => _WarrantyCertificateDialog(
        initial: initial,
      ),
    );
    if (saved == null) return;
    await _service.saveWarrantyCertificate(saved);
    if (sale.warrantyCertificateId != saved.id) {
      await _service.saveSale(
        sale.copyWith(
          warrantyCertificateId: saved.id,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _load();
  }

  Future<void> _generateCertificatePdf(
    ProductSaleRecord sale,
    ProductCatalogRecord product,
    WarrantyCertificateRecord certificate, {
    required bool share,
    bool saveAs = false,
  }) async {
    try {
      final refreshed = await _buildPrefilledCertificate(
        sale: sale,
        product: product,
        existing: certificate,
      );
      final filePath = await WarrantyCertificatePdfService.export(
        repository: widget.repository,
        certificate: refreshed,
        saveAs: saveAs,
      );
      var persisted = refreshed.copyWith(
        generatedDocumentPath: filePath,
        generatedDocumentFileName: _fileNameFromPath(filePath),
        updatedAt: DateTime.now(),
      );
      if (persisted.registryEntryId.trim().isEmpty) {
        final registryEntry = await widget.repository.registerGeneratedDocument(
          registryType: RegistryType.iesire,
          documentCategory: 'Certificat garantie',
          documentTitle:
              'Certificat de garantie ${persisted.fullCertificateNumber}',
          documentNumber: persisted.fullCertificateNumber.trim().isEmpty
              ? persisted.id
              : persisted.fullCertificateNumber,
          documentDate: persisted.documentDate,
          issuerName: persisted.sellerName,
          recipientName: persisted.buyerName,
          clientId: sale.clientId,
          filePath: filePath,
          fileName: persisted.generatedDocumentFileName,
          notes: 'Generat din modulul Catalog produse / Vanzari.',
          status: 'emis',
        );
        persisted = persisted.copyWith(registryEntryId: registryEntry.id);
      }
      await _service.saveWarrantyCertificate(persisted);
      await _service.saveSale(
        sale.copyWith(
          warrantyCertificateId: persisted.id,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (share) {
        final company = await widget.repository.loadCompanyProfile();
        if (!mounted) return;
        final client = _clientById(sale.clientId);
        final defaultTo = client?.email.trim() ?? '';
        final subject =
            'Certificat garantie ${persisted.fullCertificateNumber}';
        final body =
            'Buna ziua,\n\nAtasat gasiti certificatul de garantie.\n\nCu stima,';
        final result = await showDialog<Map<String, String>?>(
          context: context,
          builder: (_) => SendDocumentDialog(
            to: defaultTo,
            subject: subject,
            body: body,
          ),
        );
        if (result == null) return;
        final action = result['action'] ?? 'cancel';
        if (action == 'cancel') return;
        if (action == 'mailto') {
          await DocumentFileService.shareFile(
            filePath,
            subject: result['subject'] ?? subject,
            text: result['body'] ?? body,
          );
          if (!mounted) return;
          await _load();
          return;
        }
        if (action == 'queue') {
          try {
            final inlineAssets = <Map<String, dynamic>>[];
            if (company.logoBase64.trim().isNotEmpty) {
              inlineAssets.add({
                'cid': 'companylogo',
                'filename': 'logo.png',
                'base64': company.logoBase64.trim(),
                'contentType': 'image/png',
              });
            }
            final notif = NotificationCenterService();
            final attachments = [
              await _buildQueueAttachmentFromFile(
                filePath: filePath,
                fileName: persisted.generatedDocumentFileName,
                sourceModule: 'product_catalog',
                sourceEntityId: persisted.id,
              ),
            ];
            final queueItem = await notif.sendEmailNotification(
              recipientEmail: result['to'] ?? defaultTo,
              recipientName: persisted.buyerName,
              subject: result['subject'] ?? subject,
              bodyText: result['body'] ?? body,
              bodyHtml: warrantyCertificateHtml(
                recipientName: result['to'] ?? persisted.buyerName,
                companyName: company.companyName,
                certificateNumber: persisted.fullCertificateNumber,
                message: result['body'] ?? body,
              ),
              attachments: attachments,
              inlineAssets: inlineAssets,
              sourceModule: 'product_catalog',
              sourceEntityId: persisted.id,
              eventType: NotificationEventType.documentGenerated,
              metadata: {'certificate_id': persisted.id},
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Email pus in coada: ${queueItem.id}. Statusul final se vede in Notificari / Email log.',
                ),
              ),
            );
            await _load();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Eroare la punerea in coada: $e')),
            );
          }
        }
        return;
      } else {
        if (!mounted) return;
        await PdfActionsHelper.showPdfActions(
          context,
          filePath: filePath,
          title: 'Certificat de garanție generat',
          shareSubject:
              'Certificat garanție ${persisted.fullCertificateNumber.trim().isEmpty ? persisted.id : persisted.fullCertificateNumber}',
          shareText: 'Certificat de garanție generat din aplicație.',
        );
      }
      if (!mounted) return;
      await _load();
    } on PdfSaveCanceledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea documentului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut genera certificatul: $error')),
      );
    }
  }

  Future<Map<String, dynamic>> _buildQueueAttachmentFromFile({
    required String filePath,
    required String fileName,
    required String sourceModule,
    required String sourceEntityId,
  }) async {
    final file = File(filePath.trim());
    if (!file.existsSync()) {
      throw StateError('Fisierul atasat nu exista: $filePath');
    }
    final bytes = await file.readAsBytes();
    final normalizedName = _sanitizeAttachmentFileName(fileName);
    if (bytes.length <= _maxInlineAttachmentBytes) {
      return <String, dynamic>{
        'filename': normalizedName,
        'base64': base64Encode(bytes),
        'content_type': 'application/pdf',
        'size_bytes': bytes.length,
      };
    }

    final safeEntity = sourceEntityId.trim().isEmpty
        ? 'unknown'
        : sourceEntityId.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final storagePath =
        'notification_email_attachments/$sourceModule/$safeEntity/${DateTime.now().millisecondsSinceEpoch}_$normalizedName';
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } catch (e) {
      debugPrint('[ProductCatalog] ❌ Storage upload failed: $e');
      rethrow;
    }
    return <String, dynamic>{
      'filename': normalizedName,
      'storage_path': ref.fullPath,
      'storage_bucket': ref.bucket,
      'content_type': 'application/pdf',
      'size_bytes': bytes.length,
      'encoding': 'firebase_storage',
    };
  }

  String _sanitizeAttachmentFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) return 'document.pdf';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  Future<void> _editPriceListEntry(
    ProductCatalogRecord product,
    PriceListRecord priceList, {
    PriceListEntryRecord? existing,
  }) async {
    final saved = await showDialog<PriceListEntryRecord>(
      context: context,
      builder: (context) => _PriceListEntryDialog(
        product: product,
        priceList: priceList,
        existing: existing,
        defaultVatPercent: _defaultVatPercent,
      ),
    );
    if (saved == null) return;
    await _service.savePriceListEntry(saved);
    await _load();
  }

  Future<void> _editPriceList({PriceListRecord? existing}) async {
    final saved = await showDialog<PriceListRecord>(
      context: context,
      builder: (context) => _PriceListDialog(existing: existing),
    );
    if (saved == null) return;
    await _service.savePriceList(saved);
    await _load();
  }

  Future<void> _deletePriceList(PriceListRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere listă comercială'),
        content: Text('Stergi lista ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deletePriceList(item.id);
    await _load();
  }

  Future<void> _managePriceLists() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste comerciale'),
        content: SizedBox(
          width: 640,
          child: _priceLists.isEmpty
              ? const Text('Nu exista liste comerciale.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _priceLists.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _priceLists[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.scope.label} | ${item.currency} | ${item.isActive ? 'Activa' : 'Inactiva'}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _editPriceList(existing: item);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _deletePriceList(item);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Închide'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _editPriceList();
            },
            icon: const Icon(Icons.add),
            label: const Text('Lista noua'),
          ),
        ],
      ),
    );
  }

  void _openMobileDetails(ProductCatalogRecord product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: _buildDetailsPanel(product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog produse'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Catalog'),
            Tab(icon: Icon(Icons.price_change_outlined), text: 'Liste prețuri'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Generează PDF listă prețuri',
            onPressed: _products.isEmpty
                ? null
                : () => _generateCatalogPdf(share: false),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Liste comerciale avansate',
            onPressed: _managePriceLists,
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            tooltip: 'Reîncarcă',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          HelpButton(content: AppHelp.catalogProduse),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editProduct,
        icon: const Icon(Icons.add),
        label: const Text('Produs / Serviciu nou'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Catalog ────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              final selected = _selectedProduct;
              return Padding(
                padding: AppViewportGuard.scrollablePadding(
                  reserveForFab: true,
                ),
                child: Column(
                  children: [
                    _buildToolbar(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _buildProductList(wide: true),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 420,
                                  child: selected == null
                                      ? const _EmptyDetailsState()
                                      : _buildDetailsPanel(selected),
                                ),
                              ],
                            )
                          : _buildProductList(wide: false),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Tab 2: Liste prețuri rapide ───────────────────────────────
          _buildPriceListView(),
        ],
      ),
    );
  }

  Widget _buildPriceListView() {
    final activeProducts = _products.where((p) => p.isActive).toList();
    final allCapacities = activeProducts
        .map((p) => p.capacity.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // Filtrare după capacitate
    List<ProductCatalogRecord> filtered(List<ProductCatalogRecord> source) {
      if (_capacityFilter.isEmpty) return source;
      return source
          .where((p) => p.capacity.trim() == _capacityFilter)
          .toList(growable: false);
    }

    final produse = filtered(activeProducts
        .where((p) => p.itemType == ProductItemType.product)
        .toList());
    final servicii = filtered(activeProducts
        .where((p) => p.itemType == ProductItemType.service)
        .toList());

    // Generare pachete: produs + serviciu cu capacitate potrivită
    final pachete = <_Package>[];
    for (final prod in produse) {
      final cap = prod.capacity.trim();
      final matchedServices = activeProducts.where((s) =>
          s.itemType == ProductItemType.service &&
          s.linkedCapacity.trim() == cap &&
          cap.isNotEmpty).toList();
      if (matchedServices.isEmpty) {
        pachete.add(_Package(product: prod, service: null));
      } else {
        for (final svc in matchedServices) {
          pachete.add(_Package(product: prod, service: svc));
        }
      }
    }

    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Selector mod ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.widgets_outlined),
                      label: Text('Pachete'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Produse'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.build_circle_outlined),
                      label: Text('Servicii'),
                    ),
                  ],
                  selected: {_priceListMode},
                  onSelectionChanged: (sel) =>
                      setState(() => _priceListMode = sel.first),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Generează PDF Listă Prețuri',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _products.isEmpty
                    ? null
                    : _generatePriceListTabPdf,
              ),
            ],
          ),
        ),

        // ── Filtre capacitate ─────────────────────────────────────────
        if (allCapacities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Toate'),
                    selected: _capacityFilter.isEmpty,
                    onSelected: (_) =>
                        setState(() => _capacityFilter = ''),
                  ),
                  const SizedBox(width: 6),
                  ...allCapacities.map((cap) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cap),
                          selected: _capacityFilter == cap,
                          onSelected: (_) => setState(() =>
                              _capacityFilter =
                                  _capacityFilter == cap ? '' : cap),
                        ),
                      )),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // ── Lista ───────────────────────────────────────────────────────
        Expanded(
          child: Builder(builder: (context) {
            if (_priceListMode == 0) {
              // Pachete
              if (pachete.isEmpty) {
                return _priceListEmpty(
                  'Nu există pachete.\nAdaugă produse și servicii cu capacitate asociată.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: pachete.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildPackageCard(pachete[i], cs),
              );
            } else if (_priceListMode == 1) {
              // Produse
              if (produse.isEmpty) {
                return _priceListEmpty(
                  'Nu există produse active${_capacityFilter.isEmpty ? '' : ' pentru capacitatea $_capacityFilter'}.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: produse.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildProductCard(produse[i], cs),
              );
            } else {
              // Servicii
              if (servicii.isEmpty) {
                return _priceListEmpty(
                  'Nu există servicii active${_capacityFilter.isEmpty ? '' : ' pentru capacitatea $_capacityFilter'}.\nAdaugă servicii de tip "Serviciu" cu capacitate asociată.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: servicii.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildServiceCard(servicii[i], cs),
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _priceListEmpty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price <= 0) return '—';
    return '${price.toStringAsFixed(2)} RON';
  }

  // ── Extrage primul URL de imagine dintr-un produs ─────────────────────────
  String _firstImageUrl(ProductCatalogRecord p) {
    return p.imagePaths
        .map((path) => path.trim())
        .firstWhere(
          (path) =>
              path.startsWith('http://') || path.startsWith('https://'),
          orElse: () => '',
        );
  }

  // ── Card produs/serviciu generic pentru thumbnail ──────────────────────────
  Widget _productThumbnail({
    required String imageUrl,
    required IconData fallbackIcon,
    required Color bgColor,
    required Color iconColor,
    double size = 64,
  }) {
    if (imageUrl.isNotEmpty) {
      return AppNetworkImage(
        url: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.circular(10),
        errorWidget: _iconPlaceholder(
          size: size,
          bgColor: bgColor,
          icon: fallbackIcon,
          iconColor: iconColor,
        ),
        loadingWidget: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return _iconPlaceholder(
      size: size,
      bgColor: bgColor,
      icon: fallbackIcon,
      iconColor: iconColor,
    );
  }

  Widget _iconPlaceholder({
    required double size,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size * 0.45, color: iconColor),
    );
  }

  // ── Card pachet (UI profesional) ───────────────────────────────────────────
  Widget _buildPackageCard(_Package pkg, ColorScheme cs) {
    final totalPrice = pkg.product.listPrice + (pkg.service?.listPrice ?? 0);
    final imageUrl = _firstImageUrl(pkg.product);
    final productDesc = pkg.product.commercialDescription.trim().isEmpty
        ? pkg.product.description.trim()
        : pkg.product.commercialDescription.trim();
    final serviceDesc = pkg.service == null
        ? ''
        : (pkg.service!.commercialDescription.trim().isEmpty
            ? pkg.service!.description.trim()
            : pkg.service!.commercialDescription.trim());

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header colorat ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.widgets_outlined,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text(
                        'PACHET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pkg.product.capacity.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pkg.product.capacity.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (totalPrice > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white70,
                            letterSpacing: 0.5),
                      ),
                      Text(
                        _formatPrice(totalPrice),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Rândul produsului ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productThumbnail(
                  imageUrl: imageUrl,
                  fallbackIcon: Icons.inventory_2_outlined,
                  bgColor: cs.primaryContainer,
                  iconColor: cs.primary,
                  size: 60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (pkg.product.brand.isNotEmpty ||
                          pkg.product.model.isNotEmpty)
                        Text(
                          [pkg.product.brand, pkg.product.model]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      if (productDesc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          productDesc,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (pkg.product.listPrice > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Produs',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        _formatPrice(pkg.product.listPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Rândul serviciului ──────────────────────────────────────────
          if (pkg.service != null) ...[
            Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.teal.shade200),
                    ),
                    child: Icon(Icons.build_circle_outlined,
                        size: 16, color: Colors.teal.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.service!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.teal.shade800,
                          ),
                        ),
                        if (serviceDesc.isNotEmpty)
                          Text(
                            serviceDesc,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (pkg.service!.listPrice > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Montaj',
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                        Text(
                          _formatPrice(pkg.service!.listPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Text(
                'Fără serviciu de montaj asociat pentru această capacitate.',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Card produs individual (UI profesional) ────────────────────────────────
  Widget _buildProductCard(ProductCatalogRecord p, ColorScheme cs) {
    final imageUrl = _firstImageUrl(p);
    final desc = p.commercialDescription.trim().isEmpty
        ? p.description.trim()
        : p.commercialDescription.trim();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _productThumbnail(
              imageUrl: imageUrl,
              fallbackIcon: Icons.inventory_2_outlined,
              bgColor: cs.primaryContainer,
              iconColor: cs.primary,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (p.brand.isNotEmpty || p.model.isNotEmpty)
                    Text(
                      [p.brand, p.model]
                          .where((s) => s.isNotEmpty)
                          .join(' • '),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  if (p.capacity.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.capacity,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondaryContainer),
                        ),
                      ),
                    ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (p.listPrice > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('Preț',
                        style: TextStyle(
                            fontSize: 10, color: cs.onPrimaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(p.listPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Card serviciu individual (UI profesional) ──────────────────────────────
  Widget _buildServiceCard(ProductCatalogRecord s, ColorScheme cs) {
    final desc = s.commercialDescription.trim().isEmpty
        ? s.description.trim()
        : s.commercialDescription.trim();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Icon(Icons.build_circle_outlined,
                  size: 26, color: Colors.teal.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.teal.shade800)),
                  if (s.linkedCapacity.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          'Capacitate: ${s.linkedCapacity}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700),
                        ),
                      ),
                    ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (s.listPrice > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  children: [
                    Text('Preț',
                        style: TextStyle(
                            fontSize: 10, color: Colors.teal.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(s.listPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Generează PDF pentru tab-ul "Liste prețuri" ────────────────────────────
  Future<void> _generatePriceListTabPdf() async {
    final activeProducts = _products.where((p) => p.isActive).toList();

    List<ProductCatalogRecord> filtered(List<ProductCatalogRecord> src) {
      if (_capacityFilter.isEmpty) return src;
      return src
          .where((p) => p.capacity.trim() == _capacityFilter)
          .toList(growable: false);
    }

    final produse = filtered(activeProducts
        .where((p) => p.itemType == ProductItemType.product)
        .toList());
    final servicii = filtered(activeProducts
        .where((p) => p.itemType == ProductItemType.service)
        .toList());

    // Pachete
    final pachete = <ListaPreturiPachetItem>[];
    for (final prod in produse) {
      final cap = prod.capacity.trim();
      final matched = activeProducts.where((s) =>
          s.itemType == ProductItemType.service &&
          s.linkedCapacity.trim() == cap &&
          cap.isNotEmpty).toList();
      if (matched.isEmpty) {
        pachete.add(ListaPreturiPachetItem(
          productName: prod.name,
          productSubtitle: [prod.brand, prod.model]
              .where((s) => s.isNotEmpty)
              .join(' • '),
          productDescription: prod.commercialDescription.trim().isEmpty
              ? prod.description.trim()
              : prod.commercialDescription.trim(),
          productImagePath: prod.imagePaths
              .map((p) => p.trim())
              .firstWhere((p) => p.isNotEmpty, orElse: () => ''),
          capacity: cap,
          productPrice: prod.listPrice,
        ));
      } else {
        for (final svc in matched) {
          pachete.add(ListaPreturiPachetItem(
            productName: prod.name,
            productSubtitle: [prod.brand, prod.model]
                .where((s) => s.isNotEmpty)
                .join(' • '),
            productDescription: prod.commercialDescription.trim().isEmpty
                ? prod.description.trim()
                : prod.commercialDescription.trim(),
            productImagePath: prod.imagePaths
                .map((p) => p.trim())
                .firstWhere((p) => p.isNotEmpty, orElse: () => ''),
            capacity: cap,
            productPrice: prod.listPrice,
            serviceName: svc.name,
            serviceDescription: svc.commercialDescription.trim().isEmpty
                ? svc.description.trim()
                : svc.commercialDescription.trim(),
            servicePrice: svc.listPrice,
          ));
        }
      }
    }

    // Produse single
    final produseItems = produse
        .map((p) => ListaPreturiSingleItem(
              name: p.name,
              subtitle: [p.brand, p.model]
                  .where((s) => s.isNotEmpty)
                  .join(' • '),
              capacity: p.capacity,
              description: p.commercialDescription.trim().isEmpty
                  ? p.description.trim()
                  : p.commercialDescription.trim(),
              imagePath: p.imagePaths
                  .map((s) => s.trim())
                  .firstWhere((s) => s.isNotEmpty, orElse: () => ''),
              price: p.listPrice,
            ))
        .toList();

    // Servicii single
    final serviciiItems = servicii
        .map((s) => ListaPreturiSingleItem(
              name: s.name,
              subtitle: s.linkedCapacity.isNotEmpty
                  ? 'Capacitate: ${s.linkedCapacity}'
                  : '',
              description: s.commercialDescription.trim().isEmpty
                  ? s.description.trim()
                  : s.commercialDescription.trim(),
              price: s.listPrice,
            ))
        .toList();

    try {
      await ProductCatalogPricelistPdfService.exportListaPreturiTab(
        repository: widget.repository,
        title: 'Listă Prețuri',
        capacityFilter: _capacityFilter,
        pachete: pachete,
        produse: produseItems,
        servicii: serviciiItems,
        mode: _priceListMode,
        saveAs: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generat cu succes.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare generare PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Pe ecrane largi (Windows/tablet ≥600px) filtrele sunt mereu vizibile
        final isWide = constraints.maxWidth >= 600;
        final showFilters = isWide || _filtersVisible;
        final cs = Theme.of(context).colorScheme;
        final hasFilters = _activeFilterCount > 0;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rândul 1: search + buton filtre (pe mobil) / search direct (pe desktop)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Caută produs, brand, model, SKU...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.trim().isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    // Buton filtre: vizibil DOAR pe mobil (pe desktop filtrele sunt mereu afișate)
                    if (!isWide) ...[
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(
                                () => _filtersVisible = !_filtersVisible),
                            icon: Icon(
                              _filtersVisible
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              size: 18,
                            ),
                            label:
                                Text(_filtersVisible ? 'Ascunde' : 'Filtre'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: hasFilters ? cs.primary : null,
                              side: hasFilters
                                  ? BorderSide(color: cs.primary, width: 1.5)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          if (hasFilters)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_activeFilterCount',
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                // Rândul 2: filtre (mereu pe desktop, colapsabile pe mobil)
                if (showFilters) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: const Text('Toate'),
                          selected: _categoryFilter.isEmpty,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = ''),
                        ),
                        const SizedBox(width: 6),
                        ..._categories.map((cat) {
                          final displayName = _categoryDisplayName(cat);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(displayName),
                              selected: _categoryFilter == cat,
                              onSelected: (sel) => setState(
                                () => _categoryFilter = sel ? cat : '',
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  if ((_service.fallbackReason ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Fallback: ${_service.fallbackReason}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductList({required bool wide}) {
    final rows = _filteredProducts;
    if (rows.isEmpty) {
      return const Center(
        child: Text('Nu exista produse salvate pentru filtrele curente.'),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = rows[index];
        final selected = item.id == _selectedProductId;
        final referencePrice = _referencePriceForProduct(item.id);
        final sales = _salesForProduct(item.id);
        final sale = sales.isEmpty ? null : sales.first;
        final availableStock = _availableStockForProduct(item);

        final cs = Theme.of(context).colorScheme;
        final categoryDisplay = _categoryDisplayName(item.category);
        final hasPrice = referencePrice != null;
        final priceText = hasPrice
            ? _formatMoney(referencePrice.basePrice, referencePrice.currency)
            : (item.listPrice > 0
                ? _formatMoney(item.listPrice, 'RON')
                : null);
        return Card(
          color: selected ? cs.secondaryContainer : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _selectedProductId = item.id);
              if (!wide) {
                _openMobileDetails(item);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rândul 1: categorie + status stoc
                  Row(
                    children: [
                      if (item.category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryDisplay,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: availableStock > 0
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          availableStock > 0
                              ? '${availableStock.toStringAsFixed(0)} disp.'
                              : 'Fără stoc',
                          style: TextStyle(
                            fontSize: 11,
                            color: availableStock > 0
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!item.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Inactiv',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Rândul 2: numele produsului
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rândul 3: brand · cod
                  if (item.brand.isNotEmpty || item.sku.isNotEmpty)
                    Text(
                      [
                        if (item.brand.isNotEmpty) item.brand,
                        if (item.model.isNotEmpty) item.model,
                        if (item.sku.isNotEmpty) 'Cod: ${item.sku}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  if (item.capacity.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Capacitate: ${item.capacity}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Rândul 4: preț + acțiuni
                  Row(
                    children: [
                      if (priceText != null) ...[
                        Icon(Icons.monetization_on_outlined,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          priceText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 15,
                          ),
                        ),
                      ] else
                        Text(
                          'Fără preț',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _editProduct(existing: item),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Editează'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteProduct(item),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Șterge'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(color: cs.error),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Rândul 5: status vânzare (dacă există)
                  if (sale != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Vânzare: ${sale.saleStatus.label}'
                      '${sale.clientName.trim().isNotEmpty ? ' · ${sale.clientName.trim()}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsPanel(ProductCatalogRecord product) {
    final supplierPrices = _pricesForProduct(product.id);
    final referencePrice = _referencePriceForProduct(product.id);
    final referenceCost = referencePrice == null
        ? null
        : _service.computeSupplierCost(referencePrice);
    final sales = _salesForProduct(product.id);
    final availableStock = _availableStockForProduct(product);

    return Card(
      margin: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _infoRow('Categorie', product.category),
          _infoRow('Brand', product.brand),
          _infoRow('Model', product.model),
          _infoRow('Capacitate', product.capacity),
          _infoRow('SKU', product.sku),
          _infoRow('UM', product.unit),
          _infoRow('Status stoc', product.stockStatus.label),
          _infoRow('Stoc curent', product.stockQuantity.toStringAsFixed(2)),
          _infoRow(
            'Stoc alocat automat',
            _allocatedStockForProduct(product.id).toStringAsFixed(2),
          ),
          _infoRow('Stoc disponibil', availableStock.toStringAsFixed(2)),
          _infoRow(
            'Termen livrare',
            product.deliveryLeadTimeText.trim().isEmpty
                ? '-'
                : product.deliveryLeadTimeText.trim(),
          ),
          _infoRow('Ultim update stoc', _formatDate(product.stockUpdatedAt)),
          _infoRow('Activ', product.isActive ? 'Da' : 'Nu'),
          _infoRow(
            'Documente',
            'Imagini ${product.imagePaths.length} | PDF ${product.pdfPaths.length}',
          ),
          if (product.commercialDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Descriere comerciala',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(product.commercialDescription.trim()),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Stoc si disponibilitate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _adjustProductStock(product),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Ajusteaza stoc'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text('Status: ${product.stockStatus.label}'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          'Disponibil: ${availableStock.toStringAsFixed(2)} ${product.unit}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(
                          'La comanda / rezervat automat: ${_allocatedStockForProduct(product.id).toStringAsFixed(2)}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scaderea automata din stoc este derivata doar din vanzari reale cu status rezervat sau vandut. Cererile simple si aprobarile neincheiate nu modifica stocul.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Preturi furnizor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _editSupplierPrice(product),
                icon: const Icon(Icons.add),
                label: const Text('Pret'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (supplierPrices.isEmpty)
            const Text('Nu exista preturi furnizor pentru produsul selectat.')
          else
            ...supplierPrices.map((item) {
              final breakdown = _service.computeSupplierCost(item);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.supplierName.isEmpty
                                  ? 'Furnizor nealocat'
                                  : item.supplierName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (_service.isSupplierPriceActiveNow(item))
                            const Chip(
                              label: Text('Activ acum'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Baza: ${_formatMoney(item.basePrice, item.currency)} | Discount: ${_formatMoney(breakdown.discountValueApplied, item.currency)} | Cost final: ${_formatMoney(breakdown.finalEntryCost, item.currency)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Net furnizor: ${_formatMoney(breakdown.netSupplierCost, item.currency)} | Timbru verde: ${_formatMoney(breakdown.greenStampCost, item.currency)} | Transport: ${_formatMoney(breakdown.transportCost, item.currency)} | Alte costuri: ${_formatMoney(breakdown.otherCosts, item.currency)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (item.validFrom != null || item.validTo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Valabil: ${_formatDate(item.validFrom)} - ${_formatDate(item.validTo)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (item.notes.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.notes.trim(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _editSupplierPrice(product, existing: item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => _deleteSupplierPrice(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            'Liste comerciale si pret vanzare',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_priceLists.isEmpty)
            const Text('Nu exista liste comerciale definite.')
          else
            ..._priceLists.map((priceList) {
              final entry = _entryFor(priceList.id, product.id);
              final sale = _resolvedSaleBreakdown(
                entry: entry,
                referenceCost: referenceCost,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              priceList.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Chip(
                            label: Text(priceList.scope.label),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry == null
                            ? 'Fara regula configurata pentru acest produs.'
                            : '${entry.pricingMode.label}: ${entry.pricingValue.toStringAsFixed(2)}${entry.pricingMode == SalePricingMode.markupPercent || entry.pricingMode == SalePricingMode.targetProfitPercent ? '%' : ''}',
                      ),
                      if (referenceCost == null && sale == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Nu exista inca un cost furnizor de referinta pentru calcul.',
                          ),
                        ),
                      if (sale != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Cost: ${_formatMoney(sale.costBeforePricing, entry!.currency)} | Pret vanzare net: ${_formatMoney(sale.saleNetPrice, entry.currency)} | Pret prezentare: ${_formatMoney(sale.saleGrossPrice, entry.currency)} | Profit: ${_formatMoney(sale.profitValue, entry.currency)} (${sale.profitPercentOnCost.toStringAsFixed(2)}%)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (referenceCost == null && sale != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Afisare din calculul salvat la ultima configurare a regulii comerciale.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _editPriceListEntry(
                            product,
                            priceList,
                            existing: entry,
                          ),
                          icon: const Icon(Icons.edit_note_outlined),
                          label:
                              Text(entry == null ? 'Configureaza' : 'Editeaza'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Vanzari si certificate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _editSale(product),
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Vanzare'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sales.isEmpty)
            const Text(
              'Nu exista inca inregistrari de vanzare pentru produsul selectat.',
            )
          else
            ...sales.map((sale) {
              final certificate = _certificateForSale(sale);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            sale.clientName.trim().isEmpty
                                ? 'Client nealocat'
                                : sale.clientName.trim(),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Chip(
                            label: Text(sale.saleStatus.label),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (certificate != null)
                            Chip(
                              label: Text(
                                certificate.fullCertificateNumber.trim().isEmpty
                                    ? 'Certificat draft'
                                    : certificate.fullCertificateNumber,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Data vanzare: ${_formatDate(sale.saleDate)} | Factura: ${sale.invoiceNumber.trim().isEmpty ? '-' : sale.invoiceNumber.trim()} | Garantie: ${sale.warrantyMonths} luni',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Serie UI: ${sale.serialNumberIndoor.trim().isEmpty ? '-' : sale.serialNumberIndoor.trim()} | Serie UE: ${sale.serialNumberOutdoor.trim().isEmpty ? '-' : sale.serialNumberOutdoor.trim()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Instalator: ${sale.installerType.label} | ${sale.installerDisplayName.trim().isEmpty ? '-' : sale.installerDisplayName.trim()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (sale.notes.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sale.notes.trim(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _editSale(product, existing: sale),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editeaza'),
                          ),
                          if (sale.saleStatus == ProductSaleStatus.vandut)
                            FilledButton.tonalIcon(
                              onPressed: () => _editCertificate(
                                sale,
                                product,
                                existing: certificate,
                              ),
                              icon: const Icon(Icons.verified_outlined),
                              label: Text(
                                certificate == null
                                    ? 'Certificat'
                                    : 'Editeaza certificat',
                              ),
                            ),
                          if (sale.saleStatus == ProductSaleStatus.vandut &&
                              certificate != null)
                            FilledButton.tonalIcon(
                              onPressed: () => _generateCertificatePdf(
                                sale,
                                product,
                                certificate,
                                share: false,
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Genereaza PDF'),
                            ),
                          if (sale.saleStatus == ProductSaleStatus.vandut &&
                              certificate != null)
                            OutlinedButton.icon(
                              onPressed: () => _generateCertificatePdf(
                                sale,
                                product,
                                certificate,
                                share: false,
                                saveAs: true,
                              ),
                              icon: const Icon(Icons.save_as_outlined),
                              label: const Text('Save As'),
                            ),
                          if (sale.saleStatus == ProductSaleStatus.vandut &&
                              certificate != null)
                            FilledButton.tonalIcon(
                              onPressed: () => _generateCertificatePdf(
                                sale,
                                product,
                                certificate,
                                share: true,
                              ),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Share'),
                            ),
                          IconButton(
                            onPressed: () => _deleteSale(sale),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Șterge vânzarea',
                          ),
                        ],
                      ),
                      if (certificate?.registryEntryId.trim().isNotEmpty ==
                          true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Registratura: ${certificate!.registryEntryId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Text(
            'Catalog prezentare',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _priceLists.isEmpty
                    ? null
                    : () => _generateCatalogPdf(share: false),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Genereaza PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _priceLists.isEmpty
                    ? null
                    : () => _generateCatalogPdf(
                          share: false,
                          saveAs: true,
                        ),
                icon: const Icon(Icons.save_as_outlined),
                label: const Text('Save As'),
              ),
              FilledButton.tonalIcon(
                onPressed: _priceLists.isEmpty
                    ? null
                    : () => _generateCatalogPdf(share: true),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'PDF-ul foloseste doar descrierea comerciala, imaginile si pretul final din lista comerciala selectata, fara costuri sau breakdown intern.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: ${value.trim().isEmpty ? '-' : value.trim()}'),
    );
  }

  String _formatMoney(double value, String currency) {
    return '${value.toStringAsFixed(2)} ${currency.trim().isEmpty ? 'RON' : currency.trim().toUpperCase()}';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}

class _Package {
  const _Package({required this.product, this.service});
  final ProductCatalogRecord product;
  final ProductCatalogRecord? service;
}

class _EmptyDetailsState extends StatelessWidget {
  const _EmptyDetailsState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Selecteaza un produs pentru a vedea costurile si listele comerciale.'),
        ),
      ),
    );
  }
}

class _CatalogPdfRequest {
  const _CatalogPdfRequest({
    required this.priceList,
    required this.productIds,
  });

  final PriceListRecord priceList;
  final Set<String> productIds;
}

class _CatalogPdfDialog extends StatefulWidget {
  const _CatalogPdfDialog({
    required this.priceLists,
    required this.products,
    required this.filteredProductIds,
    required this.initiallySelectedProductId,
  });

  final List<PriceListRecord> priceLists;
  final List<ProductCatalogRecord> products;
  final Set<String> filteredProductIds;
  final String? initiallySelectedProductId;

  @override
  State<_CatalogPdfDialog> createState() => _CatalogPdfDialogState();
}

class _CatalogPdfDialogState extends State<_CatalogPdfDialog> {
  late PriceListRecord _selectedPriceList;
  bool _includeAllActive = true;
  late Set<String> _selectedProductIds;

  List<ProductCatalogRecord> get _activeProducts =>
      widget.products.where((item) => item.isActive).toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  void initState() {
    super.initState();
    _selectedPriceList = widget.priceLists.firstWhere(
      (item) => item.isActive,
      orElse: () => widget.priceLists.first,
    );
    final activeIds = _activeProducts.map((item) => item.id).toSet();
    final preferredIds =
        widget.filteredProductIds.where((id) => activeIds.contains(id)).toSet();
    _selectedProductIds = preferredIds.isNotEmpty ? preferredIds : activeIds;
    final initialId = widget.initiallySelectedProductId?.trim() ?? '';
    if (initialId.isNotEmpty && activeIds.contains(initialId)) {
      _selectedProductIds.add(initialId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Genereaza lista de pret PDF'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPriceList.id,
                decoration:
                    const InputDecoration(labelText: 'Lista comerciala'),
                items: widget.priceLists
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPriceList = widget.priceLists.firstWhere(
                      (item) => item.id == value,
                      orElse: () => widget.priceLists.first,
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeAllActive,
                onChanged: (value) => setState(() => _includeAllActive = value),
                title: const Text('Include toate produsele active'),
                subtitle: const Text(
                  'Daca dezactivezi optiunea, alegi manual produsele incluse in PDF.',
                ),
              ),
              if (!_includeAllActive) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: _activeProducts.map((product) {
                      final checked = _selectedProductIds.contains(product.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedProductIds.add(product.id);
                            } else {
                              _selectedProductIds.remove(product.id);
                            }
                          });
                        },
                        title: Text(product.name),
                        subtitle: Text(
                          [
                            product.category.trim(),
                            product.brand.trim(),
                            product.model.trim(),
                          ].where((item) => item.isNotEmpty).join(' | '),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continua'),
        ),
      ],
    );
  }

  void _submit() {
    final productIds = _includeAllActive
        ? _activeProducts.map((item) => item.id).toSet()
        : _selectedProductIds;
    if (productIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteaza cel putin un produs pentru PDF.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _CatalogPdfRequest(
        priceList: _selectedPriceList,
        productIds: productIds,
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    this.existing,
    this.existingCategories = const [],
    this.existingBrands = const [],
    this.existingModels = const [],
    this.existingCapacities = const [],
  });

  final ProductCatalogRecord? existing;
  final List<String> existingCategories;
  final List<String> existingBrands;
  final List<String> existingModels;
  final List<String> existingCapacities;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _linkedCapacityController = TextEditingController();
  final _listPriceController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commercialDescriptionController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _deliveryLeadTimeController = TextEditingController();
  final _imagePathsController = TextEditingController();
  final _pdfPathsController = TextEditingController();
  ProductStockStatus _stockStatus = ProductStockStatus.inStock;
  ProductItemType _itemType = ProductItemType.product;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _categoryController.text = existing.category;
      _brandController.text = existing.brand;
      _modelController.text = existing.model;
      _capacityController.text = existing.capacity;
      _linkedCapacityController.text = existing.linkedCapacity;
      _listPriceController.text = existing.listPrice > 0
          ? existing.listPrice.toStringAsFixed(2)
          : '';
      _skuController.text = existing.sku;
      _unitController.text = existing.unit;
      _descriptionController.text = existing.description;
      _commercialDescriptionController.text = existing.commercialDescription;
      _stockQuantityController.text = existing.stockQuantity.toStringAsFixed(2);
      _deliveryLeadTimeController.text = existing.deliveryLeadTimeText;
      _stockStatus = existing.stockStatus;
      _itemType = existing.itemType;
      _imagePathsController.text = existing.imagePaths.join('\n');
      _pdfPathsController.text = existing.pdfPaths.join('\n');
      _isActive = existing.isActive;
    } else {
      _unitController.text = 'buc';
      _stockQuantityController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _capacityController.dispose();
    _linkedCapacityController.dispose();
    _listPriceController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _commercialDescriptionController.dispose();
    _stockQuantityController.dispose();
    _deliveryLeadTimeController.dispose();
    _imagePathsController.dispose();
    _pdfPathsController.dispose();
    super.dispose();
  }

  double _parseDouble(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _pickPaths({
    required TextEditingController controller,
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: type,
      allowedExtensions: allowedExtensions,
    );
    if (result == null) {
      return;
    }
    final picked = result.files
        .map((file) => file.path?.trim() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (picked.isEmpty) {
      return;
    }
    final existing = _splitLines(controller.text);
    final merged = <String>[
      ...existing,
      ...picked.where((path) => !existing.contains(path)),
    ];
    setState(() {
      controller.text = merged.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Produs / Serviciu nou' : 'Editează produs / serviciu'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<ProductItemType>(
                    initialValue: _itemType,
                    decoration: const InputDecoration(labelText: 'Tip'),
                    items: ProductItemType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _itemType = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Denumire'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Completeaza denumirea.'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: _categoryController.text,
                    ),
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      final opts = widget.existingCategories
                          .where((c) =>
                              query.isEmpty || c.toLowerCase().contains(query))
                          .toList(growable: false);
                      return opts;
                    },
                    onSelected: (value) {
                      _categoryController.text = value;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _categoryController.text = value;
                        },
                        decoration:
                            const InputDecoration(labelText: 'Categorie'),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'UM'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _stockQuantityController,
                    decoration:
                        const InputDecoration(labelText: 'Cantitate stoc'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<ProductStockStatus>(
                    initialValue: _stockStatus,
                    decoration: const InputDecoration(labelText: 'Status stoc'),
                    items: ProductStockStatus.values
                        .map(
                          (item) => DropdownMenuItem<ProductStockStatus>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _stockStatus = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: _brandController.text,
                    ),
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      final opts = widget.existingBrands
                          .where((c) =>
                              query.isEmpty || c.toLowerCase().contains(query))
                          .toList(growable: false);
                      return opts;
                    },
                    onSelected: (value) {
                      _brandController.text = value;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _brandController.text = value;
                        },
                        decoration: const InputDecoration(labelText: 'Brand'),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: _modelController.text,
                    ),
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      final opts = widget.existingModels
                          .where((c) =>
                              query.isEmpty || c.toLowerCase().contains(query))
                          .toList(growable: false);
                      return opts;
                    },
                    onSelected: (value) {
                      _modelController.text = value;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _modelController.text = value;
                        },
                        decoration: const InputDecoration(labelText: 'Model'),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: _capacityController.text,
                    ),
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      final opts = widget.existingCapacities
                          .where((c) =>
                              query.isEmpty || c.toLowerCase().contains(query))
                          .toList(growable: false);
                      return opts;
                    },
                    onSelected: (value) {
                      _capacityController.text = value;
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _capacityController.text = value;
                        },
                        decoration: const InputDecoration(
                            labelText: 'Capacitate (kW/BTU)'),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _listPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preț listă (RON)',
                      helperText: 'Preț afișat în lista de prețuri',
                    ),
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setLocal) {
                    return SizedBox(
                      width: 240,
                      child: Visibility(
                        visible: _itemType == ProductItemType.service,
                        maintainState: true,
                        child: Autocomplete<String>(
                          initialValue: TextEditingValue(
                            text: _linkedCapacityController.text,
                          ),
                          optionsBuilder: (textEditingValue) {
                            final query = textEditingValue.text.trim().toLowerCase();
                            final opts = widget.existingCapacities
                                .where((c) =>
                                    query.isEmpty || c.toLowerCase().contains(query))
                                .toList(growable: false);
                            return opts;
                          },
                          onSelected: (value) {
                            _linkedCapacityController.text = value;
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (value) {
                                _linkedCapacityController.text = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Capacitate asociată',
                                helperText: 'Conectează serviciul la produse cu aceeași capacitate',
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU / cod'),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _deliveryLeadTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Termen livrare',
                      helperText: 'Ex: 2 zile, 5-7 zile, la comanda',
                    ),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Descriere interna'),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _commercialDescriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Descriere comerciala'),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _imagePathsController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Cai imagini',
                          helperText: 'Un path pe linie.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPaths(
                            controller: _imagePathsController,
                            type: FileType.image,
                          ),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Alege imagine'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _pdfPathsController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Cai PDF',
                          helperText: 'Un path pe linie.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPaths(
                            controller: _pdfPathsController,
                            type: FileType.custom,
                            allowedExtensions: const <String>[
                              'pdf',
                              'doc',
                              'docx',
                              'xls',
                              'xlsx',
                              'jpg',
                              'jpeg',
                              'png',
                              'webp',
                            ],
                          ),
                          icon: const Icon(Icons.attach_file_outlined),
                          label: const Text('Alege fisier'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    title: const Text('Activ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      ProductCatalogRecord(
        id: widget.existing?.id ?? 'product-${now.microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        itemType: _itemType,
        category: _categoryController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        capacity: _capacityController.text.trim(),
        linkedCapacity: _itemType == ProductItemType.service
            ? _linkedCapacityController.text.trim()
            : '',
        listPrice: _parseDouble(_listPriceController.text),
        sku: _skuController.text.trim(),
        unit: _unitController.text.trim().isEmpty
            ? (_itemType == ProductItemType.service ? 'serv' : 'buc')
            : _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        commercialDescription: _commercialDescriptionController.text.trim(),
        stockQuantity: _parseDouble(_stockQuantityController.text),
        stockStatus: _stockStatus,
        deliveryLeadTimeText: _deliveryLeadTimeController.text.trim(),
        stockUpdatedAt: DateTime.now(),
        isActive: _isActive,
        imagePaths: _splitLines(_imagePathsController.text),
        pdfPaths: _splitLines(_pdfPathsController.text),
        registryEntryIds: widget.existing?.registryEntryIds ?? const <String>[],
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _ProductStockAdjustDialog extends StatefulWidget {
  const _ProductStockAdjustDialog({required this.product});

  final ProductCatalogRecord product;

  @override
  State<_ProductStockAdjustDialog> createState() =>
      _ProductStockAdjustDialogState();
}

class _ProductStockAdjustDialogState extends State<_ProductStockAdjustDialog> {
  late final TextEditingController _currentQuantityController =
      TextEditingController(
    text: widget.product.stockQuantity.toStringAsFixed(2),
  );
  final TextEditingController _adjustmentController = TextEditingController();
  late final TextEditingController _leadTimeController = TextEditingController(
    text: widget.product.deliveryLeadTimeText,
  );
  late ProductStockStatus _stockStatus = widget.product.stockStatus;

  @override
  void dispose() {
    _currentQuantityController.dispose();
    _adjustmentController.dispose();
    _leadTimeController.dispose();
    super.dispose();
  }

  double _parseDouble(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajusteaza stoc'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentQuantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Cantitate stoc noua'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adjustmentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Ajustare rapida +/-',
                helperText:
                    'Optional. Daca este completata, se aplica peste cantitatea curenta.',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductStockStatus>(
              initialValue: _stockStatus,
              decoration: const InputDecoration(labelText: 'Status stoc'),
              items: ProductStockStatus.values
                  .map(
                    (item) => DropdownMenuItem<ProductStockStatus>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _stockStatus = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _leadTimeController,
              decoration: const InputDecoration(labelText: 'Termen livrare'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: () {
            final now = DateTime.now();
            var quantity = _parseDouble(_currentQuantityController.text);
            final delta = _parseDouble(_adjustmentController.text);
            if (_adjustmentController.text.trim().isNotEmpty) {
              quantity = widget.product.stockQuantity + delta;
            }
            Navigator.of(context).pop(
              widget.product.copyWith(
                stockQuantity: quantity,
                stockStatus: _stockStatus,
                deliveryLeadTimeText: _leadTimeController.text.trim(),
                stockUpdatedAt: now,
                updatedAt: now,
              ),
            );
          },
          child: const Text('Salveaza'),
        ),
      ],
    );
  }
}

class _SupplierPriceDialog extends StatefulWidget {
  const _SupplierPriceDialog({
    required this.product,
    required this.suppliers,
    this.existing,
    this.defaultVatPercent = 21.0,
  });

  final ProductCatalogRecord product;
  final List<PartnerRecord> suppliers;
  final SupplierPriceRecord? existing;
  final double defaultVatPercent;

  @override
  State<_SupplierPriceDialog> createState() => _SupplierPriceDialogState();
}

class _SupplierPriceDialogState extends State<_SupplierPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();
  final _currencyController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _vatPercentController = TextEditingController();
  final _discountPercentController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _greenStampController = TextEditingController();
  final _transportController = TextEditingController();
  final _otherCostController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedSupplierId;
  bool _priceIncludesVat = false;
  bool _greenStampIncluded = false;
  bool _transportIncluded = false;
  DateTime? _validFrom;
  DateTime? _validTo;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedSupplierId =
          existing.supplierId.trim().isEmpty ? null : existing.supplierId;
      _supplierNameController.text = existing.supplierName;
      _currencyController.text = existing.currency;
      _basePriceController.text = existing.basePrice.toStringAsFixed(2);
      _vatPercentController.text = existing.vatPercent.toStringAsFixed(2);
      _discountPercentController.text =
          existing.supplierDiscountPercent.toStringAsFixed(2);
      _discountValueController.text =
          existing.supplierDiscountValue.toStringAsFixed(2);
      _greenStampController.text = existing.greenStampValue.toStringAsFixed(2);
      _transportController.text = existing.transportValue.toStringAsFixed(2);
      _otherCostController.text = existing.otherCostValue.toStringAsFixed(2);
      _notesController.text = existing.notes;
      _priceIncludesVat = existing.priceIncludesVat;
      _greenStampIncluded = existing.greenStampIncluded;
      _transportIncluded = existing.transportIncluded;
      _validFrom = existing.validFrom;
      _validTo = existing.validTo;
    } else {
      _currencyController.text = 'RON';
      _vatPercentController.text = widget.defaultVatPercent.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _currencyController.dispose();
    _basePriceController.dispose();
    _vatPercentController.dispose();
    _discountPercentController.dispose();
    _discountValueController.dispose();
    _greenStampController.dispose();
    _transportController.dispose();
    _otherCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Pret furnizor nou'
          : 'Editeaza pret furnizor'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 360,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedSupplierId != null &&
                            widget.suppliers.any(
                              (item) => item.id == _selectedSupplierId,
                            )
                        ? _selectedSupplierId
                        : null,
                    decoration:
                        const InputDecoration(labelText: 'Partener furnizor'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Furnizor liber'),
                      ),
                      ...widget.suppliers.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                        final supplier = widget.suppliers
                            .where((item) => item.id == value)
                            .fold<PartnerRecord?>(
                              null,
                              (previous, item) => item,
                            );
                        if (supplier != null) {
                          _supplierNameController.text = supplier.name;
                        }
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _supplierNameController,
                    decoration:
                        const InputDecoration(labelText: 'Nume furnizor'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _currencyController,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _basePriceController,
                    decoration: const InputDecoration(labelText: 'Pret baza'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        _parseDouble(value) <= 0 ? 'Completeaza pretul.' : null,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _vatPercentController,
                    decoration: const InputDecoration(labelText: 'TVA %'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _discountPercentController,
                    decoration: const InputDecoration(labelText: 'Discount %'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _discountValueController,
                    decoration:
                        const InputDecoration(labelText: 'Discount valoric'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _greenStampController,
                    decoration:
                        const InputDecoration(labelText: 'Timbru verde'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _transportController,
                    decoration: const InputDecoration(labelText: 'Transport'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _otherCostController,
                    decoration:
                        const InputDecoration(labelText: 'Alte costuri'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _priceIncludesVat,
                    onChanged: (value) =>
                        setState(() => _priceIncludesVat = value),
                    title: const Text('Pretul include TVA'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _greenStampIncluded,
                    onChanged: (value) =>
                        setState(() => _greenStampIncluded = value),
                    title: const Text('Timbru inclus'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _transportIncluded,
                    onChanged: (value) =>
                        setState(() => _transportIncluded = value),
                    title: const Text('Transport inclus'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Valabil de la',
                    value: _validFrom,
                    onTap: () async {
                      final picked = await _pickDate(_validFrom);
                      if (picked == null) return;
                      setState(() => _validFrom = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Valabil pana la',
                    value: _validTo,
                    onTap: () async {
                      final picked = await _pickDate(_validTo);
                      if (picked == null) return;
                      setState(() => _validTo = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observatii'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      SupplierPriceRecord(
        id: widget.existing?.id ??
            'supplier-price-${now.microsecondsSinceEpoch}',
        productId: widget.product.id,
        supplierId: _selectedSupplierId ?? '',
        supplierName: _supplierNameController.text.trim(),
        currency: _currencyController.text.trim().isEmpty
            ? 'RON'
            : _currencyController.text.trim().toUpperCase(),
        basePrice: _parseDouble(_basePriceController.text),
        priceIncludesVat: _priceIncludesVat,
        vatPercent: _parseDouble(_vatPercentController.text, fallback: 19),
        supplierDiscountPercent: _parseDouble(_discountPercentController.text),
        supplierDiscountValue: _parseDouble(_discountValueController.text),
        greenStampValue: _parseDouble(_greenStampController.text),
        greenStampIncluded: _greenStampIncluded,
        transportValue: _parseDouble(_transportController.text),
        transportIncluded: _transportIncluded,
        otherCostValue: _parseDouble(_otherCostController.text),
        notes: _notesController.text.trim(),
        registryEntryIds: widget.existing?.registryEntryIds ?? const <String>[],
        validFrom: _validFrom,
        validTo: _validTo,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _PriceListDialog extends StatefulWidget {
  const _PriceListDialog({this.existing});

  final PriceListRecord? existing;

  @override
  State<_PriceListDialog> createState() => _PriceListDialogState();
}

class _PriceListDialogState extends State<_PriceListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _currencyController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _collaboratorNameController = TextEditingController();
  final _notesController = TextEditingController();
  PriceListScope _scope = PriceListScope.standard;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _codeController.text = existing.code;
      _currencyController.text = existing.currency;
      _clientNameController.text = existing.clientName;
      _collaboratorNameController.text = existing.collaboratorName;
      _notesController.text = existing.notes;
      _scope = existing.scope;
      _isActive = existing.isActive;
    } else {
      _currencyController.text = 'RON';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _currencyController.dispose();
    _clientNameController.dispose();
    _collaboratorNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Lista comerciala noua'
          : 'Editeaza lista comerciala'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Denumire'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Completeaza denumirea.'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Cod'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _currencyController,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PriceListScope>(
                  initialValue: _scope,
                  decoration: const InputDecoration(labelText: 'Tip lista'),
                  items: PriceListScope.values
                      .map(
                        (item) => DropdownMenuItem<PriceListScope>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _scope = value);
                  },
                ),
                const SizedBox(height: 8),
                if (_scope == PriceListScope.dedicatedClient)
                  TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _clientNameController,
                    decoration:
                        const InputDecoration(labelText: 'Client dedicat'),
                  ),
                if (_scope == PriceListScope.collaborator) ...[
                  TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _collaboratorNameController,
                    decoration: const InputDecoration(labelText: 'Colaborator'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observatii'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Activa'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      PriceListRecord(
        id: widget.existing?.id ?? 'price-list-${now.microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        scope: _scope,
        currency: _currencyController.text.trim().isEmpty
            ? 'RON'
            : _currencyController.text.trim().toUpperCase(),
        clientId: widget.existing?.clientId ?? '',
        clientName: _clientNameController.text.trim(),
        collaboratorId: widget.existing?.collaboratorId ?? '',
        collaboratorName: _collaboratorNameController.text.trim(),
        notes: _notesController.text.trim(),
        isActive: _isActive,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _PriceListEntryDialog extends StatefulWidget {
  const _PriceListEntryDialog({
    required this.product,
    required this.priceList,
    this.existing,
    this.defaultVatPercent = 21.0,
  });

  final ProductCatalogRecord product;
  final PriceListRecord priceList;
  final PriceListEntryRecord? existing;
  final double defaultVatPercent;

  @override
  State<_PriceListEntryDialog> createState() => _PriceListEntryDialogState();
}

class _PriceListEntryDialogState extends State<_PriceListEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pricingValueController = TextEditingController();
  final _manualSalePriceController = TextEditingController();
  final _vatPercentController = TextEditingController();
  final _notesController = TextEditingController();
  SalePricingMode _pricingMode = SalePricingMode.markupPercent;
  PercentageBasis _percentageBasis = PercentageBasis.onCost;
  bool _priceIncludesVat = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _pricingValueController.text = existing.pricingValue.toStringAsFixed(2);
      _manualSalePriceController.text =
          existing.manualSalePrice.toStringAsFixed(2);
      _vatPercentController.text = existing.vatPercent.toStringAsFixed(2);
      _notesController.text = existing.notes;
      _pricingMode = existing.pricingMode;
      _percentageBasis = existing.percentageBasis;
      _priceIncludesVat = existing.priceIncludesVat;
    } else {
      _vatPercentController.text = widget.defaultVatPercent.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _pricingValueController.dispose();
    _manualSalePriceController.dispose();
    _vatPercentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configurare ${widget.priceList.name}'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<SalePricingMode>(
                  initialValue: _pricingMode,
                  decoration:
                      const InputDecoration(labelText: 'Regula pret vanzare'),
                  items: SalePricingMode.values
                      .map(
                        (item) => DropdownMenuItem<SalePricingMode>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _pricingMode = value);
                  },
                ),
                const SizedBox(height: 8),
                if (_pricingMode == SalePricingMode.targetProfitPercent)
                  DropdownButtonFormField<PercentageBasis>(
                    initialValue: _percentageBasis,
                    decoration:
                        const InputDecoration(labelText: 'Baza procent'),
                    items: PercentageBasis.values
                        .map(
                          (item) => DropdownMenuItem<PercentageBasis>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _percentageBasis = value);
                    },
                  ),
                if (_pricingMode == SalePricingMode.targetProfitPercent)
                  const SizedBox(height: 8),
                TextFormField(
                  controller: _pricingValueController,
                  decoration: const InputDecoration(
                    labelText: 'Valoare regula',
                    helperText:
                        'Procent sau valoare, in functie de regula aleasa.',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _manualSalePriceController,
                  decoration: const InputDecoration(
                    labelText: 'Override pret net',
                    helperText:
                        'Optional. Daca este completat, suprascrie calculul.',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vatPercentController,
                  decoration: const InputDecoration(labelText: 'TVA %'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _priceIncludesVat,
                  onChanged: (value) =>
                      setState(() => _priceIncludesVat = value),
                  title: const Text('Pret prezentare cu TVA'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Observatii'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  void _save() {
    final now = DateTime.now();
    Navigator.of(context).pop(
      PriceListEntryRecord(
        id: widget.existing?.id ??
            '${widget.priceList.id}_${widget.product.id}_${now.microsecondsSinceEpoch}',
        priceListId: widget.priceList.id,
        productId: widget.product.id,
        currency: widget.priceList.currency,
        pricingMode: _pricingMode,
        percentageBasis: _percentageBasis,
        pricingValue: _parseDouble(_pricingValueController.text),
        manualSalePrice: _parseDouble(_manualSalePriceController.text),
        vatPercent: _parseDouble(_vatPercentController.text, fallback: 19),
        priceIncludesVat: _priceIncludesVat,
        notes: _notesController.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _SaleDialog extends StatefulWidget {
  const _SaleDialog({
    required this.product,
    required this.clients,
    required this.partners,
    this.existing,
  });

  final ProductCatalogRecord product;
  final List<ClientRecord> clients;
  final List<PartnerRecord> partners;
  final ProductSaleRecord? existing;

  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _serialIndoorController = TextEditingController();
  final _serialOutdoorController = TextEditingController();
  final _warrantyMonthsController = TextEditingController();
  final _installerDisplayNameController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedClientId;
  ProductSaleStatus _saleStatus = ProductSaleStatus.draft;
  InstallerType _installerType = InstallerType.ownCompany;
  String? _selectedInstallerPartnerId;
  DateTime? _saleDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedClientId =
          existing.clientId.trim().isEmpty ? null : existing.clientId;
      _clientNameController.text = existing.clientName;
      _invoiceNumberController.text = existing.invoiceNumber;
      _serialIndoorController.text = existing.serialNumberIndoor;
      _serialOutdoorController.text = existing.serialNumberOutdoor;
      _warrantyMonthsController.text = existing.warrantyMonths.toString();
      _installerDisplayNameController.text = existing.installerDisplayName;
      _notesController.text = existing.notes;
      _saleStatus = existing.saleStatus;
      _installerType = existing.installerType;
      _selectedInstallerPartnerId = existing.installerPartnerId.trim().isEmpty
          ? null
          : existing.installerPartnerId;
      _saleDate = existing.saleDate;
    } else {
      _warrantyMonthsController.text = '24';
      _saleDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _invoiceNumberController.dispose();
    _serialIndoorController.dispose();
    _serialOutdoorController.dispose();
    _warrantyMonthsController.dispose();
    _installerDisplayNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Vanzare noua' : 'Editeaza vanzarea'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 360,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedClientId != null &&
                            widget.clients.any(
                              (item) => item.id == _selectedClientId,
                            )
                        ? _selectedClientId
                        : null,
                    decoration: const InputDecoration(labelText: 'Client'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Client liber'),
                      ),
                      ...widget.clients.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedClientId = value;
                        final client = widget.clients
                            .where((item) => item.id == value)
                            .fold<ClientRecord?>(
                              null,
                              (previous, item) => item,
                            );
                        if (client != null) {
                          _clientNameController.text = client.name;
                        }
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _clientNameController,
                    decoration: const InputDecoration(labelText: 'Nume client'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Completeaza clientul.'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<ProductSaleStatus>(
                    initialValue: _saleStatus,
                    decoration:
                        const InputDecoration(labelText: 'Status comercial'),
                    items: ProductSaleStatus.values
                        .map(
                          (item) => DropdownMenuItem<ProductSaleStatus>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _saleStatus = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data vanzare',
                    value: _saleDate,
                    onTap: () async {
                      final picked = await _pickDate(_saleDate);
                      if (picked == null) return;
                      setState(() => _saleDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(labelText: 'Factura'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialIndoorController,
                    decoration: const InputDecoration(labelText: 'Serie UI'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialOutdoorController,
                    decoration: const InputDecoration(labelText: 'Serie UE'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _warrantyMonthsController,
                    decoration:
                        const InputDecoration(labelText: 'Garantie luni'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<InstallerType>(
                    initialValue: _installerType,
                    decoration: const InputDecoration(
                        labelText: 'Instalator / service'),
                    items: InstallerType.values
                        .map(
                          (item) => DropdownMenuItem<InstallerType>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _installerType = value;
                        if (_installerType == InstallerType.ownCompany) {
                          _selectedInstallerPartnerId = null;
                        }
                      });
                    },
                  ),
                ),
                if (_installerType == InstallerType.partner)
                  SizedBox(
                    width: 360,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedInstallerPartnerId != null &&
                              widget.partners.any(
                                (item) =>
                                    item.id == _selectedInstallerPartnerId,
                              )
                          ? _selectedInstallerPartnerId
                          : null,
                      decoration: const InputDecoration(
                          labelText: 'Partener instalator'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Colaborator liber'),
                        ),
                        ...widget.partners.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedInstallerPartnerId = value;
                          final partner = widget.partners
                              .where((item) => item.id == value)
                              .fold<PartnerRecord?>(
                                null,
                                (previous, item) => item,
                              );
                          if (partner != null &&
                              _installerDisplayNameController.text
                                  .trim()
                                  .isEmpty) {
                            _installerDisplayNameController.text = partner.name;
                          }
                        });
                      },
                    ),
                  ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerDisplayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Denumire afisata instalator',
                    ),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observatii'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.of(context).pop(
      ProductSaleRecord(
        id: widget.existing?.id ?? 'sale-${now.microsecondsSinceEpoch}',
        productId: widget.product.id,
        productName: widget.product.name,
        clientId: _selectedClientId ?? '',
        clientName: _clientNameController.text.trim(),
        saleStatus: _saleStatus,
        saleDate: _saleDate,
        invoiceNumber: _invoiceNumberController.text.trim(),
        serialNumberIndoor: _serialIndoorController.text.trim(),
        serialNumberOutdoor: _serialOutdoorController.text.trim(),
        warrantyMonths: _parseInt(_warrantyMonthsController.text, fallback: 24),
        installerType: _installerType,
        installerPartnerId: _installerType == InstallerType.partner
            ? (_selectedInstallerPartnerId ?? '')
            : '',
        installerDisplayName: _installerDisplayNameController.text.trim(),
        notes: _notesController.text.trim(),
        warrantyCertificateId: widget.existing?.warrantyCertificateId ?? '',
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _WarrantyCertificateDialog extends StatefulWidget {
  const _WarrantyCertificateDialog({
    required this.initial,
  });

  final WarrantyCertificateRecord initial;

  @override
  State<_WarrantyCertificateDialog> createState() =>
      _WarrantyCertificateDialogState();
}

class _WarrantyCertificateDialogState
    extends State<_WarrantyCertificateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seriesController;
  late final TextEditingController _numberController;
  late final TextEditingController _equipmentTypeController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _serialIndoorController;
  late final TextEditingController _serialOutdoorController;
  late final TextEditingController _invoiceController;
  late final TextEditingController _warrantyMonthsController;
  late final TextEditingController _sellerNameController;
  late final TextEditingController _sellerAddressController;
  late final TextEditingController _sellerEmailController;
  late final TextEditingController _sellerPhoneController;
  late final TextEditingController _sellerTaxIdController;
  late final TextEditingController _buyerNameController;
  late final TextEditingController _buyerAddressController;
  late final TextEditingController _buyerPhoneController;
  late final TextEditingController _buyerTaxIdController;
  late final TextEditingController _installerNameController;
  late final TextEditingController _installerAddressController;
  late final TextEditingController _installerEmailController;
  late final TextEditingController _installerPhoneController;
  late final TextEditingController _installerTaxIdController;
  late final TextEditingController _installerPersonsController;
  late final TextEditingController _termsController;

  DateTime? _documentDate;
  DateTime? _saleDate;
  DateTime? _installationDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _seriesController = TextEditingController(text: initial.certificateSeries);
    _numberController = TextEditingController(text: initial.certificateNumber);
    _equipmentTypeController =
        TextEditingController(text: initial.equipmentType);
    _brandController = TextEditingController(text: initial.brand);
    _modelController = TextEditingController(text: initial.model);
    _serialIndoorController =
        TextEditingController(text: initial.serialNumberIndoor);
    _serialOutdoorController =
        TextEditingController(text: initial.serialNumberOutdoor);
    _invoiceController = TextEditingController(text: initial.invoiceNumber);
    _warrantyMonthsController =
        TextEditingController(text: initial.warrantyMonths.toString());
    _sellerNameController = TextEditingController(text: initial.sellerName);
    _sellerAddressController =
        TextEditingController(text: initial.sellerAddress);
    _sellerEmailController = TextEditingController(text: initial.sellerEmail);
    _sellerPhoneController = TextEditingController(text: initial.sellerPhone);
    _sellerTaxIdController = TextEditingController(text: initial.sellerTaxId);
    _buyerNameController = TextEditingController(text: initial.buyerName);
    _buyerAddressController = TextEditingController(text: initial.buyerAddress);
    _buyerPhoneController = TextEditingController(text: initial.buyerPhone);
    _buyerTaxIdController = TextEditingController(text: initial.buyerTaxOrCnp);
    _installerNameController =
        TextEditingController(text: initial.installerName);
    _installerAddressController =
        TextEditingController(text: initial.installerAddress);
    _installerEmailController =
        TextEditingController(text: initial.installerEmail);
    _installerPhoneController =
        TextEditingController(text: initial.installerPhone);
    _installerTaxIdController =
        TextEditingController(text: initial.installerTaxId);
    _installerPersonsController =
        TextEditingController(text: initial.installerPersons);
    _termsController = TextEditingController(text: initial.termsText);
    _documentDate = initial.documentDate;
    _saleDate = initial.saleDate;
    _installationDate = initial.installationDate;
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _numberController.dispose();
    _equipmentTypeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialIndoorController.dispose();
    _serialOutdoorController.dispose();
    _invoiceController.dispose();
    _warrantyMonthsController.dispose();
    _sellerNameController.dispose();
    _sellerAddressController.dispose();
    _sellerEmailController.dispose();
    _sellerPhoneController.dispose();
    _sellerTaxIdController.dispose();
    _buyerNameController.dispose();
    _buyerAddressController.dispose();
    _buyerPhoneController.dispose();
    _buyerTaxIdController.dispose();
    _installerNameController.dispose();
    _installerAddressController.dispose();
    _installerEmailController.dispose();
    _installerPhoneController.dispose();
    _installerTaxIdController.dispose();
    _installerPersonsController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Certificat de garantie'),
      content: SizedBox(
        width: 980,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _seriesController,
                    decoration: const InputDecoration(labelText: 'Serie'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _numberController,
                    decoration: const InputDecoration(labelText: 'Numar'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data document',
                    value: _documentDate,
                    onTap: () async {
                      final picked = await _pickDate(_documentDate);
                      if (picked == null) return;
                      setState(() => _documentDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data vanzare',
                    value: _saleDate,
                    onTap: () async {
                      final picked = await _pickDate(_saleDate);
                      if (picked == null) return;
                      setState(() => _saleDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _DateField(
                    label: 'Data instalare',
                    value: _installationDate,
                    onTap: () async {
                      final picked = await _pickDate(_installationDate);
                      if (picked == null) return;
                      setState(() => _installationDate = picked);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _warrantyMonthsController,
                    decoration:
                        const InputDecoration(labelText: 'Garantie luni'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _equipmentTypeController,
                    decoration:
                        const InputDecoration(labelText: 'Tip echipament'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _modelController,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _invoiceController,
                    decoration: const InputDecoration(labelText: 'Factura'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialIndoorController,
                    decoration: const InputDecoration(labelText: 'Serie UI'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _serialOutdoorController,
                    decoration: const InputDecoration(labelText: 'Serie UE'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - denumire'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _sellerEmailController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - email'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _sellerPhoneController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _sellerTaxIdController,
                    decoration:
                        const InputDecoration(labelText: 'Vanzator - CUI/CIF'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerNameController,
                    decoration:
                        const InputDecoration(labelText: 'Cumparator - nume'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Cumparator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _buyerPhoneController,
                    decoration: const InputDecoration(
                        labelText: 'Cumparator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _buyerTaxIdController,
                    decoration: const InputDecoration(
                        labelText: 'Cumparator - CUI/CNP'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerNameController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - denumire'),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerAddressController,
                    decoration:
                        const InputDecoration(labelText: 'Instalator - adresa'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _installerEmailController,
                    decoration:
                        const InputDecoration(labelText: 'Instalator - email'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerPhoneController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - telefon'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _installerTaxIdController,
                    decoration: const InputDecoration(
                        labelText: 'Instalator - CUI/CIF'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _installerPersonsController,
                    decoration:
                        const InputDecoration(labelText: 'Persoane instalare'),
                  ),
                ),
                SizedBox(
                  width: 956,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _termsController,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Condiții de garanție',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      widget.initial.copyWith(
        certificateSeries: _seriesController.text.trim(),
        certificateNumber: _numberController.text.trim(),
        documentDate: _documentDate,
        equipmentType: _equipmentTypeController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        serialNumberIndoor: _serialIndoorController.text.trim(),
        serialNumberOutdoor: _serialOutdoorController.text.trim(),
        invoiceNumber: _invoiceController.text.trim(),
        saleDate: _saleDate,
        warrantyMonths: _parseInt(_warrantyMonthsController.text, fallback: 24),
        sellerName: _sellerNameController.text.trim(),
        sellerAddress: _sellerAddressController.text.trim(),
        sellerEmail: _sellerEmailController.text.trim(),
        sellerPhone: _sellerPhoneController.text.trim(),
        sellerTaxId: _sellerTaxIdController.text.trim(),
        buyerName: _buyerNameController.text.trim(),
        buyerAddress: _buyerAddressController.text.trim(),
        buyerPhone: _buyerPhoneController.text.trim(),
        buyerTaxOrCnp: _buyerTaxIdController.text.trim(),
        installerName: _installerNameController.text.trim(),
        installerAddress: _installerAddressController.text.trim(),
        installerEmail: _installerEmailController.text.trim(),
        installerPhone: _installerPhoneController.text.trim(),
        installerTaxId: _installerTaxIdController.text.trim(),
        installerPersons: _installerPersonsController.text.trim(),
        installationDate: _installationDate,
        termsText: _termsController.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value == null
              ? '-'
              : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}',
        ),
      ),
    );
  }
}

List<String> _splitLines(String raw) {
  return raw
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _parseInt(String? raw, {int fallback = 0}) {
  return int.tryParse((raw ?? '').trim()) ?? fallback;
}

double _parseDouble(String? raw, {double fallback = 0}) {
  return double.tryParse((raw ?? '').trim().replaceAll(',', '.')) ?? fallback;
}

String _fileNameFromPath(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return '';
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}
