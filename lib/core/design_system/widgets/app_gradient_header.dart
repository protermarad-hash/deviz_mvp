import 'package:flutter/material.dart';

import '../../app_theme_preset.dart';
import '../app_tokens.dart';

/// Header "elevated" cu gradient bold pe 2-3 culori — folosește
/// [AppBrandTheme.heroGradient] (extensie a temei active), NU un gradient
/// hardcodat separat. Text ALB (heroGradient e mereu saturat/închis).
class AppGradientHeader extends StatelessWidget {
  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.stats = const <Widget>[],
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// De regulă o listă de [AppStatPill] — randate într-un `Wrap` sub titlu.
  final List<Widget> stats;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final gradient = brand?.heroGradient ??
        LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
          ],
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (brand?.shellGlow ?? Colors.black26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: stats,
            ),
          ],
        ],
      ),
    );
  }
}
