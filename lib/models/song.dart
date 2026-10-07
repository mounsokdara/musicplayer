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

  factory Song.fromModel(SongModel m) => Song(
        id: m.id,
        title: m.title,
        artist: m.artist ?? 'Unknown artist',
        album: m.album ?? 'Unknown album',
        albumId: m.albumId,
        albumArtist: m.getMap['album_artist'] as String? ?? m.artist ?? '',
        genre: m.genre ?? '',
        composer: m.composer ?? '',
        data: m.data,
        duration: Duration(milliseconds: m.duration ?? 0),
        track: m.track ?? 0,
        year: m.getMap['year'] as int? ?? 0,
        dateAdded: m.dateAdded ?? 0,
        dateModified: m.dateModified ?? 0,
        size: m.size,
      );

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
