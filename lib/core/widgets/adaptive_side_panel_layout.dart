import 'package:flutter/material.dart';

class AdaptiveSidePanelLayout extends StatelessWidget {
  const AdaptiveSidePanelLayout({
    super.key,
    required this.mainContent,
    required this.sidePanel,
    required this.showSidePanel,
    this.sidePanelWidth = 340,
    this.gap = 16,
  });

  final Widget mainContent;
  final Widget sidePanel;
  final bool showSidePanel;
  final double sidePanelWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!showSidePanel) {
      return mainContent;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: mainContent),
        SizedBox(width: gap),
        SizedBox(
          width: sidePanelWidth,
          child: sidePanel,
        ),
      ],
    );
  }
}

class SidePanelCard extends StatelessWidget {
  const SidePanelCard({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Flexible(child: child),
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
