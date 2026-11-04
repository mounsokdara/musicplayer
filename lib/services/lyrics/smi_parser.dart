import 'dart:io';

import 'package:html_unescape/html_unescape.dart';

import 'lyrics.dart';

/// Parser for SAMI synced-lyrics files.
///
/// SAMI is HTML-ish and rarely well formed: tags are unclosed, attributes are
/// unquoted or single quoted, and blank lines are encoded as `&nbsp;`. So we
/// scan for `<SYNC Start=...>` markers instead of using an XML parser.
class SmiParser {
  static final _unescape = HtmlUnescape();

  static final _titleRe =
      RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);
  static final _syncRe = RegExp(
    r'''<sync\s+start\s*=\s*["']?(-?\d+)["']?[^>]*>''',
    caseSensitive: false,
  );
  static final _tagRe = RegExp(r'<[^>]*>', dotAll: true);
  static final _commentRe = RegExp(r'<!--.*?-->', dotAll: true);
  static final _styleRe =
      RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true);

  /// Parse SAMI [source]. Blank (`&nbsp;`) cues are kept so that a line can be
  /// cleared while an instrumental section plays; pass
  /// [keepBlankCues] = false to drop them.
  static Lyrics parse(String source, {bool keepBlankCues = true}) {
    final cleaned = source.replaceAll(_styleRe, '').replaceAll(_commentRe, '');

    final title = _titleRe.firstMatch(source)?.group(1)?.trim();

    final matches = _syncRe.allMatches(cleaned).toList();
    final lines = <LyricLine>[];

    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final ms = int.tryParse(m.group(1)!) ?? 0;
      final end = i + 1 < matches.length ? matches[i + 1].start : cleaned.length;
      final raw = cleaned.substring(m.end, end);

      final text = _unescape
          .convert(raw.replaceAll(_tagRe, ' '))
          // &nbsp; unescapes to U+00A0, which is not stripped by trim().
          .replaceAll('\u00a0', ' ')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();

      final line = LyricLine(start: Duration(milliseconds: ms), text: text);
      if (line.isBlank && !keepBlankCues) continue;
      lines.add(line);
    }

    lines.sort((a, b) => a.start.compareTo(b.start));
    return Lyrics(title: title, lines: lines);
  }

  /// Load lyrics sitting next to an audio file (`song.mp3` -> `song.smi`).
  static Future<Lyrics?> forAudioFile(String audioPath) async {
    final dot = audioPath.lastIndexOf('.');
    final base = dot == -1 ? audioPath : audioPath.substring(0, dot);
    for (final ext in const ['.smi', '.sami', '.SMI']) {
      final file = File('$base$ext');
      if (await file.exists()) {
        // SAMI files in the wild are often not UTF-8; fall back to latin-1.
        final bytes = await file.readAsBytes();
        String text;
        try {
          text = String.fromCharCodes(bytes);
          text = await file.readAsString();
        } catch (_) {
          text = String.fromCharCodes(bytes);
        }
        return parse(text);
      }
    }
    return null;
  }
}
