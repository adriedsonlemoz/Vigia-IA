import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum AppThemePreference { system, light, dark }
enum AppAccentColor { turquoise, blue, purple, orange }

class AppearanceSettingsService extends ChangeNotifier {
  AppearanceSettingsService._();

  static final AppearanceSettingsService instance = AppearanceSettingsService._();

  AppThemePreference _themePreference = AppThemePreference.dark;
  AppAccentColor _accentColor = AppAccentColor.turquoise;
  File? _file;
  bool _initialized = false;

  AppThemePreference get themePreference => _themePreference;
  AppAccentColor get accentColor => _accentColor;

  ThemeMode get themeMode => switch (_themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  Color get seedColor => switch (_accentColor) {
        AppAccentColor.turquoise => const Color(0xFF20BFA9),
        AppAccentColor.blue => const Color(0xFF3B82F6),
        AppAccentColor.purple => const Color(0xFF8B5CF6),
        AppAccentColor.orange => const Color(0xFFF59E0B),
      };

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}appearance_settings.json');
    final file = _file!;
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          final map = raw.cast<String, dynamic>();
          final themeName = map['theme'] as String?;
          final accentName = map['accent'] as String?;
          _themePreference = AppThemePreference.values.firstWhere(
            (value) => value.name == themeName,
            orElse: () => AppThemePreference.dark,
          );
          _accentColor = AppAccentColor.values.firstWhere(
            (value) => value.name == accentName,
            orElse: () => AppAccentColor.turquoise,
          );
        }
      } catch (_) {
        _themePreference = AppThemePreference.dark;
        _accentColor = AppAccentColor.turquoise;
      }
    }
    _initialized = true;
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    if (_themePreference == value) return;
    _themePreference = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAccentColor(AppAccentColor value) async {
    if (_accentColor == value) return;
    _accentColor = value;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await initialize();
    final file = _file!;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'theme': _themePreference.name,
        'accent': _accentColor.name,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
