import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings (§6.9).
class SettingsService extends ChangeNotifier {
  SettingsService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsService> load() async =>
      SettingsService._(await SharedPreferences.getInstance());

  // Themes & Colors
  ThemeMode get themeMode =>
      ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
  set themeMode(ThemeMode v) => _set('themeMode', v.index);

  bool get useDynamicColor => _prefs.getBool('dynamicColor') ?? true;
  set useDynamicColor(bool v) => _set('dynamicColor', v);

  Color get accentColor => Color(_prefs.getInt('accent') ?? 0xFF38618D);
  set accentColor(Color v) => _set('accent', v.toARGB32());

  bool get amoledBlack => _prefs.getBool('amoledBlack') ?? false;
  set amoledBlack(bool v) => _set('amoledBlack', v);

  bool get highContrast => _prefs.getBool('highContrast') ?? false;
  set highContrast(bool v) => _set('highContrast', v);

  bool get boldText => _prefs.getBool('boldText') ?? false;
  set boldText(bool v) => _set('boldText', v);

  // Now Playing
  bool get showExtraControls => _prefs.getBool('extraControls') ?? true;
  set showExtraControls(bool v) => _set('extraControls', v);

  bool get albumArtOnLockscreen => _prefs.getBool('lockscreenArt') ?? true;
  set albumArtOnLockscreen(bool v) => _set('lockscreenArt', v);

  // Library
  bool get splitMultipleArtists => _prefs.getBool('splitArtists') ?? false;
  set splitMultipleArtists(bool v) => _set('splitArtists', v);

  int get minTrackSeconds => _prefs.getInt('minTrackSeconds') ?? 3;
  set minTrackSeconds(int v) => _set('minTrackSeconds', v);

  // Images
  bool get cacheImages => _prefs.getBool('cacheImages') ?? true;
  set cacheImages(bool v) => _set('cacheImages', v);

  bool get downloadMetadata => _prefs.getBool('downloadMetadata') ?? false;
  set downloadMetadata(bool v) => _set('downloadMetadata', v);

  // Audio
  bool get fadeAudio => _prefs.getBool('fadeAudio') ?? false;
  set fadeAudio(bool v) => _set('fadeAudio', v);

  bool get replayGain => _prefs.getBool('replayGain') ?? false;
  set replayGain(bool v) => _set('replayGain', v);

  bool get gaplessPlayback => _prefs.getBool('gapless') ?? true;
  set gaplessPlayback(bool v) => _set('gapless', v);

  // Playlists
  int get recentlyAddedDays => _prefs.getInt('recentlyAddedDays') ?? 14;
  set recentlyAddedDays(int v) => _set('recentlyAddedDays', v);

  int get recentlyPlayedDays => _prefs.getInt('recentlyPlayedDays') ?? 7;
  set recentlyPlayedDays(int v) => _set('recentlyPlayedDays', v);

  bool get autoDownloadLyrics => _prefs.getBool('autoLyrics') ?? false;
  set autoDownloadLyrics(bool v) => _set('autoLyrics', v);

  bool get showLyricsTranslation => _prefs.getBool('lyricsTranslation') ?? true;
  set showLyricsTranslation(bool v) => _set('lyricsTranslation', v);

  /// Backup: all settings as a JSON string.
  String exportJson() => jsonEncode({
        for (final k in _prefs.getKeys()) k: _prefs.get(k),
      });

  /// Restore from [exportJson] output. Returns false if the text is invalid.
  Future<bool> importJson(String text) async {
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      for (final e in data.entries) {
        final v = e.value;
        if (v is bool) {
          await _prefs.setBool(e.key, v);
        } else if (v is int) {
          await _prefs.setInt(e.key, v);
        } else if (v is double) {
          await _prefs.setDouble(e.key, v);
        } else if (v is String) {
          await _prefs.setString(e.key, v);
        } else if (v is List) {
          await _prefs.setStringList(e.key, v.map((x) => '$x').toList());
        }
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _set(String key, Object value) {
    switch (value) {
      case final int v:
        _prefs.setInt(key, v);
      case final bool v:
        _prefs.setBool(key, v);
      case final String v:
        _prefs.setString(key, v);
    }
    notifyListeners();
  }
}
