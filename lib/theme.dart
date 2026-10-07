import 'package:flutter/material.dart';

/// Material 3 theming. Colors come from a seed (accent color in Settings) or
/// from Android's dynamic color when available.
class AppTheme {
  static const Color defaultSeed = Color(0xFF4A6FA5);

  static ThemeData light(ColorScheme? dynamicScheme, Color seed) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark(ColorScheme? dynamicScheme, Color seed) => _build(
        dynamicScheme ??
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      );

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        year2023: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Now Playing background derived from album art (§6.4).
  static ColorScheme fromArtwork(Color dominant, Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: dominant, brightness: brightness);
}
