import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

class PlayStats extends ChangeNotifier {
  PlayStats._(this._prefs, this._counts, this._history);

  static const _countsKey = 'stats_counts';
  static const _historyKey = 'stats_history';
  static const _maxHistory = 500;

  final SharedPreferences _prefs;
  final Map<int, int> _counts;
  final List<(int, int)> _history;

  static Future<PlayStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    final counts = <int, int>{};
    final history = <(int, int)>[];
    try {
      final c = prefs.getString(_countsKey);
      if (c != null) {
        (jsonDecode(c) as Map<String, dynamic>).forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null && v is int) counts[id] = v;
        });
      }
      final h = prefs.getString(_historyKey);
      if (h != null) {
        for (final e in jsonDecode(h) as List) {
          if (e is List && e.length == 2 && e[0] is int && e[1] is int) {
            history.add((e[0] as int, e[1] as int));
          }
        }
      }
    } catch (_) {}
    return PlayStats._(prefs, counts, history);
  }

  int countOf(int id) => _counts[id] ?? 0;

  void recordPlay(Song song) {
    _counts[song.id] = countOf(song.id) + 1;
    _history.insert(0, (song.id, DateTime.now().millisecondsSinceEpoch));
    if (_history.length > _maxHistory) _history.removeLast();
    _persist();
    notifyListeners();
  }

  List<int> mostPlayedIds({int limit = 100}) {
    final ids = _counts.keys.where((id) => _counts[id]! > 0).toList()
      ..sort((a, b) => _counts[b]!.compareTo(_counts[a]!));
    return ids.take(limit).toList();
  }

  List<int> historyIds() {
    final seen = <int>{};
    final out = <int>[];
    for (final e in _history) {
      if (seen.add(e.$1)) out.add(e.$1);
    }
    return out;
  }

  List<int> recentIds(int days) {
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final seen = <int>{};
    final out = <int>[];
    for (final e in _history) {
      if (e.$2 < cutoff) break;
      if (seen.add(e.$1)) out.add(e.$1);
    }
    return out;
  }

  void clear() {
    _counts.clear();
    _history.clear();
    _persist();
    notifyListeners();
  }

  void _persist() {
    _prefs.setString(
      _countsKey,
      jsonEncode(_counts.map((k, v) => MapEntry('$k', v))),
    );
    _prefs.setString(
      _historyKey,
      jsonEncode([
        for (final e in _history) [e.$1, e.$2],
      ]),
    );
  }
}
