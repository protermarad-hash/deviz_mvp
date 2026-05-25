import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../integrations/smartbill_service.dart';
import '../integrations/smartbill_stock_cache_service.dart';
import '../smartbill_settings.dart';

/// Un articol de bon consum (intrare din dialog).
class BonConsumArticol {
  BonConsumArticol({
    required this.denumire,
    required this.cantitate,
    required this.um,
    this.cod = '',
    this.pretUnitar = 0,
  });

  final String denumire;
  double cantitate;
  final String um;
  final String cod;
  final double pretUnitar;
}

/// Dialog pentru emiterea unui bon de consum în SmartBill.
/// Preia lista de articole din documentul curent (ofertă/deviz).
/// Permite editarea cantităților înainte de trimitere.
class SmartBillBonConsumDialog extends StatefulWidget {
  const SmartBillBonConsumDialog({
    super.key,
    required this.settings,
    required this.articole,
    required this.documentTitle,
    this.stockMap = const {},
  });

  final SmartBillSettings settings;

  /// Lista materialelor din document (numai materiale, nu manoperă).
  final List<BonConsumArticol> articole;

  /// Titlul documentului (pentru afișare în dialog).
  final String documentTitle;

  /// Stocul disponibil din SmartBill (poate fi gol dacă nu s-a sincronizat).
  final Map<String, SmartBillStockItem> stockMap;

  @override
  State<SmartBillBonConsumDialog> createState() =>
      _SmartBillBonConsumDialogState();
}

class _SmartBillBonConsumDialogState extends State<SmartBillBonConsumDialog> {
  late List<_ArticolState> _articole;
  bool _loading = false;
  bool _syncingStock = false;
  late Map<String, SmartBillStockItem> _stockMap;
  DateTime _dataBon = DateTime.now();
  final _smartBillService = SmartBillService();
  final _stockCacheService = SmartBillStockCacheService();
  final _fmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _stockMap = Map.from(widget.stockMap);
    _articole = widget.articole
        .map((a) => _ArticolState(
              denumire: a.denumire,
              cod: a.cod,
              um: a.um,
              cantitateCtrl:
                  TextEditingController(text: _fmtQ(a.cantitate)),
              pretUnitar: a.pretUnitar,
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final a in _articole) {
      a.cantitateCtrl.dispose();
    }
    super.dispose();
  }

  String _fmtQ(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(3);

  /// Sincronizare manuală stoc SmartBill
  Future<void> _syncStock() async {
    setState(() => _syncingStock = true);
    try {
      final updated = await _stockCacheService.syncFromSmartBill(widget.settings);
      if (!mounted) return;
      setState(() => _stockMap = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stoc actualizat: ${updated.length} articole din SmartBill.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on SmartBillApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare stoc SmartBill: ${e.message}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncingStock = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataBon,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _dataBon = picked);
    }
  }

  /// Emite bonul de consum în SmartBill
  Future<void> _emiteBon() async {
    // Validare: cel puțin un articol cu cantitate > 0
    final linii = <SmartBillConsumptionLine>[];
    for (final a in _articole) {
      if (!a.inclus) continue;
      final qty = double.tryParse(
            a.cantitateCtrl.text.replaceAll(',', '.').trim(),
          ) ??
          0;
      if (qty <= 0) continue;
      linii.add(SmartBillConsumptionLine(
        name: a.denumire,
        code: a.cod,
        quantity: qty,
        unit: a.um.isNotEmpty ? a.um : 'buc',
        unitPrice: a.pretUnitar,
      ));
    }

    if (linii.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adaugă cel puțin un articol cu cantitate mai mare de 0.'),
        ),
      );
      return;
    }

