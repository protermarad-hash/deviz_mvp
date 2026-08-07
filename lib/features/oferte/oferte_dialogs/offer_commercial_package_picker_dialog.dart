import 'package:flutter/material.dart';

import '../offer_commercial_package_models.dart';

class OfferCommercialPackagePickerDialog extends StatelessWidget {
  const OfferCommercialPackagePickerDialog({required this.items});

  final List<OfferCommercialPackageTemplate> items;

  @override
  Widget build(BuildContext context) {
    final available = items
        .where((item) => item.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: const Text('Adauga din pachet comercial'),
      content: SizedBox(
        width: 720,
        child: available.isEmpty
            ? const Center(
                child: Text('Nu exista pachete comerciale standard active.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: available.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = available[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.description.trim().isEmpty ? '-' : item.description.trim()}\n'
                      'Materiale: ${item.materials.length} • Manopera standard: ${item.standardLabor.length} • Conditii: ${item.commercialClauses.length}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
      ],
    );
  }
}
