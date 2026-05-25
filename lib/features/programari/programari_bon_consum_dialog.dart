import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/integrations/smartbill_service.dart';
import '../../core/smartbill_settings.dart';
import 'appointment_models.dart';

/// Dialog pentru trimiterea unui bon de consum în SmartBill,
/// pe baza materialelor folosite la o programare.
class ProgramariBonConsumDialog extends StatefulWidget {
  const ProgramariBonConsumDialog({
    super.key,
    required this.appointment,
    required this.settings,
    required this.lines,
  });

  final Appointment appointment;
  final SmartBillSettings settings;
  final List<AppointmentMaterialUsageLine> lines;

  @override
  State<ProgramariBonConsumDialog> createState() =>
      _ProgramariBonConsumDialogState();
}

class _ProgramariBonConsumDialogState
    extends State<ProgramariBonConsumDialog> {
  late final TextEditingController _warehouseCtrl;
  late final TextEditingController _seriesCtrl;
  DateTime _date = DateTime.now();
  bool _sending = false;
  String _resultMessage = '';
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _warehouseCtrl = TextEditingController(
      text: widget.settings.consumptionWarehouseName,
    );
    _seriesCtrl = TextEditingController(
      text: widget.settings.consumptionSeriesName,
    );
  }

  @override
  void dispose() {
    _warehouseCtrl.dispose();
    _seriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _trimite() async {
    final warehouse = _warehouseCtrl.text.trim();
    final series = _seriesCtrl.text.trim();
    if (warehouse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completează gestiunea.')),
      );
      return;
    }
    if (series.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completează seria bonului de consum.')),
      );
      return;
    }

    setState(() {
      _sending = true;
      _resultMessage = '';
      _success = false;
    });

    try {
      final service = SmartBillService();
      final sbLines = widget.lines.map((line) {
        return SmartBillConsumptionLine(
          name: line.name,
          code: line.materialId,
          quantity: line.quantity,
          unit: line.unit,
          unitPrice: line.unitCost,
        );
      }).toList();

      final response = await service.createConsumptionNote(
        widget.settings,
        warehouseName: warehouse,
        seriesName: series,
        date: _date,
        lines: sbLines,
      );

      if (mounted) {
        setState(() {
          _success = true;
          _resultMessage = response.documentLabel.isNotEmpty
              ? 'Bon de consum creat: ${response.documentLabel}'
              : 'Bon de consum trimis cu succes în SmartBill!';
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _success = false;
          _resultMessage = 'Eroare: $e';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final lines = widget.lines;

    return AlertDialog(
      title: const Text('Bon de consum SmartBill'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Programare: ${widget.appointment.title.isNotEmpty ? widget.appointment.title : 'fără titlu'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              Text(
                'Materiale (${lines.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...lines.map((line) {
                final qty = line.quantity;
                final qtyStr = qty == qty.truncateToDouble()
                    ? qty.toInt().toString()
                    : qty.toStringAsFixed(2);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '$qtyStr ${line.unit}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 20),

              TextFormField(
                controller: _warehouseCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Gestiune',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _seriesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Serie bon consum',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Data bonului'),
                subtitle: Text(fmt.format(_date)),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: _sending
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          locale: const Locale('ro'),
                        );
                        if (picked != null && mounted) {
                          setState(() => _date = picked);
                        }
                      },
              ),

              if (_resultMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        _success ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(
                      color: _success
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: _success
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resultMessage,
                          style: TextStyle(
                            color: _success
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 13,
                          ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_success ? 'Închide' : 'Anulează'),
        ),
        if (!_success)
          FilledButton.icon(
            onPressed: _sending ? null : _trimite,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Se trimite...' : 'Trimite la SmartBill'),
          ),
      ],
    );
  }
}
