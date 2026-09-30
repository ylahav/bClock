import 'package:flutter/material.dart';
import 'package:plinth_components/plinth_components.dart';

/// bClock's theme: Plinth tokens are the source of truth, and Material's
/// `ColorScheme` is derived from them (`toColorScheme`) so the few Material
/// widgets still in use (AppBar, NavigationBar, time picker) agree with the
/// Plinth components around them.
class AppTheme {
  /// The one brand colour. `generateShades` anchors shade 6 to exactly this.
  static const Color brandColor = Color(0xFF2196F3);

  static const Color _lightBg = Color(0xFFF8F9FA);
  static const Color _darkBg = Color(0xFF111111);

  static PlinthTheme _brand(PlinthTheme base) => base.copyWith(
        primaryColor: 'brand',
        colors: {
          ...base.colors,
          'brand': PlinthTheme.generateShades(brandColor),
        },
      );

  static final PlinthTheme plinthLight = _brand(PlinthTheme.defaultTheme);
  static final PlinthTheme plinthDark = _brand(PlinthTheme.darkTheme);

  static ThemeData _themeData(PlinthTheme plinth, Color bg) => ThemeData(
        useMaterial3: true,
        brightness: plinth.brightness,
        colorScheme: plinth.toColorScheme(),
        scaffoldBackgroundColor: bg,
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: bg,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
        ),
        extensions: [plinth],
      );

  static ThemeData get lightTheme => _themeData(plinthLight, _lightBg);
  static ThemeData get darkTheme => _themeData(plinthDark, _darkBg);
}
