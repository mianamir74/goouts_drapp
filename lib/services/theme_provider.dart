import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'dapp_light_mode';

  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  bool _isLight = false;
  bool get isLight => _isLight;

  ThemeMode get themeMode => _isLight ? ThemeMode.light : ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLight = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle(bool value) async {
    _isLight = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  // ── Dark theme (default) ────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF031134),
        primaryColor: const Color(0xFF0392ca),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0392ca),
          secondary: Color(0xFFf97316),
          surface: Color(0xFF0b1a3d),
          onSurface: Colors.white,
          error: Color(0xFFef4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0b1a3d),
          selectedItemColor: Color(0xFFf97316),
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0392ca),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  // ── Light theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        primaryColor: const Color(0xFF0392ca),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0392ca),
          secondary: Color(0xFFf97316),
          surface: Colors.white,
          onSurface: Color(0xFF031134),
          error: Color(0xFFef4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF031134)),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF031134),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFf97316),
          unselectedItemColor: Colors.black38,
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0392ca),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
