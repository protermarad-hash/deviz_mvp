import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/offline_sync_runtime.dart';
import '../notifications/notification_runtime_service.dart';
import '../product_catalog/product_catalog_models.dart';
import '../product_catalog/product_catalog_service.dart';
import 'partner_financial_models.dart';
import 'partner_financial_repository.dart';

/// Formular vânzare produs către partener.
/// Căutare în catalogul de produse, completare cantitate/preț,
/// scădere automată stoc la salvare.
class PartnerSaleForm extends StatefulWidget {
  const PartnerSaleForm({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  final String partnerId;
  final String partnerName;

  @override
  State<PartnerSaleForm> createState() => _PartnerSaleFormState();
}

class _PartnerSaleFormState extends State<PartnerSaleForm> {
  final _catalogService = ProductCatalogService();
  final _financialRepo = PartnerFinancialRepository();
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');

  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loadingProducts = true;
  bool _saving = false;
  List<ProductCatalogRecord> _allProducts = const [];
  List<ProductCatalogRecord> _filtered = const [];
  ProductCatalogRecord? _selected;
  var _selectedDate = DateTime.now();
  var _paymentMethod = PartnerTransactionPaymentMethod.cash;
  var _status = PartnerTransactionStatus.neplatit;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _catalogService.listProducts();
    if (!mounted) return;
    setState(() {
      _allProducts = products
          .where((p) => p.isActive)
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      _filtered = _allProducts;
      _loadingProducts = false;
    });
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allProducts
          : _allProducts
              .where((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.sku.toLowerCase().contains(query) ||
                  p.brand.toLowerCase().contains(query))
              .toList();
    });
  }

  void _selectProduct(ProductCatalogRecord product) {
    setState(() {
      _selected = product;
      _priceCtrl.text = product.listPrice > 0
          ? product.listPrice.toStringAsFixed(2)
          : '';
    });
  }

  double get _qty =>
      double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _price =>
      double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _total => _qty * _price;

  Future<void> _save() async {
    if (_selected == null) {
      _showError('Selectează un produs din catalog.');
      return;
    }
    if (_qty <= 0) {
      _showError('Cantitatea trebuie să fie mai mare decât 0.');
      return;
    }
    if (_price <= 0) {
      _showError('Prețul trebuie să fie mai mare decât 0.');
      return;
    }
    if (_selected!.stockQuantity > 0 && _qty > _selected!.stockQuantity) {
      final confirm = await _confirmInsuficientStoc();
      if (!confirm) return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final transaction = PartnerTransaction(
        id: PartnerTransaction.generateId(),
        partnerId: widget.partnerId,
        partnerName: widget.partnerName,
        type: PartnerTransactionType.vanzareProdus,
        direction: PartnerTransactionDirection.intrare,
        amount: _total,
        date: _selectedDate,
        description:
            '${_selected!.name} × ${_qty.toStringAsFixed(_qty == _qty.roundToDouble() ? 0 : 2)} ${_selected!.unit}',
        referenceId: _selected!.id,
        referenceType: 'produs_catalog',
        paymentMethod: _paymentMethod,
        status: _status,
        notes: _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _financialRepo.upsertTransaction(transaction);
      await OfflineSyncRuntime.instance.queuePartnerTransactionUpsert(
        transaction.toMap(),
      );

      // Scade stocul din catalog dacă produsul are stoc pozitiv
      if (_selected!.stockQuantity > 0) {
        final newQty = (_selected!.stockQuantity - _qty).clamp(0.0, double.infinity);
        final updated = _selected!.copyWith(
          stockQuantity: newQty,
          stockUpdatedAt: now,
          updatedAt: now,
        );
        await _catalogService.saveProduct(updated);
      }

      // Verifică sold net și trimite alertă locală dacă < -1000 RON
      final summary = await _financialRepo.getSummaryForPartner(
        widget.partnerId,
      );
      if (summary != null && summary.soldNet < -1000) {
        await NotificationRuntimeService.instance.showLocalNotification(
          title: '⚠️ Sold negativ partener',
          body:
              '${widget.partnerName}: sold net ${_fmt.format(summary.soldNet)} RON',
          data: <String, dynamic>{
            'partner_id': widget.partnerId,
            'module': 'partner_financial',
          },
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) _showError('Eroare la salvare. Încearcă din nou.');
    }
  }

  Future<bool> _confirmInsuficientStoc() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stoc insuficient'),
            content: Text(
              'Stocul disponibil este ${_selected!.stockQuantity.toStringAsFixed(2)} ${_selected!.unit}, '
              'dar vinzi ${_qty.toStringAsFixed(2)}. Continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Renunță'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continuă'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  Widget _buildProductSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Caută produs',
            prefixIcon: Icon(Icons.search),
            hintText: 'Nume, SKU sau marcă...',
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingProducts)
          const LinearProgressIndicator()
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Niciun produs găsit.'),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final p = _filtered[i];
                final isSelected = _selected?.id == p.id;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  title: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_fmt.format(p.listPrice)} RON/${p.unit}'
                    '${p.stockQuantity > 0 ? ' · Stoc: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit}' : ''}',
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () => _selectProduct(p),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vânzare → ${widget.partnerName}'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Salvează'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Selectează produsul',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildProductSearch(),
            const Divider(height: 24),
            Text(
              '2. Cantitate și preț',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cantitate',
                      suffixText: _selected?.unit ?? 'buc',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preț unitar (RON)',
                      suffixText: 'RON',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_qty > 0 && _price > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total vânzare:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_fmt.format(_total)} RON',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Text(
              '3. Detalii plată',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                'Data: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PartnerTransactionPaymentMethod>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Metodă plată'),
              items: PartnerTransactionPaymentMethod.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _paymentMethod = v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PartnerTransactionStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status plată'),
              items: PartnerTransactionStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (opțional)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
