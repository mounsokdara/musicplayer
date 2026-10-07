import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../services/media_library.dart';
import '../services/permissions.dart';

/// Sort fields, shared by every sortable list/grid (§5).
enum SongSortField {
  name('Name'),
  album('Album'),
  artist('Artist'),
  albumArtist('Album artist'),
  genre('Genre'),
  track('Track number'),
  duration('Duration'),
  year('Year'),
  composer('Composer'),
  dateModified('Date modified'),
  dateAdded('Date added');

  const SongSortField(this.label);
  final String label;
}

enum CollectionSortField {
  name('Name'),
  songCount('Song count'),
  year('Year'),
  dateModified('Date modified'),
  dateAdded('Date added');

  const CollectionSortField(this.label);
  final String label;
}

class LibraryState extends ChangeNotifier {
  LibraryState(this._library);

  final MediaLibrary _library;

  bool loading = true;
  bool permissionDenied = false;

  List<Song> songs = [];
  List<AlbumModel> albums = [];
  List<ArtistModel> artists = [];
  List<GenreModel> genres = [];
  List<PlaylistModel> playlists = [];

  final Set<String> blacklistedFolders = {};

  SongSortField songSort = SongSortField.name;
  bool songAscending = true;

  CollectionSortField collectionSort = CollectionSortField.name;
  bool collectionAscending = true;

  /// Grid density, 1–4 columns (§6.7).
  int gridColumns = 2;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    if (!await MediaPermissions.request()) {
      permissionDenied = true;
      loading = false;
      notifyListeners();
      return;
    }
    permissionDenied = false;
    await MediaPermissions.requestNotifications();

    final results = await Future.wait([
      _library.songs(),
      _library.albums(),
      _library.artists(),
      _library.genres(),
      _library.playlists(),
    ]);

    songs = (results[0] as List<Song>)
        .where((s) => !blacklistedFolders.contains(s.folder))
        .toList();
    albums = results[1] as List<AlbumModel>;
    artists = results[2] as List<ArtistModel>;
    genres = results[3] as List<GenreModel>;
    playlists = results[4] as List<PlaylistModel>;

    _sortSongs();
    loading = false;
    notifyListeners();
  }

  /// Tapping the active field again reverses the order (§5).
  void setSongSort(SongSortField field) {
    if (songSort == field) {
      songAscending = !songAscending;
    } else {
      songSort = field;
      songAscending = true;
    }
    _sortSongs();
    notifyListeners();
  }

  void setCollectionSort(CollectionSortField field) {
    if (collectionSort == field) {
      collectionAscending = !collectionAscending;
    } else {
      collectionSort = field;
      collectionAscending = true;
    }
    notifyListeners();
  }

  void setGridColumns(int n) {
    gridColumns = n.clamp(1, 4);
    notifyListeners();
  }

  void blacklistFolder(String folder) {
    blacklistedFolders.add(folder);
    songs = songs.where((s) => s.folder != folder).toList();
    notifyListeners();
  }

  List<Song> search(String query) {
    if (query.trim().isEmpty) return songs;
    final q = query.toLowerCase();
    return songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q))
        .toList();
  }

  void _sortSongs() {
    int cmp(Song a, Song b) => switch (songSort) {
          SongSortField.name =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          SongSortField.album =>
            a.album.toLowerCase().compareTo(b.album.toLowerCase()),
          SongSortField.artist =>
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
          SongSortField.albumArtist =>
            a.albumArtist.toLowerCase().compareTo(b.albumArtist.toLowerCase()),
          SongSortField.genre =>
            a.genre.toLowerCase().compareTo(b.genre.toLowerCase()),
          SongSortField.track => a.track.compareTo(b.track),
          SongSortField.duration => a.duration.compareTo(b.duration),
          SongSortField.year => a.year.compareTo(b.year),
          SongSortField.composer =>
            a.composer.toLowerCase().compareTo(b.composer.toLowerCase()),
          SongSortField.dateModified => a.dateModified.compareTo(b.dateModified),
          SongSortField.dateAdded => a.dateAdded.compareTo(b.dateAdded),
        };
    songs.sort((a, b) => songAscending ? cmp(a, b) : cmp(b, a));
  }

  Future<void> rescan() => load();

  Future<List<Song>> songsOfAlbum(int id) =>
      _library.songsOf(id, AudiosFromType.ALBUM_ID);
  Future<List<Song>> songsOfArtist(int id) =>
      _library.songsOf(id, AudiosFromType.ARTIST_ID);
  Future<List<Song>> songsOfGenre(int id) =>
      _library.songsOf(id, AudiosFromType.GENRE_ID);
  Future<List<Song>> songsOfPlaylist(int id) =>
      _library.songsOf(id, AudiosFromType.PLAYLIST);

  Future<void> createPlaylist(String name) async {
    await _library.createPlaylist(name);
    playlists = await _library.playlists();
    notifyListeners();
  }

  Future<void> renamePlaylist(int id, String name) async {
    await _library.renamePlaylist(id, name);
    playlists = await _library.playlists();
    notifyListeners();
  }

  Future<void> deletePlaylist(int id) async {
    await _library.removePlaylist(id);
    playlists = await _library.playlists();
    notifyListeners();
  }

  Future<void> addToPlaylist(int playlistId, int songId) =>
      _library.addToPlaylist(playlistId, songId);
}
