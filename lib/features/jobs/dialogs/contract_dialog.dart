import 'package:flutter/material.dart';

import '../contract_pdf_service.dart';

/// Dialog auto-conținut pentru completarea datelor de contract înainte de
/// generarea PDF-ului. Totalurile (materiale/manoperă) și datele lucrării sunt
/// calculate de pagină și pasate ca parametri. Extras din
/// `lucrare_detalii_page.dart` (Faza 1).
Future<ContractData?> showContractDialog(
  BuildContext context, {
  required double materialTotal,
  required double laborTotal,
  required String clientName,
  required String jobCode,
  required String jobTitle,
  required String location,
  required String teamName,
  required String teamMembers,
}) async {
  final now = DateTime.now();
  final dateFmt =
      '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

  final numberCtrl = TextEditingController();
  final dateCtrl = TextEditingController(text: dateFmt);
  final clientCtrl = TextEditingController(text: clientName.trim());
  final execTermCtrl = TextEditingController();
  final payTermCtrl =
      TextEditingController(text: '30 zile de la emiterea facturii');
  final advanceCtrl = TextEditingController(text: '-');
  final installCtrl = TextEditingController(text: '-');
  final obsCtrl = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Contract de prestări servicii'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _contractField(numberCtrl, 'Număr contract', 'ex: 001/2026'),
              _contractField(dateCtrl, 'Data contractului', ''),
              _contractField(clientCtrl, 'Beneficiar (client)', ''),
              _contractField(
                  execTermCtrl, 'Termen execuție', 'ex: 30 zile calendaristice'),
              _contractField(payTermCtrl, 'Termen plată', ''),
              _contractField(
                  advanceCtrl, 'Avans', 'ex: 30% din valoarea contractului'),
              _contractField(installCtrl, 'Tranșe de plată',
                  'ex: 30% avans + 70% la recepție'),
              _contractField(obsCtrl, 'Observații suplimentare', '',
                  maxLines: 3),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valoare contract:',
                        style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text('Materiale: ${materialTotal.toStringAsFixed(2)} RON'),
                    Text('Manoperă: ${laborTotal.toStringAsFixed(2)} RON'),
                    Text(
                        'Subtotal: ${(materialTotal + laborTotal).toStringAsFixed(2)} RON'),
                    Text(
                        'TVA 19%: ${((materialTotal + laborTotal) * 0.19).toStringAsFixed(2)} RON'),
                    Text(
                      'TOTAL: ${((materialTotal + laborTotal) * 1.19).toStringAsFixed(2)} RON',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Generează PDF'),
        ),
      ],
    ),
  );

  if (result != true) {
    numberCtrl.dispose();
    dateCtrl.dispose();
    clientCtrl.dispose();
    execTermCtrl.dispose();
    payTermCtrl.dispose();
    advanceCtrl.dispose();
    installCtrl.dispose();
    obsCtrl.dispose();
    return null;
  }

  final data = ContractData(
    contractNumber: numberCtrl.text.trim(),
    contractDate:
        dateCtrl.text.trim().isEmpty ? dateFmt : dateCtrl.text.trim(),
    clientName:
        clientCtrl.text.trim().isEmpty ? clientName : clientCtrl.text.trim(),
    jobCode: jobCode,
    jobTitle: jobTitle,
    location: location,
    teamName: teamName,
    teamMembers: teamMembers,
    materialTotal: materialTotal,
    laborTotal: laborTotal,
    vatPercent: 19.0,
    executionTerm:
        execTermCtrl.text.trim().isEmpty ? '-' : execTermCtrl.text.trim(),
    paymentTerm:
        payTermCtrl.text.trim().isEmpty ? '-' : payTermCtrl.text.trim(),
    advance: advanceCtrl.text.trim().isEmpty ? '-' : advanceCtrl.text.trim(),
    installments:
        installCtrl.text.trim().isEmpty ? '-' : installCtrl.text.trim(),
    observations: obsCtrl.text.trim(),
  );

  numberCtrl.dispose();
  dateCtrl.dispose();
  clientCtrl.dispose();
  execTermCtrl.dispose();
  payTermCtrl.dispose();
  advanceCtrl.dispose();
  installCtrl.dispose();
  obsCtrl.dispose();

  return data;
}

Widget _contractField(
  TextEditingController ctrl,
  String label,
  String hint, {
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}
