import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/song.dart';
import 'lrc_parser.dart';
import 'lyrics.dart';
import 'smi_parser.dart';
import 'ttml_parser.dart';

class LyricsService {
  static const _headers = {
    'User-Agent': 'MusicPlayer/0.1 (https://github.com/mounsokdara/musicplayer)',
  };

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/lyrics');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _cacheFile(Song song) async =>
      File('${(await _dir()).path}/${song.id}.lrc');

  static String _basePath(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    return dot == -1 ? audioPath : audioPath.substring(0, dot);
  }

  static Lyrics? parseText(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('<')) {
      if (trimmed.toLowerCase().contains('<sami')) {
        final smi = SmiParser.parse(text);
        return smi.isEmpty ? null : smi;
      }
      return TtmlParser.parse(text);
    }
    final lrc = LrcParser.parse(text);
    return lrc.isEmpty ? null : lrc;
  }

  static Future<String?> _readFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return latin1.decode(bytes);
      }
    } catch (_) {
      return null;
    }
  }

  static Future<String?> storedText(Song song) async {
    final cached = await _cacheFile(song);
    if (await cached.exists()) return _readFile(cached);
    final base = _basePath(song.data);
    for (final ext in const ['.lrc', '.LRC', '.ttml', '.TTML', '.xml']) {
      final f = File('$base$ext');
      if (await f.exists()) return _readFile(f);
    }
    return null;
  }

  static Future<Lyrics?> load(Song song) async {
    final text = await storedText(song);
    if (text != null) {
      final parsed = parseText(text);
      if (parsed != null) return parsed;
    }
    return SmiParser.forAudioFile(song.data);
  }

  static Future<void> save(Song song, String text) async {
    final f = await _cacheFile(song);
    await f.writeAsString(text);
  }

  static Future<void> delete(Song song) async {
    final f = await _cacheFile(song);
    if (await f.exists()) await f.delete();
  }

  static String? _pick(dynamic body) {
    if (body is! Map) return null;
    final synced = body['syncedLyrics'];
    if (synced is String && synced.trim().isNotEmpty) return synced;
    final plain = body['plainLyrics'];
    if (plain is String && plain.trim().isNotEmpty) return plain;
    return null;
  }

  static Future<String?> download(Song song) async {
    final artist = song.artist == 'Unknown artist' ? '' : song.artist;
    final album = song.album == 'Unknown album' ? '' : song.album;
    try {
      final getUri = Uri.https('lrclib.net', '/api/get', {
        'track_name': song.title,
        'artist_name': artist,
        'album_name': album,
        'duration': song.duration.inSeconds.toString(),
      });
      final res = await http
          .get(getUri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final text = _pick(jsonDecode(utf8.decode(res.bodyBytes)));
        if (text != null) return text;
      }

      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'track_name': song.title,
        if (artist.isNotEmpty) 'artist_name': artist,
      });
      final res2 = await http
          .get(searchUri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res2.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(res2.bodyBytes));
      if (list is! List) return null;
      String? fallback;
      for (final item in list) {
        if (item is! Map) continue;
        final dur = item['duration'];
        if (dur is num && (dur - song.duration.inSeconds).abs() > 5) continue;
        final synced = item['syncedLyrics'];
        if (synced is String && synced.trim().isNotEmpty) return synced;
        fallback ??= _pick(item);
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }
}
