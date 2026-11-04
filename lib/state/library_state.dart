import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Set<String> whitelistedFolders = {};
  bool useWhitelist = false;
  Set<String> allFolders = {};
  List<Song> _allSongs = [];

  SongSortField songSort = SongSortField.name;
  bool songAscending = true;

  CollectionSortField collectionSort = CollectionSortField.name;
  bool collectionAscending = true;

  /// Grid density, 1–4 columns (§6.7).
  int gridColumns = 2;

  /// Minimum track length (Settings → "Minimum track length").
  int minTrackMs = 3000;

  void setMinTrackSeconds(int seconds) {
    final ms = seconds * 1000;
    if (ms == minTrackMs) return;
    minTrackMs = ms;
    _refilter();
  }

  bool _loadRunning = false;
  bool _reloadQueued = false;
  bool _askedAllFiles = false;
  String? loadError;

  Future<List<T>> _safe<T>(Future<List<T>> f) async {
    try {
      return await f.timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('library query failed: $e');
      loadError = '$e';
      return <T>[];
    }
  }

  /// Loads the library. Always ends with `loading == false`, even when a
  /// query fails or hangs. [quiet] refreshes without showing the spinner.
  Future<void> load({bool quiet = false}) async {
    if (_loadRunning) {
      _reloadQueued = true; // something changed mid-load: run once more
      return;
    }
    _loadRunning = true;
    loadError = null;
    if (!quiet) {
      loading = true;
      notifyListeners();
    }

    try {
      if (!await MediaPermissions.request()) {
        permissionDenied = true;
        return;
      }
      permissionDenied = false;
      unawaited(MediaPermissions.requestNotifications());
      await _loadFilters();

      final results = await Future.wait([
        _safe(_library.songs()),
        _safe(_library.albums()),
        _safe(_library.artists()),
        _safe(_library.genres()),
        _safe(_library.playlists()),
      ]);

      _allSongs = results[0] as List<Song>;
      allFolders = {for (final song in _allSongs) song.folder};
      songs = _allSongs.where(_allowed).toList();
      albums = results[1] as List<AlbumModel>;
      artists = results[2] as List<ArtistModel>;
      genres = results[3] as List<GenreModel>;
      playlists = results[4] as List<PlaylistModel>;
      _sortSongs();

      // Ask for all-files access once, after the library is on screen.
      if (!_askedAllFiles) {
        _askedAllFiles = true;
        unawaited(MediaPermissions.requestAllFilesAccess());
      }
    } catch (e, st) {
      debugPrint('library load failed: $e\n$st');
      loadError = '$e';
    } finally {
      _loadRunning = false;
      loading = false;
      notifyListeners();
      if (_reloadQueued) {
        _reloadQueued = false;
        unawaited(load(quiet: true));
      }
    }
  }

  /// Re-index one file after its tags changed, then refresh quietly.
  Future<void> rescanFile(String path) async {
    try {
      await _library.scan(path);
    } catch (e) {
      debugPrint('scan failed: $e');
    }
    await load(quiet: true);
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

  static bool _inside(String folder, String root) =>
      folder == root || folder.startsWith('$root/');

  bool _allowed(Song song) {
    if (song.duration.inMilliseconds < minTrackMs) return false;
    if (useWhitelist && whitelistedFolders.isNotEmpty) {
      return whitelistedFolders.any((f) => _inside(song.folder, f));
    }
    return !blacklistedFolders.any((f) => _inside(song.folder, f));
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    blacklistedFolders
      ..clear()
      ..addAll(prefs.getStringList('blacklist') ?? const []);
    whitelistedFolders
      ..clear()
      ..addAll(prefs.getStringList('whitelist') ?? const []);
    useWhitelist = prefs.getBool('useWhitelist') ?? false;
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blacklist', blacklistedFolders.toList());
    await prefs.setStringList('whitelist', whitelistedFolders.toList());
    await prefs.setBool('useWhitelist', useWhitelist);
  }

  void _refilter() {
    songs = _allSongs.where(_allowed).toList();
    _sortSongs();
    notifyListeners();
  }

  void _applyFilters() {
    _refilter();
    _saveFilters();
  }

  void blacklistFolder(String folder) {
    blacklistedFolders.add(folder);
    _applyFilters();
  }

  void unblacklistFolder(String folder) {
    blacklistedFolders.remove(folder);
    _applyFilters();
  }

  void whitelistFolder(String folder) {
    whitelistedFolders.add(folder);
    _applyFilters();
  }

  void unwhitelistFolder(String folder) {
    whitelistedFolders.remove(folder);
    _applyFilters();
  }

  void setUseWhitelist(bool value) {
    useWhitelist = value;
    _applyFilters();
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

  // Album/artist/genre/playlist views honour blacklist/whitelist as well.
  Future<List<Song>> _filtered(int id, AudiosFromType type) async =>
      (await _library.songsOf(id, type)).where(_allowed).toList();

  Future<List<Song>> songsOfAlbum(int id) =>
      _filtered(id, AudiosFromType.ALBUM_ID);
  Future<List<Song>> songsOfArtist(int id) =>
      _filtered(id, AudiosFromType.ARTIST_ID);
  Future<List<Song>> songsOfGenre(int id) =>
      _filtered(id, AudiosFromType.GENRE_ID);
  Future<List<Song>> songsOfPlaylist(int id) =>
      _filtered(id, AudiosFromType.PLAYLIST);

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
