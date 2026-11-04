import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

class Scrobbler extends ChangeNotifier {
  Scrobbler._(this._prefs);

  final SharedPreferences _prefs;
  bool _flushing = false;

  static Future<Scrobbler> load() async =>
      Scrobbler._(await SharedPreferences.getInstance());

  static const _lfmUrl = 'https://ws.audioscrobbler.com/2.0/';
  static const _lbUrl = 'https://api.listenbrainz.org/1/';

  String get lbToken => _prefs.getString('lb_token') ?? '';
  bool get lbEnabled => _prefs.getBool('lb_enabled') ?? false;
  String get lfmKey => _prefs.getString('lfm_key') ?? '';
  String get lfmSecret => _prefs.getString('lfm_secret') ?? '';
  String get lfmSession => _prefs.getString('lfm_session') ?? '';
  String get lfmUser => _prefs.getString('lfm_user') ?? '';
  bool get lfmEnabled => _prefs.getBool('lfm_enabled') ?? false;

  bool get lbReady => lbEnabled && lbToken.isNotEmpty;
  bool get lfmReady =>
      lfmEnabled && lfmKey.isNotEmpty && lfmSecret.isNotEmpty && lfmSession.isNotEmpty;

  set lbToken(String v) => _put('lb_token', v);
  set lbEnabled(bool v) => _put('lb_enabled', v);
  set lfmKey(String v) => _put('lfm_key', v);
  set lfmSecret(String v) => _put('lfm_secret', v);
  set lfmEnabled(bool v) => _put('lfm_enabled', v);

  void _put(String key, Object v) {
    if (v is bool) {
      _prefs.setBool(key, v);
    } else if (v is String) {
      _prefs.setString(key, v);
    }
    notifyListeners();
  }

  void lfmSignOut() {
    _prefs.remove('lfm_session');
    _prefs.remove('lfm_user');
    _prefs.setBool('lfm_enabled', false);
    notifyListeners();
  }

  List<Map<String, dynamic>> _pending() {
    final raw = _prefs.getString('scrobble_pending');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _savePending(List<Map<String, dynamic>> list) {
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    _prefs.setString('scrobble_pending', jsonEncode(trimmed));
  }

  int get pendingCount => _pending().length;

  String _sign(Map<String, String> params) {
    final keys = params.keys.where((k) => k != 'format' && k != 'callback').toList()
      ..sort();
    final base = keys.map((k) => '$k${params[k]}').join() + lfmSecret;
    return md5.convert(utf8.encode(base)).toString();
  }

  Future<Map<String, dynamic>?> _lfmCall(Map<String, String> params) async {
    final signed = {...params, 'api_key': lfmKey};
    final body = {...signed, 'api_sig': _sign(signed), 'format': 'json'};
    final res = await http
        .post(Uri.parse(_lfmUrl), body: body)
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  Future<String?> lfmLogin(String user, String password) async {
    if (lfmKey.isEmpty || lfmSecret.isEmpty) {
      return 'Enter your Last.fm API key and secret first';
    }
    try {
      final res = await _lfmCall({
        'method': 'auth.getMobileSession',
        'username': user,
        'password': password,
      });
      if (res == null) return 'Unexpected response';
      if (res['error'] != null) return '${res['message'] ?? 'Login failed'}';
      final session = res['session'];
      if (session is Map && session['key'] is String) {
        _prefs.setString('lfm_session', session['key'] as String);
        _prefs.setString('lfm_user', '${session['name'] ?? user}');
        _prefs.setBool('lfm_enabled', true);
        notifyListeners();
        return null;
      }
      return 'Unexpected response';
    } catch (e) {
      return 'Network error';
    }
  }

  Future<String?> lbValidate(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${_lbUrl}validate-token'),
        headers: {'Authorization': 'Token $token'},
      ).timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['valid'] == true) {
        return '${decoded['user_name'] ?? ''}';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _skip(Song s) => s.title.isEmpty || s.artist == 'Unknown artist';

  Future<void> nowPlaying(Song song) async {
    if (_skip(song)) return;
    if (lbReady) {
      try {
        await http
            .post(
              Uri.parse('${_lbUrl}submit-listens'),
              headers: {
                'Authorization': 'Token $lbToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'listen_type': 'playing_now',
                'payload': [
                  {'track_metadata': _lbMeta(song)},
                ],
              }),
            )
            .timeout(const Duration(seconds: 12));
      } catch (_) {}
    }
    if (lfmReady) {
      try {
        await _lfmCall({
          'method': 'track.updateNowPlaying',
          'artist': song.artist,
          'track': song.title,
          if (song.album != 'Unknown album') 'album': song.album,
          'duration': '${song.duration.inSeconds}',
          'sk': lfmSession,
        });
      } catch (_) {}
    }
  }

  Map<String, dynamic> _lbMeta(Song s) => {
        'artist_name': s.artist,
        'track_name': s.title,
        if (s.album != 'Unknown album') 'release_name': s.album,
        'additional_info': {
          'media_player': 'Music Player',
          'duration_ms': s.duration.inMilliseconds,
        },
      };

  Future<void> scrobble(Song song, DateTime startedAt) async {
    if (_skip(song)) return;
    if (!lbReady && !lfmReady) return;
    final list = _pending()
      ..add({
        'artist': song.artist,
        'title': song.title,
        'album': song.album == 'Unknown album' ? '' : song.album,
        'duration': song.duration.inSeconds,
        'ts': startedAt.millisecondsSinceEpoch ~/ 1000,
        'lb': lbReady,
        'lfm': lfmReady,
      });
    _savePending(list);
    notifyListeners();
    await flush();
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final list = _pending();
      for (final e in list) {
        if (e['lb'] == true) {
          if (!lbReady) {
            e['lb'] = false;
          } else if (await _sendLb(e)) {
            e['lb'] = false;
          }
        }
        if (e['lfm'] == true) {
          if (!lfmReady) {
            e['lfm'] = false;
          } else if (await _sendLfm(e)) {
            e['lfm'] = false;
          }
        }
      }
      _savePending(
        list.where((e) => e['lb'] == true || e['lfm'] == true).toList(),
      );
      notifyListeners();
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _sendLb(Map<String, dynamic> e) async {
    try {
      final res = await http
          .post(
            Uri.parse('${_lbUrl}submit-listens'),
            headers: {
              'Authorization': 'Token $lbToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'listen_type': 'single',
              'payload': [
                {
                  'listened_at': e['ts'],
                  'track_metadata': {
                    'artist_name': e['artist'],
                    'track_name': e['title'],
                    if ((e['album'] as String).isNotEmpty)
                      'release_name': e['album'],
                  },
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200 || res.statusCode == 400;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendLfm(Map<String, dynamic> e) async {
    try {
      final res = await _lfmCall({
        'method': 'track.scrobble',
        'artist': '${e['artist']}',
        'track': '${e['title']}',
        if ((e['album'] as String).isNotEmpty) 'album': '${e['album']}',
        'timestamp': '${e['ts']}',
        'duration': '${e['duration']}',
        'sk': lfmSession,
      });
      if (res == null) return false;
      final err = res['error'];
      if (err == null) return true;
      return err != 11 && err != 16 && err != 29;
    } catch (_) {
      return false;
    }
  }
}
