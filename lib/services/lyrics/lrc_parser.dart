import 'dart:convert';

import 'lyrics.dart';

class _Entry {
  _Entry(this.order, this.start, this.text, this.words);

  final int order;
  final Duration start;
  final String text;
  final List<LyricWord> words;
}

class LrcParser {
  static final _stampRe = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final _wordRe = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');
  static final _tagRe = RegExp(r'^\[([A-Za-z#]+):(.*)\]$');

  static Duration _duration(String m, String s, String? f) {
    var ms = 0;
    if (f != null) {
      ms = int.parse(f.padRight(3, '0').substring(0, 3));
    }
    return Duration(
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: ms,
    );
  }

  static Duration _shift(Duration d, int offsetMs) {
    final v = d.inMilliseconds - offsetMs;
    return Duration(milliseconds: v < 0 ? 0 : v);
  }

  static Lyrics parse(String source) {
    var offset = 0;
    String? title;
    final entries = <_Entry>[];
    final plain = <String>[];
    var order = 0;

    for (final raw in const LineSplitter().convert(source)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final tag = _tagRe.firstMatch(line);
      if (tag != null) {
        final key = tag.group(1)!.toLowerCase();
        final value = tag.group(2)!.trim();
        if (key == 'offset') offset = int.tryParse(value) ?? 0;
        if (key == 'ti') title = value;
        continue;
      }

      final stamps = <Duration>[];
      var rest = line;
      while (true) {
        final m = _stampRe.matchAsPrefix(rest);
        if (m == null) break;
        stamps.add(_duration(m.group(1)!, m.group(2)!, m.group(3)));
        rest = rest.substring(m.end);
      }

      if (stamps.isEmpty) {
        plain.add(line);
        continue;
      }

      final words = <LyricWord>[];
      String text;
      final wordMatches = _wordRe.allMatches(rest).toList();
      if (wordMatches.isEmpty) {
        text = rest.trim();
      } else {
        final lead = rest.substring(0, wordMatches.first.start);
        if (lead.trim().isNotEmpty) {
          words.add(LyricWord(start: stamps.first, text: lead));
        }
        for (var i = 0; i < wordMatches.length; i++) {
          final m = wordMatches[i];
          final end =
              i + 1 < wordMatches.length ? wordMatches[i + 1].start : rest.length;
          final t = rest.substring(m.end, end);
          if (t.isEmpty) continue;
          words.add(LyricWord(
            start: _duration(m.group(1)!, m.group(2)!, m.group(3)),
            text: t,
          ));
        }
        text = words.map((w) => w.text).join().trim();
      }

      for (final s in stamps) {
        entries.add(_Entry(order++, s, text, words));
      }
    }

    if (entries.isEmpty) {
      return Lyrics(
        title: title,
        synced: false,
        lines: [
          for (final p in plain) LyricLine(start: Duration.zero, text: p),
        ],
      );
    }

    entries.sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.order.compareTo(b.order);
    });

    final lines = <LyricLine>[];
    var i = 0;
    while (i < entries.length) {
      final first = entries[i];
      var j = i + 1;
      while (j < entries.length && entries[j].start == first.start) {
        j++;
      }
      final groupSize = j - i;
      String? translation;
      if (groupSize >= 2 && first.text.isNotEmpty) {
        translation = entries[i + 1].text;
      }
      final shiftedWords = [
        for (final w in first.words)
          LyricWord(start: _shift(w.start, offset), text: w.text),
      ];
      lines.add(LyricLine(
        start: _shift(first.start, offset),
        text: first.text,
        words: shiftedWords,
        translation: translation,
      ));
      if (groupSize >= 2 && first.text.isEmpty) {
        for (var k = i + 1; k < j; k++) {
          lines.add(LyricLine(
            start: _shift(entries[k].start, offset),
            text: entries[k].text,
            words: [
              for (final w in entries[k].words)
                LyricWord(start: _shift(w.start, offset), text: w.text),
            ],
          ));
        }
      }
      i = j;
    }

    return Lyrics(title: title, lines: lines);
  }
}
