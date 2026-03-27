import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  Color _accentColor = const Color(0xFFA78BFA);
  bool _isDark = true;

  Color get accentColor => _accentColor;
  bool get isDark => _isDark;

  ThemeData get theme => _isDark
      ? AppTheme.buildDarkTheme(_accentColor)
      : AppTheme.buildLightTheme(_accentColor);

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString('themeColor') ?? '#A78BFA';
    _accentColor = Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    _isDark = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  Future<void> setTheme(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    final r = color.r;
    final g = color.g;
    final b = color.b;
    final hexStr =
        '#${(((r * 255).round() << 16) | ((g * 255).round() << 8) | (b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    await prefs.setString('themeColor', hexStr);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool isDark) async {
    _isDark = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }
}
