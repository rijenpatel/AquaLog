import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/translations.dart';

const Object _sentinel = Object();

@immutable
class AppSettingsState {
  final String language; // 'en' or 'hi'
  final ThemeMode themeMode; // system, light, dark
  final bool outdoorMode;
  final double fontScale;
  final String? selectedSiteId;
  final String? selectedBatchId;

  const AppSettingsState({
    this.language = 'en',
    this.themeMode = ThemeMode.light,
    this.outdoorMode = false,
    this.fontScale = 1.0,
    this.selectedSiteId,
    this.selectedBatchId,
  });

  AppSettingsState copyWith({
    String? language,
    ThemeMode? themeMode,
    bool? outdoorMode,
    double? fontScale,
    Object? selectedSiteId = _sentinel,
    Object? selectedBatchId = _sentinel,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      outdoorMode: outdoorMode ?? this.outdoorMode,
      fontScale: fontScale ?? this.fontScale,
      selectedSiteId: identical(selectedSiteId, _sentinel)
          ? this.selectedSiteId
          : selectedSiteId as String?,
      selectedBatchId: identical(selectedBatchId, _sentinel)
          ? this.selectedBatchId
          : selectedBatchId as String?,
    );
  }

  String tr(String key) => AppStrings.get(key, language);
  bool get isHindi => language == 'hi';
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final SharedPreferences _prefs;

  AppSettingsNotifier(this._prefs)
      : super(AppSettingsState(
          language: _prefs.getString('al_language') ?? 'en',
          outdoorMode: _prefs.getBool('al_outdoor_mode') ?? false,
          fontScale: _prefs.getDouble('al_font_scale') ?? 1.0,
          themeMode: _parseThemeMode(_prefs.getString('al_theme_mode')),
          selectedSiteId: _prefs.getString('al_selected_site'),
          selectedBatchId: _prefs.getString('al_selected_batch'),
        ));

  static ThemeMode _parseThemeMode(String? val) {
    if (val == 'dark') return ThemeMode.dark;
    if (val == 'system') return ThemeMode.system;
    return ThemeMode.light;
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString('al_language', lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setOutdoorMode(bool enabled) async {
    await _prefs.setBool('al_outdoor_mode', enabled);
    state = state.copyWith(outdoorMode: enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('al_theme_mode', mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setFontScale(double scale) async {
    await _prefs.setDouble('al_font_scale', scale);
    state = state.copyWith(fontScale: scale);
  }

  Future<void> setSelectedSiteId(String? siteId, {bool clearBatch = false}) async {
    if (siteId != null) {
      await _prefs.setString('al_selected_site', siteId);
    } else {
      await _prefs.remove('al_selected_site');
    }

    if (siteId != state.selectedSiteId || clearBatch) {
      // If site changed or cleared, clear the selected batch
      await _prefs.remove('al_selected_batch');
      state = state.copyWith(
        selectedSiteId: siteId,
        selectedBatchId: null,
      );
    } else {
      state = state.copyWith(selectedSiteId: siteId);
    }
  }

  Future<void> setSelectedBatchId(String? batchId) async {
    if (batchId != null) {
      await _prefs.setString('al_selected_batch', batchId);
    } else {
      await _prefs.remove('al_selected_batch');
    }
    state = state.copyWith(selectedBatchId: batchId);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main()');
});

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppSettingsNotifier(prefs);
});
