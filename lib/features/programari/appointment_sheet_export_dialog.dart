import 'package:flutter/material.dart';

import 'appointment_sheet_pdf_service.dart';

/// Dialog de configurare export fișă programare (PDF).
///
/// SECURITATE: secțiunea administrativă (checkbox-uri) este afișată DOAR dacă
/// [isAdmin] este true. Pentru non-admin, checkbox-urile nu apar deloc — nici
/// dezactivate — și se returnează exclusiv setul „teren".
///
/// Returnează opțiunile selectate, sau `null` dacă utilizatorul anulează.
Future<AppointmentSheetExportOptions?> showAppointmentSheetExportDialog(
  BuildContext context, {
  required bool isAdmin,
}) {
  return showDialog<AppointmentSheetExportOptions>(
    context: context,
    builder: (dialogContext) => _AppointmentSheetExportDialog(isAdmin: isAdmin),
  );
}

class _AppointmentSheetExportDialog extends StatefulWidget {
  const _AppointmentSheetExportDialog({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_AppointmentSheetExportDialog> createState() =>
      _AppointmentSheetExportDialogState();
}

class _AppointmentSheetExportDialogState
    extends State<_AppointmentSheetExportDialog> {
  // Toate opțiunile administrative sunt DEBIFATE implicit (opt-in explicit).
  bool _financiarIntern = false;
  bool _costuriMateriale = false;
  bool _societateContractanta = false;
  bool _partenerBeneficiar = false;
  bool _partenerExecutant = false;
  bool _platiAngajati = false;

  static const _terenFields = <String>[
    'Titlu, status, prioritate, tip',
    'Interval, durată, tip/rezultat vizită',
    'Beneficiar, adresă, contact, telefoane, email',
    'Echipă, angajați, responsabil, vehicul',
    'Echipament, lucrare, reclamație, reprogramare',
    'Materiale consumate (denumire, cantitate, UM)',
    'Preț intervenție',
    'Notițe și documente atașate',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Export fișă programare (PDF)'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informații de teren (incluse mereu)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._terenFields.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Secțiune administrativă — DOAR pentru admin ──────────────
              if (widget.isAdmin) ...[
                const Divider(height: 24),
                Text(
                  'Informații administrative (opționale)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bifează ce vrei să incluzi. Implicit nu se exportă nimic administrativ.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                _adminCheckbox(
                  value: _financiarIntern,
                  title: 'Financiar intern',
                  subtitle: 'Încasare, status financiar, scadență, observații',
                  onChanged: (v) => setState(() => _financiarIntern = v),
                ),
                _adminCheckbox(
                  value: _costuriMateriale,
                  title: 'Costuri materiale și profit',
                  subtitle: 'Cost unitar, cost total, profit estimat, facturabil',
                  onChanged: (v) => setState(() => _costuriMateriale = v),
                ),
                _adminCheckbox(
                  value: _societateContractanta,
                  title: 'Societate contractantă',
                  subtitle: 'Societatea care contractează lucrarea',
                  onChanged: (v) => setState(() => _societateContractanta = v),
                ),
                _adminCheckbox(
                  value: _partenerBeneficiar,
                  title: 'Partener beneficiar (subcontractare)',
                  subtitle: 'Sumă de încasat, status, dată, observații',
                  onChanged: (v) => setState(() => _partenerBeneficiar = v),
                ),
                _adminCheckbox(
                  value: _partenerExecutant,
                  title: 'Partener executant (comision)',
                  subtitle: 'Comision, status plată, dată, observații',
                  onChanged: (v) => setState(() => _partenerExecutant = v),
                ),
                _adminCheckbox(
                  value: _platiAngajati,
                  title: 'Plăți angajați',
                  subtitle: 'Sume datorate angajaților pentru această programare',
                  onChanged: (v) => setState(() => _platiAngajati = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anulează'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            AppointmentSheetExportOptions(
              financiarIntern: _financiarIntern,
              costuriMateriale: _costuriMateriale,
              societateContractanta: _societateContractanta,
              partenerBeneficiar: _partenerBeneficiar,
              partenerExecutant: _partenerExecutant,
              platiAngajati: _platiAngajati,
            ),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generează PDF'),
        ),
      ],
    );
  }

  Widget _adminCheckbox({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(title),
      subtitle: Text(subtitle),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
