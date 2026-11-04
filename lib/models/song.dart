import 'package:on_audio_query/on_audio_query.dart';

/// A track from MediaStore, plus the extras we show in the info badge.
class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.albumArtist,
    required this.genre,
    required this.composer,
    required this.data,
    required this.duration,
    required this.track,
    required this.year,
    required this.dateAdded,
    required this.dateModified,
    required this.size,
  });

  /// Tolerant of the system returning numbers as text (e.g. `year` comes
  /// back as a String) or leaving fields null.
  factory Song.fromModel(SongModel m) {
    final map = m.getMap;
    String? str(String key) {
      final v = map[key];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty || t == '<unknown>' ? null : t;
    }

    final artist = str('artist');
    final data = str('_data') ?? '';
    final fileName = data.contains('/') ? data.split('/').last : data;
    return Song(
      id: _int(map['_id']) ?? 0,
      title: str('title') ?? str('_display_name_wo_ext') ?? fileName,
      artist: artist ?? 'Unknown artist',
      album: str('album') ?? 'Unknown album',
      albumId: _int(map['album_id']),
      albumArtist: str('album_artist') ?? artist ?? '',
      genre: str('genre') ?? '',
      composer: str('composer') ?? '',
      data: data,
      duration: Duration(milliseconds: _int(map['duration']) ?? 0),
      // Track numbers are often encoded as disc*1000+track (e.g. 1005).
      track: (_int(map['track']) ?? 0) % 1000,
      year: _int(map['year']) ?? 0,
      dateAdded: _int(map['date_added']) ?? 0,
      dateModified: _int(map['date_modified']) ?? 0,
      size: _int(map['_size']) ?? 0,
    );
  }

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ??
        double.tryParse(v.toString().trim())?.toInt();
  }

  final int id;
  final String title;
  final String artist;
  final String album;
  final int? albumId;
  final String albumArtist;
  final String genre;
  final String composer;
  final String data;
  final Duration duration;
  final int track;
  final int year;
  final int dateAdded;
  final int dateModified;
  final int size;

  String get folder {
    final i = data.lastIndexOf('/');
    return i <= 0 ? '/' : data.substring(0, i);
  }

  String get fileType {
    final i = data.lastIndexOf('.');
    return i == -1 ? '' : data.substring(i + 1).toUpperCase();
  }

  /// Average bitrate in kbps, derived from file size and duration.
  int get bitrateKbps {
    final secs = duration.inMilliseconds / 1000;
    if (secs <= 0) return 0;
    return (size * 8 / secs / 1000).round();
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
