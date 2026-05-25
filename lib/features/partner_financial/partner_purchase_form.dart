import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/cloud/offline_sync_runtime.dart';
import '../notifications/notification_runtime_service.dart';
import 'partner_financial_models.dart';
import 'partner_financial_repository.dart';

/// Formular achiziție produs/serviciu de la partener.
class PartnerPurchaseForm extends StatefulWidget {
  const PartnerPurchaseForm({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  final String partnerId;
  final String partnerName;

  @override
  State<PartnerPurchaseForm> createState() => _PartnerPurchaseFormState();
}

class _PartnerPurchaseFormState extends State<PartnerPurchaseForm> {
  final _financialRepo = PartnerFinancialRepository();
  final _fmt = NumberFormat('#,##0.00', 'ro_RO');

  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'buc');
  final _notesCtrl = TextEditingController();

  bool _saving = false;
  var _selectedDate = DateTime.now();
  var _paymentMethod = PartnerTransactionPaymentMethod.cash;
  var _status = PartnerTransactionStatus.neplatit;

  @override
  void dispose() {
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _qty =>
      double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _price =>
      double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _total => _qty * _price;

  Future<void> _save() async {
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Completează descrierea produsului/serviciului.');
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

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final unitText = _unitCtrl.text.trim();
      final transaction = PartnerTransaction(
        id: PartnerTransaction.generateId(),
        partnerId: widget.partnerId,
        partnerName: widget.partnerName,
        type: PartnerTransactionType.achizitieProodus,
        direction: PartnerTransactionDirection.iesire,
        amount: _total,
        date: _selectedDate,
        description:
            '${_descCtrl.text.trim()} × ${_qty.toStringAsFixed(_qty == _qty.roundToDouble() ? 0 : 2)}'
            '${unitText.isNotEmpty ? ' $unitText' : ''}',
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Achiziție ← ${widget.partnerName}'),
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
              'Produs / Serviciu achiziționat',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descriere produs/serviciu',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'ex: Manoperă montaj, Material X...',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantitate',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'UM',
                      hintText: 'buc',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total achiziție:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_fmt.format(_total)} RON',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Text(
              'Detalii plată',
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
                    (m) => DropdownMenuItem(value: m, child: Text(m.label)),
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
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
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