    if (widget.settings.consumptionSeriesName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurează seria bonului de consum în Setări SmartBill.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _smartBillService.createConsumptionNote(
        widget.settings,
        warehouseName: widget.settings.consumptionWarehouseName,
        seriesName: widget.settings.consumptionSeriesName,
        date: _dataBon,
        lines: linii,
      );
      if (!mounted) return;
      Navigator.of(context).pop(response);
    } on SmartBillApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare SmartBill: ${e.message}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  SmartBillStockItem? _stocPentru(String denumire) {
    final key = denumire.trim().toLowerCase();
    if (_stockMap.containsKey(key)) return _stockMap[key];
    // Potrivire parțială
    for (final entry in _stockMap.entries) {
      if (entry.key.contains(key) || key.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nrIncluse = _articole.where((a) => a.inclus).length;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Emite bon de consum SmartBill',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              // Buton refresh stoc
              _syncingStock
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync, size: 20),
                      tooltip: 'Actualizează stoc din SmartBill',
                      onPressed: _syncStock,
                    ),
            ],
          ),
          Text(
            widget.documentTitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gestiune și serie
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warehouse_outlined,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Gestiune: ${widget.settings.consumptionWarehouseName.isNotEmpty ? widget.settings.consumptionWarehouseName : "— neconfigurata —"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.numbers, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Serie: ${widget.settings.consumptionSeriesName.isNotEmpty ? widget.settings.consumptionSeriesName : "— neconfigurata —"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        // Data bon
                        InkWell(
                          onTap: _loading ? null : _selectDate,
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 13, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                _fmt.format(_dataBon),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Header tabel
              if (_articole.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nu există materiale în acest document.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        flex: 4,
                        child: Text(
                          'Articol',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 70,
                        child: Text(
                          'Cant.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 40,
                        child: Text(
                          'UM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 70,
                        child: Text(
                          'Stoc',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 8),
                // Lista articole
                ...List.generate(_articole.length, (i) {
                  final a = _articole[i];
                  final stoc = _stocPentru(a.denumire);
                  return _ArticolRow(
                    articol: a,
                    stoc: stoc,
                    enabled: !_loading,
                    onToggle: (v) => setState(() => a.inclus = v),
                  );
                }),
                const Divider(height: 8),
                Text(
                  '$nrIncluse din ${_articole.length} articole selectate',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              // Avertisment stoc gol
              if (_stockMap.isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Stocul SmartBill nu este sincronizat. Apasă butonul ↻ pentru a-l prelua.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Anulează'),
        ),
        FilledButton.icon(
          onPressed: (_loading || _articole.isEmpty) ? null : _emiteBon,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(_loading ? 'Se emite...' : 'Emite bon consum'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Starea unui articol în dialog
// ---------------------------------------------------------------------------

class _ArticolState {
  _ArticolState({
    required this.denumire,
    required this.cod,
    required this.um,
    required this.cantitateCtrl,
    this.pretUnitar = 0,
  });

  final String denumire;
  final String cod;
  final String um;
  final TextEditingController cantitateCtrl;
  final double pretUnitar;
  bool inclus = true;
}

// ---------------------------------------------------------------------------
// Rând articol în tabel
// ---------------------------------------------------------------------------

class _ArticolRow extends StatelessWidget {
  const _ArticolRow({
    required this.articol,
    required this.stoc,
    required this.enabled,
    required this.onToggle,
  });

  final _ArticolState articol;
  final SmartBillStockItem? stoc;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stocQty = stoc?.quantity ?? -1;
    final stocColor = stocQty < 0
        ? cs.onSurfaceVariant
        : stocQty == 0
            ? Colors.red.shade600
            : Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox includere
          SizedBox(
            width: 36,
            child: Checkbox(
              value: articol.inclus,
              onChanged: enabled ? (v) => onToggle(v ?? false) : null,
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Denumire
          Expanded(
            flex: 4,
            child: Text(
              articol.denumire,
              style: TextStyle(
                fontSize: 12,
                color: articol.inclus ? null : cs.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Cantitate editabilă
          SizedBox(
            width: 70,
            child: TextField(
              controller: articol.cantitateCtrl,
              enabled: enabled && articol.inclus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // UM
          SizedBox(
            width: 36,
            child: Text(
              articol.um,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          // Stoc disponibil
          SizedBox(
            width: 70,
            child: stocQty < 0
                ? Text(
                    '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Text(
                    stocQty.toStringAsFixed(stocQty == stocQty.truncateToDouble() ? 0 : 2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: stocColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
