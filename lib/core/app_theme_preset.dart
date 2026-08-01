import 'package:flutter/material.dart';

/// Etapa "elevated cards + gradient" (aug 2026): înlocuiește complet cele 5
/// presetări vechi (atelier/aurora/forest/graphite/proTerm). Profilurile din
/// Firestore salvate cu valorile vechi NU sunt migrate activ — `fromValue()`
/// nu le mai recunoaște (niciun preset nou nu refolosește un `value` vechi)
/// și cad automat pe fallback-ul implicit `proTermSignature`.
enum AppThemePreset {
  proTermSignature,
  oceanDepth,
  copperSlate,
  violetCircuit,
  crimsonSteel,
}

extension AppThemePresetX on AppThemePreset {
  String get value {
    switch (this) {
      case AppThemePreset.proTermSignature:
        return 'pro_term_signature';
      case AppThemePreset.oceanDepth:
        return 'ocean_depth';
      case AppThemePreset.copperSlate:
        return 'copper_slate';
      case AppThemePreset.violetCircuit:
        return 'violet_circuit';
      case AppThemePreset.crimsonSteel:
        return 'crimson_steel';
    }
  }

  String get label {
    switch (this) {
      case AppThemePreset.proTermSignature:
        return 'PRO TERM Signature';
      case AppThemePreset.oceanDepth:
        return 'Ocean Depth';
      case AppThemePreset.copperSlate:
        return 'Copper Slate';
      case AppThemePreset.violetCircuit:
        return 'Violet Circuit';
      case AppThemePreset.crimsonSteel:
        return 'Crimson Steel';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.proTermSignature:
        return 'Temă implicită PRO TERM — roșu de impact, albastru tehnic și accente reci inspirate din identitatea HVAC.';
      case AppThemePreset.oceanDepth:
        return 'Tonuri de teal profund și albastru electric, aspect tehnic și răcoros.';
      case AppThemePreset.copperSlate:
        return 'Cupru cald combinat cu gri ardezie — aspect industrial, robust.';
      case AppThemePreset.violetCircuit:
        return 'Violet electric cu accente cyan — aspect modern, high-tech.';
      case AppThemePreset.crimsonSteel:
        return 'Roșu crimson cu gri oțel — contrast puternic, aspect premium.';
    }
  }

  static AppThemePreset fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final preset in AppThemePreset.values) {
      if (preset.value == normalized) {
        return preset;
      }
    }
    return AppThemePreset.proTermSignature;
  }
}

@immutable
class AppBrandTheme extends ThemeExtension<AppBrandTheme> {
  const AppBrandTheme({
    required this.shellHeaderGradient,
    required this.shellAccentGradient,
    required this.shellLineColor,
    required this.shellGlow,
    required this.heroGradient,
  });

  /// Fundal pastel/deschis — folosit pentru zone MARI cu text închis peste
  /// (ex: header-ul de navigație din shell, preview-ul de temă din setări).
  final LinearGradient shellHeaderGradient;

  /// Gradient saturat pentru elemente mici de accent (cerc decorativ,
  /// pastilă "Preview", FAB) — text ALB peste el.
  final LinearGradient shellAccentGradient;
  final Color shellLineColor;
  final Color shellGlow;

  /// Gradient bold pe 2 culori (primary → primary închis) — dedicat noilor
  /// header-e "elevated" (`AppGradientHeader`), care folosesc text ALB.
  /// Extensie a sistemului existent de gradient-uri, NU un sistem paralel:
  /// [shellHeaderGradient] rămâne fundalul pastel pentru shell/preview,
  /// [heroGradient] e varianta saturată pentru header-e de pagină.
  final LinearGradient heroGradient;

