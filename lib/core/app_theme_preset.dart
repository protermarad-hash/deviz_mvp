import 'package:flutter/material.dart';

enum AppThemePreset {
  atelier,
  aurora,
  forest,
  graphite,
  proTerm,
}

extension AppThemePresetX on AppThemePreset {
  String get value {
    switch (this) {
      case AppThemePreset.atelier:
        return 'atelier';
      case AppThemePreset.aurora:
        return 'aurora';
      case AppThemePreset.forest:
        return 'forest';
      case AppThemePreset.graphite:
        return 'graphite';
      case AppThemePreset.proTerm:
        return 'pro_term';
    }
  }

  String get label {
    switch (this) {
      case AppThemePreset.atelier:
        return 'Atelier Indigo';
      case AppThemePreset.aurora:
        return 'Aurora Slate';
      case AppThemePreset.forest:
        return 'Forest Copper';
      case AppThemePreset.graphite:
        return 'Graphite Mono';
      case AppThemePreset.proTerm:
        return 'ProVentaris Signature';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.atelier:
        return 'Aspect editorial modern, echilibrat pentru uz zilnic.';
      case AppThemePreset.aurora:
        return 'Paletă rece, premium, cu accente curate și tehnice.';
      case AppThemePreset.forest:
        return 'Tonuri naturale și industriale, potrivite pentru operare.';
      case AppThemePreset.graphite:
        return 'Interfață neutră, contrastată, orientată spre densitate mare de informații.';
      case AppThemePreset.proTerm:
        return 'Temă ProVentaris cu roșu de impact, albastru tehnic și accente reci inspirate din identitatea HVAC.';
    }
  }

  static AppThemePreset fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final preset in AppThemePreset.values) {
      if (preset.value == normalized) {
        return preset;
      }
    }
    return AppThemePreset.proTerm;
  }
}

@immutable
class AppBrandTheme extends ThemeExtension<AppBrandTheme> {
  const AppBrandTheme({
    required this.shellHeaderGradient,
    required this.shellAccentGradient,
    required this.shellLineColor,
    required this.shellGlow,
  });

  final LinearGradient shellHeaderGradient;
  final LinearGradient shellAccentGradient;
  final Color shellLineColor;
  final Color shellGlow;

  @override
  AppBrandTheme copyWith({
    LinearGradient? shellHeaderGradient,
    LinearGradient? shellAccentGradient,
    Color? shellLineColor,
    Color? shellGlow,
  }) {
    return AppBrandTheme(
      shellHeaderGradient: shellHeaderGradient ?? this.shellHeaderGradient,
      shellAccentGradient: shellAccentGradient ?? this.shellAccentGradient,
      shellLineColor: shellLineColor ?? this.shellLineColor,
      shellGlow: shellGlow ?? this.shellGlow,
    );
  }

  @override
  AppBrandTheme lerp(ThemeExtension<AppBrandTheme>? other, double t) {
    if (other is! AppBrandTheme) {
      return this;
    }
    return AppBrandTheme(
      shellHeaderGradient: LinearGradient(
        colors: List<Color>.generate(
          shellHeaderGradient.colors.length,
          (index) =>
              Color.lerp(
                shellHeaderGradient.colors[index],
                other.shellHeaderGradient.colors[index],
                t,
              ) ??
              shellHeaderGradient.colors[index],
        ),
        begin: Alignment.lerp(
              _asAlignment(shellHeaderGradient.begin),
              _asAlignment(other.shellHeaderGradient.begin),
              t,
            ) ??
            _asAlignment(shellHeaderGradient.begin),
        end: Alignment.lerp(
              _asAlignment(shellHeaderGradient.end),
              _asAlignment(other.shellHeaderGradient.end),
              t,
            ) ??
            _asAlignment(shellHeaderGradient.end),
      ),
      shellAccentGradient: LinearGradient(
        colors: List<Color>.generate(
          shellAccentGradient.colors.length,
          (index) =>
              Color.lerp(
                shellAccentGradient.colors[index],
                other.shellAccentGradient.colors[index],
                t,
              ) ??
              shellAccentGradient.colors[index],
        ),
        begin: Alignment.lerp(
              _asAlignment(shellAccentGradient.begin),
              _asAlignment(other.shellAccentGradient.begin),
              t,
            ) ??
            _asAlignment(shellAccentGradient.begin),
        end: Alignment.lerp(
              _asAlignment(shellAccentGradient.end),
              _asAlignment(other.shellAccentGradient.end),
              t,
            ) ??
            _asAlignment(shellAccentGradient.end),
      ),
      shellLineColor:
          Color.lerp(shellLineColor, other.shellLineColor, t) ?? shellLineColor,
      shellGlow: Color.lerp(shellGlow, other.shellGlow, t) ?? shellGlow,
    );
  }

