import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/clients/client_models.dart';

/// Card compact cu datele de identificare ale unui client.
/// Afișează: CUI, Reg. Com., Adresă, Telefon, Email, Persoana de contact.
/// Se foloseşte în formulare (oferte, devize tehnice, lucrări) după selectarea clientului.
class ClientInfoCard extends StatelessWidget {
  const ClientInfoCard({
    super.key,
    required this.client,
    this.showTitle = true,
    this.compact = false,
  });

  final ClientRecord client;

  /// Afișează titlul "Date identificare client" deasupra cardului.
  final bool showTitle;

  /// Mod compact: fără padding extra, fără titlu separat.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = _buildRows();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle && !compact) ...[
          const SizedBox(height: 6),
          Text(
            'Date identificare client',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 8 : 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Wrap(
            spacing: compact ? 12 : 16,
            runSpacing: compact ? 4 : 6,
            children: rows,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRows() {
    final items = <_InfoItem>[];

    if (client.cui.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'CUI', value: client.cui.trim()));
    }
    if (client.regCom.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Reg. Com.', value: client.regCom.trim()));
    }
    if (client.address.trim().isNotEmpty) {
      items.add(_InfoItem(
        label: 'Adresă',
        value: [
          client.address.trim(),
          if (client.city.trim().isNotEmpty) client.city.trim(),
          if (client.county.trim().isNotEmpty) client.county.trim(),
        ].join(', '),
      ));
    } else if (client.city.trim().isNotEmpty) {
      items.add(_InfoItem(
        label: 'Localitate',
        value: [
          client.city.trim(),
          if (client.county.trim().isNotEmpty) client.county.trim(),
        ].join(', '),
      ));
    }
    if (client.phone.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Telefon', value: client.phone.trim(), copyable: true));
    }
    if (client.phone2.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Tel. 2', value: client.phone2.trim(), copyable: true));
    }
    if (client.email.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Email', value: client.email.trim(), copyable: true));
    }
    if (client.contactPerson.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Contact', value: client.contactPerson.trim()));
    }
    if (client.iban.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'IBAN', value: client.iban.trim(), copyable: true));
    }
    if (client.bank.trim().isNotEmpty) {
      items.add(_InfoItem(label: 'Bancă', value: client.bank.trim()));
    }

    return items;
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copiat.'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          : null,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: cs.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
