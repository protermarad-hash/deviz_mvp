import 'package:flutter/material.dart';

/// Buton de ajutor afișat în AppBar. Deschide un dialog cu instrucțiuni.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.content});

  final HelpContent content;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajutor — cum se folosește modulul',
      icon: const Icon(Icons.help_outline),
      onPressed: () => _showHelp(context),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _HelpDialog(content: content),
    );
  }
}

/// Conținut structurat pentru dialogul de ajutor.
class HelpContent {
  const HelpContent({
    required this.title,
    required this.sections,
    this.intro = '',
  });

  final String title;
  final String intro;
  final List<HelpSection> sections;
}

class HelpSection {
  const HelpSection({
    required this.title,
    required this.steps,
    this.icon,
    this.note = '',
  });

  final String title;
  final List<String> steps;
  final IconData? icon;
  /// Text suplimentar afișat după pași (atenționare, sfat etc.)
  final String note;
}

// ---------------------------------------------------------------------------
// Dialog intern
// ---------------------------------------------------------------------------

class _HelpDialog extends StatelessWidget {
  const _HelpDialog({required this.content});

  final HelpContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      content.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Conținut scrollabil
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content.intro.isNotEmpty) ...[
                      Text(
                        content.intro,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ...content.sections.map(
                      (section) => _HelpSectionWidget(section: section),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Am înțeles'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSectionWidget extends StatelessWidget {
  const _HelpSectionWidget({required this.section});

  final HelpSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titlu secțiune
          Row(
            children: [
              if (section.icon != null) ...[
                Icon(section.icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Pași
          ...section.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1, right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Notă
          if (section.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      section.note,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
