import 'package:xml/xml.dart';

import 'lyrics.dart';

class TtmlParser {
  static String? _attr(XmlElement e, String local) {
    for (final a in e.attributes) {
      if (a.name.local == local) return a.value;
    }
    return null;
  }

  static Duration? _time(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;
    if (v.endsWith('ms')) {
      final n = double.tryParse(v.substring(0, v.length - 2));
      return n == null ? null : Duration(microseconds: (n * 1000).round());
    }
    if (v.endsWith('s')) {
      final n = double.tryParse(v.substring(0, v.length - 1));
      return n == null ? null : Duration(microseconds: (n * 1000000).round());
    }
    final parts = v.split(':');
    if (parts.length > 3) return null;
    var total = 0.0;
    for (final p in parts) {
      final n = double.tryParse(p);
      if (n == null) return null;
      total = total * 60 + n;
    }
    return Duration(microseconds: (total * 1000000).round());
  }

  static Lyrics? parse(String source) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } catch (_) {
      return null;
    }

    final lines = <LyricLine>[];
    for (final p in doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'p')) {
      final begin = _time(_attr(p, 'begin'));
      if (begin == null) continue;

      final words = <LyricWord>[];
      final text = StringBuffer();
      String? translation;

      for (final node in p.children) {
        if (node is XmlElement && node.name.local == 'span') {
          final role = _attr(node, 'role');
          if (role == 'x-translation') {
            translation = node.innerText.trim();
            continue;
          }
          if (role == 'x-roman') continue;
          final t = node.innerText;
          text.write(t);
          words.add(LyricWord(start: _time(_attr(node, 'begin')) ?? begin, text: t));
        } else if (node is XmlText) {
          final t = node.value;
          text.write(t);
          if (words.isNotEmpty && t.trim().isEmpty && t.isNotEmpty) {
            final last = words.removeLast();
            words.add(LyricWord(
              start: last.start,
              text: last.text.endsWith(' ') ? last.text : '${last.text} ',
            ));
          }
        } else if (node is XmlElement && node.name.local == 'br') {
          text.write(' ');
        }
      }

      final clean = text.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      lines.add(LyricLine(
        start: begin,
        text: clean,
        words: words.length > 1 ? words : const [],
        translation: translation,
      ));
    }

    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.start.compareTo(b.start));
    return Lyrics(lines: lines);
  }
}
