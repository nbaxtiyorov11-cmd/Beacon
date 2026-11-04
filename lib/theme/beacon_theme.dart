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

abstract final class BeaconTheme {
  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BeaconColors.paper,
    fontFamily: 'sans-serif',
    colorScheme: ColorScheme.fromSeed(
      seedColor: BeaconColors.ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: BeaconColors.ink,
      secondary: BeaconColors.lime,
      surface: BeaconColors.paper,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BeaconColors.paper,
      foregroundColor: BeaconColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: BeaconColors.ink,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BeaconColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      height: 76,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: Colors.white, size: 22),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? BeaconColors.lime : Colors.white,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BeaconColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}