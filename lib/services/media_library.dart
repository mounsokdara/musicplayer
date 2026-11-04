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
    return rows
        // Keep everything that isn't a system sound: many real tracks (m4a,
        // audiobooks, sideloaded files) are not flagged IS_MUSIC.
        .where((s) =>
            s.data.isNotEmpty &&
            s.isAlarm != true &&
            s.isNotification != true &&
            s.isRingtone != true)
        .map(Song.fromModel)
        .toList();
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
    return rows.map(Song.fromModel).toList();
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
