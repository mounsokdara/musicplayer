import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'core/material_you.dart';
import 'services/settings_service.dart';

/// Material 3 theming (shared look with the Video Player app): colors come
/// from a Material You seed chip, a custom color, or Android's wallpaper
/// colors, with optional pure-black dark mode, high contrast and bold text.
class AppTheme {
  static const Color defaultSeed = Color(0xFF38618D);

  static ThemeData build({
    required Brightness brightness,
    required SettingsService settings,
    ColorScheme? dynamicScheme,
  }) {
    final dark = brightness == Brightness.dark;
    ColorScheme scheme;
    if (settings.useDynamicColor && dynamicScheme != null) {
      scheme = dynamicScheme.harmonized();
      if (dark && settings.amoledBlack) {
        scheme = scheme.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0B0B0B),
          surfaceContainer: const Color(0xFF111111),
          surfaceContainerHigh: const Color(0xFF181818),
          surfaceContainerHighest: const Color(0xFF202020),
        );
      }
    } else {
      scheme = materialYouScheme(
        settings.accentColor,
        brightness,
        extraDark: settings.amoledBlack,
      );
    }

    if (settings.highContrast) {
      scheme = scheme.copyWith(
        outline: dark ? Colors.white70 : Colors.black87,
        onSurface: dark ? Colors.white : Colors.black,
      );
    }

    const radius = 16.0;
    final typography = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    );
    final bold = settings.boldText;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: dark ? typography.white : typography.black,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        year2023: false,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle:
            TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(const StadiumBorder()),
      ),
    );
  }

  /// Now Playing background derived from album art (§6.4).
  static ColorScheme fromArtwork(Color dominant, Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: dominant, brightness: brightness);
}
