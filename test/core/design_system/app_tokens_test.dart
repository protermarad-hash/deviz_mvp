import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/app_tokens.dart';

void main() {
  group('AppElevatedCardStyle — rețetă unică cardului elevated', () {
    test('cornerRadius/borderRadius consistente (24, folosit de AppCard + planner)', () {
      expect(AppElevatedCardStyle.cornerRadius, 24);
      expect(
        AppElevatedCardStyle.borderRadius,
        BorderRadius.circular(24),
      );
    });

    test('accentBarWidth este 4 — identic în Listă/Calendar/Pe echipe', () {
      expect(AppElevatedCardStyle.accentBarWidth, 4);
    });

    test('shadow() derivă din culoarea accent cu alpha/blur/offset fixe', () {
      const accent = Colors.teal;
      final shadow = AppElevatedCardStyle.shadow(accent);
      expect(shadow, hasLength(1));
      expect(shadow.single.color, accent.withValues(alpha: 0.22));
      expect(shadow.single.blurRadius, 18);
      expect(shadow.single.offset, const Offset(0, 8));
    });

    test('shadow() reflectă culoarea accent primită — nu e hardcodată', () {
      final shadowRed = AppElevatedCardStyle.shadow(Colors.red);
      final shadowBlue = AppElevatedCardStyle.shadow(Colors.blue);
      expect(shadowRed.single.color, isNot(shadowBlue.single.color));
    });
  });
}
