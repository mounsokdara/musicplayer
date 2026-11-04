import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ArtistImages {
  static Future<void> _queue = Future.value();

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/artists');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File?> fetch(String name) {
    final completer = _queue.then((_) => _fetch(name));
    _queue = completer.then((_) => Future<void>.delayed(
          const Duration(milliseconds: 150),
        ));
    return completer;
  }

  static Future<File?> _fetch(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean == 'Unknown artist' || clean == '<unknown>') {
      return null;
    }
    try {
      final key = md5.convert(utf8.encode(clean.toLowerCase())).toString();
      final dir = await _dir();
      final file = File('${dir.path}/$key.jpg');
      if (await file.exists()) return file;
      final none = File('${dir.path}/$key.none');
      if (await none.exists()) return null;

      final res = await http
          .get(Uri.https('api.deezer.com', '/search/artist', {'q': clean, 'limit': '1'}))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final data = body is Map ? body['data'] : null;
      if (data is! List || data.isEmpty) {
        await none.writeAsString('');
        return null;
      }
      final first = data.first as Map;
      final url = (first['picture_big'] ?? first['picture_medium'] ?? first['picture']) as String?;
      if (url == null || url.isEmpty || url.contains('/artist//')) {
        await none.writeAsString('');
        return null;
      }
      final img = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (img.statusCode != 200 || img.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(img.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}
