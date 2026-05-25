import 'package:flutter/material.dart';

class PlaceholderFeaturePage extends StatelessWidget {
  const PlaceholderFeaturePage({
    super.key,
    required this.title,
    this.description = '',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              description.isEmpty
                  ? 'Modul pregatit pentru extindere ulterioara.'
                  : description,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