  static Alignment _asAlignment(AlignmentGeometry value) {
    return value is Alignment ? value : Alignment.center;
  }
}

class _AppThemeTokens {
  const _AppThemeTokens({
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.scaffold,
    required this.surface,
    required this.headerGradient,
    required this.accentGradient,
    required this.lineColor,
    required this.glow,
  });

  final Color seed;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color scaffold;
  final Color surface;
  final LinearGradient headerGradient;
  final LinearGradient accentGradient;
  final Color lineColor;
  final Color glow;
}

ThemeData buildAppTheme(AppThemePreset preset) {
  final tokens = _tokensForPreset(preset);
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.seed,
    primary: tokens.primary,
    secondary: tokens.secondary,
    tertiary: tokens.tertiary,
    surface: tokens.surface,
    brightness: Brightness.light,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.scaffold,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    extensions: <ThemeExtension<dynamic>>[
      AppBrandTheme(
        shellHeaderGradient: tokens.headerGradient,
        shellAccentGradient: tokens.accentGradient,
        shellLineColor: tokens.lineColor,
        shellGlow: tokens.glow,
      ),
    ],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

_AppThemeTokens _tokensForPreset(AppThemePreset preset) {
  switch (preset) {
    case AppThemePreset.atelier:
      return _AppThemeTokens(
        seed: const Color(0xFF4F46E5),
        primary: const Color(0xFF3940D1),
        secondary: const Color(0xFF14B8A6),
        tertiary: const Color(0xFFF59E0B),
        scaffold: const Color(0xFFF5F7FD),
        surface: Colors.white,
        headerGradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0F2FE), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF14B8A6)],
        ),
        lineColor: const Color(0xFFBFDBFE),
        glow: const Color(0x553B82F6),
      );
    case AppThemePreset.aurora:
      return _AppThemeTokens(
        seed: const Color(0xFF0F766E),
        primary: const Color(0xFF0F766E),
        secondary: const Color(0xFF2563EB),
        tertiary: const Color(0xFF7C3AED),
        scaffold: const Color(0xFFF3F8FA),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFE6FFFB), Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
        ),
        lineColor: const Color(0xFF99F6E4),
        glow: const Color(0x5538BDF8),
      );
    case AppThemePreset.forest:
      return _AppThemeTokens(
        seed: const Color(0xFF355E3B),
        primary: const Color(0xFF355E3B),
        secondary: const Color(0xFFB45309),
        tertiary: const Color(0xFF0F766E),
        scaffold: const Color(0xFFF6F5EF),
        surface: const Color(0xFFFFFCF6),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFEEF6EA), Color(0xFFFFF3E0), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF355E3B), Color(0xFFB45309)],
        ),
        lineColor: const Color(0xFFD6D3B1),
        glow: const Color(0x5565A30D),
      );
    case AppThemePreset.graphite:
      return _AppThemeTokens(
        seed: const Color(0xFF334155),
        primary: const Color(0xFF334155),
        secondary: const Color(0xFF0F766E),
        tertiary: const Color(0xFF7C2D12),
        scaffold: const Color(0xFFF3F4F6),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFE5E7EB), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF475569)],
        ),
        lineColor: const Color(0xFFD1D5DB),
        glow: const Color(0x55222633),
      );
    case AppThemePreset.proTerm:
      return _AppThemeTokens(
        seed: const Color(0xFFE10613),
        primary: const Color(0xFFE10613),
        secondary: const Color(0xFF0057B8),
        tertiary: const Color(0xFF66C4FF),
        scaffold: const Color(0xFFF4F8FE),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFFFF4F4), Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFFE10613), Color(0xFF0057B8), Color(0xFF66C4FF)],
        ),
        lineColor: const Color(0xFFB8D7F5),
        glow: const Color(0x330057B8),
      );
  }
}