  @override
  AppBrandTheme copyWith({
    LinearGradient? shellHeaderGradient,
    LinearGradient? shellAccentGradient,
    Color? shellLineColor,
    Color? shellGlow,
    LinearGradient? heroGradient,
  }) {
    return AppBrandTheme(
      shellHeaderGradient: shellHeaderGradient ?? this.shellHeaderGradient,
      shellAccentGradient: shellAccentGradient ?? this.shellAccentGradient,
      shellLineColor: shellLineColor ?? this.shellLineColor,
      shellGlow: shellGlow ?? this.shellGlow,
      heroGradient: heroGradient ?? this.heroGradient,
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
      heroGradient: LinearGradient(
        colors: List<Color>.generate(
          heroGradient.colors.length,
          (index) =>
              Color.lerp(
                heroGradient.colors[index],
                other.heroGradient.colors[index],
                t,
              ) ??
              heroGradient.colors[index],
        ),
        begin: Alignment.lerp(
              _asAlignment(heroGradient.begin),
              _asAlignment(other.heroGradient.begin),
              t,
            ) ??
            _asAlignment(heroGradient.begin),
        end: Alignment.lerp(
              _asAlignment(heroGradient.end),
              _asAlignment(other.heroGradient.end),
              t,
            ) ??
            _asAlignment(heroGradient.end),
      ),
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
    required this.heroGradient,
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
  final LinearGradient heroGradient;
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
        heroGradient: tokens.heroGradient,
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
    case AppThemePreset.proTermSignature:
      return _AppThemeTokens(
        seed: const Color(0xFFE10613),
        primary: const Color(0xFFE10613),
        secondary: const Color(0xFF0057B8),
        tertiary: const Color(0xFF66C4FF),
        scaffold: const Color(0xFFF4F6FA),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFFFF4F4), Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradient: const LinearGradient(
          colors: [Color(0xFFE10613), Color(0xFFA80410)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF0057B8), Color(0xFF003D82)],
        ),
        lineColor: const Color(0xFFB8D7F5),
        glow: const Color(0x55E10613),
      );
    case AppThemePreset.oceanDepth:
      return _AppThemeTokens(
        seed: const Color(0xFF0F766E),
        primary: const Color(0xFF0F766E),
        secondary: const Color(0xFF2563EB),
        tertiary: const Color(0xFF93C5FD),
        scaffold: const Color(0xFFF0FDFA),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
        ),
        lineColor: const Color(0xFF99F6E4),
        glow: const Color(0x550F766E),
      );
    case AppThemePreset.copperSlate:
      return _AppThemeTokens(
        seed: const Color(0xFFB45309),
        primary: const Color(0xFFB45309),
        secondary: const Color(0xFF475569),
        tertiary: const Color(0xFF94A3B8),
        scaffold: const Color(0xFFFFFBEB),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradient: const LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFF78350F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF1E293B)],
        ),
        lineColor: const Color(0xFFFDE68A),
        glow: const Color(0x55B45309),
      );
    case AppThemePreset.violetCircuit:
      return _AppThemeTokens(
        seed: const Color(0xFF6D28D9),
        primary: const Color(0xFF6D28D9),
        secondary: const Color(0xFF0891B2),
        tertiary: const Color(0xFF67E8F9),
        scaffold: const Color(0xFFFAF5FF),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFFAF5FF), Color(0xFFECFEFF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF164E63)],
        ),
        lineColor: const Color(0xFFDDD6FE),
        glow: const Color(0x556D28D9),
      );
    case AppThemePreset.crimsonSteel:
      return _AppThemeTokens(
        seed: const Color(0xFFBE123C),
        primary: const Color(0xFFBE123C),
        secondary: const Color(0xFF334155),
        tertiary: const Color(0xFF94A3B8),
        scaffold: const Color(0xFFFFF1F2),
        surface: const Color(0xFFFFFFFF),
        headerGradient: const LinearGradient(
          colors: [Color(0xFFFFF1F2), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradient: const LinearGradient(
          colors: [Color(0xFFBE123C), Color(0xFF881337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accentGradient: const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF0F172A)],
        ),
        lineColor: const Color(0xFFFECDD3),
        glow: const Color(0x55BE123C),
      );
  }
}
