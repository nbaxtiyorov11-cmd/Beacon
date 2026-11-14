import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

abstract final class BeaconColors {
  static const ink = Color(0xFF15372F);
  static const forest = Color(0xFF24483C);
  static const lime = Color(0xFFD9ED76);
  static const paper = Color(0xFFF3F1EA);
  static const muted = Color(0xFF6E776F);
  static const line = Color(0xFFE3E0D7);
  static const coral = Color(0xFFE66E61);
  static const blue = Color(0xFF93B8D9);
  static const beige = Color(0xFFF8F3EE);
}

enum BeaconThemePreset {
  active,
  spring,
  summer,
  autumn,
  winter,
  performance,
  chill,
}

class BeaconThemeTokens extends ThemeExtension<BeaconThemeTokens> {
  const BeaconThemeTokens({required this.preset});

  final BeaconThemePreset preset;

  @override
  BeaconThemeTokens copyWith({BeaconThemePreset? preset}) {
    return BeaconThemeTokens(preset: preset ?? this.preset);
  }

  @override
  BeaconThemeTokens lerp(
    covariant ThemeExtension<BeaconThemeTokens>? other,
    double t,
  ) {
    if (other is! BeaconThemeTokens) return this;
    return t < 0.5 ? this : other;
  }
}

class BeaconAppTheme {
  const BeaconAppTheme({
    required this.preset,
    required this.label,
    required this.backgroundImageUrl,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.accentColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.borderColor,
    required this.tagColor,
  });

  final BeaconThemePreset preset;
  final String label;
  final String backgroundImageUrl;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color accentColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;
  final Color mutedTextColor;
  final Color borderColor;
  final Color tagColor;

  ImageProvider<Object> backgroundImageProvider({int? maxWidth}) =>
      CachedNetworkImageProvider(
        backgroundImageUrl,
        maxWidth: maxWidth ?? 1200,
      );

  static const List<BeaconAppTheme> presets = [
    BeaconAppTheme(
      preset: BeaconThemePreset.active,
      label: 'Active',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFEAF3F1),
      surfaceColor: Color(0xFFF7F5F1),
      cardColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF295B4D),
      primaryColor: Color(0xFF15372F),
      secondaryColor: Color(0xFFD9ED76),
      textColor: Color(0xFF15372F),
      mutedTextColor: Color(0xFF66726C),
      borderColor: Color(0xFFE1E6E1),
      tagColor: Color(0xFFE7EEE9),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.spring,
      label: 'Spring',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFEFF8F0),
      surfaceColor: Color(0xFFF9FFF8),
      cardColor: Color(0xFFFFFDFB),
      accentColor: Color(0xFF2F7D5A),
      primaryColor: Color(0xFF204636),
      secondaryColor: Color(0xFFB9E7A8),
      textColor: Color(0xFF1B2D24),
      mutedTextColor: Color(0xFF4A6557),
      borderColor: Color(0xFFDAE8E0),
      tagColor: Color(0xFFE4F7E6),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.summer,
      label: 'Summer',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFEFF7FF),
      surfaceColor: Color(0xFFF8FBFF),
      cardColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF1C8CC8),
      primaryColor: Color(0xFF103B59),
      secondaryColor: Color(0xFFFFD166),
      textColor: Color(0xFF102C3B),
      mutedTextColor: Color(0xFF4C6A7E),
      borderColor: Color(0xFFD5E9F5),
      tagColor: Color(0xFFE3F4FF),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.autumn,
      label: 'Autumn',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFF8F0E7),
      surfaceColor: Color(0xFFFCF8F4),
      cardColor: Color(0xFFFFFDF9),
      accentColor: Color(0xFF9F4E2A),
      primaryColor: Color(0xFF4A2A18),
      secondaryColor: Color(0xFFF4BB7A),
      textColor: Color(0xFF2D1D17),
      mutedTextColor: Color(0xFF6B5147),
      borderColor: Color(0xFFE9DCC7),
      tagColor: Color(0xFFF5E7DA),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.winter,
      label: 'Winter',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFEAF4FF),
      surfaceColor: Color(0xFFF6FAFF),
      cardColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF2E6FA0),
      primaryColor: Color(0xFF1F3348),
      secondaryColor: Color(0xFFBDE0FF),
      textColor: Color(0xFF1C2430),
      mutedTextColor: Color(0xFF586A7A),
      borderColor: Color(0xFFD7E4F1),
      tagColor: Color(0xFFE8F0FC),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.performance,
      label: 'Performance',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFEEF3F8),
      surfaceColor: Color(0xFFF8FBFF),
      cardColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF2B4F71),
      primaryColor: Color(0xFF112A42),
      secondaryColor: Color(0xFF8BC7FF),
      textColor: Color(0xFF10243B),
      mutedTextColor: Color(0xFF536C85),
      borderColor: Color(0xFFD9E6F6),
      tagColor: Color(0xFFE8F3FF),
    ),
    BeaconAppTheme(
      preset: BeaconThemePreset.chill,
      label: 'Chill',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1200&q=80',
      backgroundColor: Color(0xFFF3F1FF),
      surfaceColor: Color(0xFFFAF9FF),
      cardColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF5E5BB8),
      primaryColor: Color(0xFF27224A),
      secondaryColor: Color(0xFFC0D7FF),
      textColor: Color(0xFF281F3A),
      mutedTextColor: Color(0xFF625D7C),
      borderColor: Color(0xFFE1DDF7),
      tagColor: Color(0xFFEDEBFF),
    ),
  ];

  static BeaconAppTheme forPreset(BeaconThemePreset preset) {
    return presets.firstWhere((theme) => theme.preset == preset);
  }

  ThemeData toThemeData() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'sans-serif',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: primaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor.withValues(alpha: 0.92),
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor.withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: textColor, size: 22),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? accentColor : textColor,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      dialogTheme: DialogThemeData(backgroundColor: cardColor),
      canvasColor: surfaceColor,
      dividerColor: borderColor,
      extensions: [BeaconThemeTokens(preset: preset)],
    );
  }
}

abstract final class BeaconTheme {
  static final light =
      BeaconAppTheme.forPreset(BeaconThemePreset.active).toThemeData();

  static ThemeData forPreset(BeaconThemePreset preset) =>
      BeaconAppTheme.forPreset(preset).toThemeData();
}
