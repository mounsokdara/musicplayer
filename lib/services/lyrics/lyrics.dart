class LyricWord {
  const LyricWord({required this.start, required this.text});

  final Duration start;
  final String text;
}

class LyricLine {
  const LyricLine({
    required this.start,
    required this.text,
    this.words = const [],
    this.translation,
  });

  final Duration start;
  final String text;
  final List<LyricWord> words;
  final String? translation;

  bool get isBlank => text.trim().isEmpty;
  bool get hasWords => words.isNotEmpty;
  bool get hasTranslation => translation != null && translation!.trim().isNotEmpty;
}

class Lyrics {
  Lyrics({this.title, required this.lines, this.synced = true});

  final String? title;
  final List<LyricLine> lines;
  final bool synced;

  bool get isEmpty => lines.isEmpty;
  bool get hasTranslation => lines.any((l) => l.hasTranslation);
  bool get hasWordSync => lines.any((l) => l.hasWords);

  int indexAt(Duration position) {
    if (!synced) return -1;
    var lo = 0;
    var hi = lines.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (lines[mid].start <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }
}
