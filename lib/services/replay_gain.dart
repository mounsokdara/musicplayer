import 'dart:io';

class ReplayGain {
  static final _trackRe = RegExp(
    r'replaygain_track_gain[\s\S]{0,20}?([-+]?\d+(?:\.\d+)?)\s*dB',
    caseSensitive: false,
  );
  static final _albumRe = RegExp(
    r'replaygain_album_gain[\s\S]{0,20}?([-+]?\d+(?:\.\d+)?)\s*dB',
    caseSensitive: false,
  );

  static Future<double?> read(String path) async {
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final length = await raf.length();
      final n = length < 1048576 ? length : 1048576;
      final bytes = await raf.read(n);
      final sb = StringBuffer();
      for (final b in bytes) {
        if (b != 0) sb.writeCharCode(b);
      }
      final text = sb.toString();
      final m = _trackRe.firstMatch(text) ?? _albumRe.firstMatch(text);
      if (m == null) return null;
      final v = double.tryParse(m.group(1)!);
      if (v == null || v < -40 || v > 40) return null;
      return v;
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }
}
