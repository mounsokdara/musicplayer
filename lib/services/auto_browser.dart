import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import 'audio_handler.dart';
import 'play_stats.dart';
import 'settings_service.dart';

class AutoBrowser {
  AutoBrowser({
    required this.handler,
    required this.library,
    required this.stats,
    required this.player,
    required this.settings,
  }) {
    handler.onBrowse = browse;
    handler.onPlayFromId = play;
  }

  final MusicAudioHandler handler;
  final LibraryState library;
  final PlayStats stats;
  final PlayerState player;
  final SettingsService settings;

  static const _songs = 'm_songs';
  static const _favorites = 'm_fav';
  static const _most = 'm_most';
  static const _history = 'm_history';
  static const _added = 'm_added';

  Future<void> _ready() async {
    var waited = 0;
    while (library.loading && waited < 15000) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      waited += 250;
    }
  }

  MediaItem _folder(String id, String title) =>
      MediaItem(id: id, title: title, playable: false);

  List<Song> _byIds(List<int> ids) {
    final map = {for (final s in library.songs) s.id: s};
    return [
      for (final id in ids)
        if (map[id] != null) map[id]!,
    ];
  }

  List<Song> _songsFor(String parent) {
    switch (parent) {
      case _favorites:
        return library.songs.where(player.isFavorite).toList();
      case _most:
        return _byIds(stats.mostPlayedIds());
      case _history:
        return _byIds(stats.historyIds());
      case _added:
        final cutoff = DateTime.now()
                .subtract(Duration(days: settings.recentlyAddedDays))
                .millisecondsSinceEpoch ~/
            1000;
        return library.songs.where((s) => s.dateAdded >= cutoff).toList()
          ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      default:
        return library.songs;
    }
  }

  Future<List<MediaItem>> browse(String parent) async {
    await _ready();
    if (parent == AudioService.browsableRootId) {
      return [
        _folder(_songs, 'Songs'),
        _folder(_favorites, 'Favorites'),
        _folder(_most, 'Most played'),
        _folder(_history, 'History'),
        _folder(_added, 'Recently added'),
      ];
    }
    return [
      for (final s in _songsFor(parent).take(300))
        MediaItem(
          id: '$parent|${s.data}',
          title: s.title,
          artist: s.artist,
          album: s.album,
          duration: s.duration,
          artUri: s.albumId == null
              ? null
              : Uri.parse('content://media/external/audio/albumart/${s.albumId}'),
          playable: true,
        ),
    ];
  }

  Future<void> play(String mediaId) async {
    await _ready();
    final cut = mediaId.indexOf('|');
    final parent = cut == -1 ? _songs : mediaId.substring(0, cut);
    final path = cut == -1 ? mediaId : mediaId.substring(cut + 1);
    final list = _songsFor(parent);
    final index = list.indexWhere((s) => s.data == path);
    if (index == -1) return;
    await player.playAll(list, index);
  }
}
