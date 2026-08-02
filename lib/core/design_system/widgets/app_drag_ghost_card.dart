import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Feedback vizual minimal pentru drag & drop (`Draggable.feedback` /
/// `LongPressDraggable.feedback`) — "ghost card" semi-transparent, cu umbră
/// pronunțată, care urmărește degetul/cursorul în timpul tragerii. Respectă
/// token-urile existente ([AppSpacing]) și tema activă, fără stil ad-hoc.
///
/// Nu conține logică — doar învelește [child] (de regulă conținutul unui
/// `AppCard`) într-un [Material] transparent (obligatoriu pentru feedback,
/// care randează în afara ierarhiei de widget-uri normale) + opacitate
/// redusă + umbră.
class AppDragGhostCard extends StatelessWidget {
  const AppDragGhostCard({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.9,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
