import 'package:flutter/foundation.dart' show debugPrint;
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';

/// Thin wrapper over MediaStore queries.
class MediaLibrary {
  final OnAudioQuery _q = OnAudioQuery();

  Future<List<Song>> songs() async {
    final rows = await _q.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final songs = <Song>[];
    for (final row in rows) {
      try {
        // Keep everything that isn't a system sound: many real tracks (m4a,
        // audiobooks, sideloaded files) are not flagged IS_MUSIC.
        final m = row.getMap;
        if (m['is_alarm'] == true ||
            m['is_notification'] == true ||
            m['is_ringtone'] == true) {
          continue;
        }
        final song = Song.fromModel(row);
        if (song.data.isNotEmpty) songs.add(song);
      } catch (e) {
        // One malformed row must not take the whole library down.
        debugPrint('skipping unreadable track: $e');
      }
    }
    return songs;
  }

  Future<List<AlbumModel>> albums() =>
      _q.queryAlbums(uriType: UriType.EXTERNAL, ignoreCase: true);

  Future<List<ArtistModel>> artists() =>
      _q.queryArtists(uriType: UriType.EXTERNAL, ignoreCase: true);

  Future<List<GenreModel>> genres() =>
      _q.queryGenres(uriType: UriType.EXTERNAL, ignoreCase: true);

  Future<List<PlaylistModel>> playlists() =>
      _q.queryPlaylists(uriType: UriType.EXTERNAL, ignoreCase: true);

  Future<List<Song>> songsOf(int id, AudiosFromType type) async {
    final rows = await _q.queryAudiosFrom(type, id);
    final songs = <Song>[];
    for (final row in rows) {
      try {
        songs.add(Song.fromModel(row));
      } catch (e) {
        debugPrint('skipping unreadable track: $e');
      }
    }
    return songs;
  }

  Future<bool> createPlaylist(String name) => _q.createPlaylist(name);
  Future<bool> renamePlaylist(int id, String name) =>
      _q.renamePlaylist(id, name);
  Future<bool> removePlaylist(int id) => _q.removePlaylist(id);
  Future<bool> addToPlaylist(int playlistId, int audioId) =>
      _q.addToPlaylist(playlistId, audioId);
  Future<bool> removeFromPlaylist(int playlistId, int audioId) =>
      _q.removeFromPlaylist(playlistId, audioId);

  Future<void> scan(String path) => _q.scanMedia(path);
}
