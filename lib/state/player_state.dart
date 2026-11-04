import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart'
    show LoopMode, PositionDiscontinuityReason;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../services/audio_handler.dart';
import '../services/lyrics/lyrics.dart';
import '../services/lyrics/lyrics_service.dart';
import '../services/play_stats.dart';
import '../services/replay_gain.dart';
import '../services/scrobbler.dart';
import '../services/settings_service.dart';

enum RepeatMode { off, all, one }

class PlayerState extends ChangeNotifier {
  PlayerState(
    this.handler, {
    required this.stats,
    required this.scrobbler,
    required this.settings,
  }) {
    handler.player.playerStateStream.listen((_) => notifyListeners());
    handler.player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < _queue.length) {
        _index = i;
        _onTrackChanged();
        notifyListeners();
      }
    });
    handler.player.positionStream.listen(_onPosition);
    // Repeat-one loops the same index, so no track-change event fires: count
    // each loop as a new play (stats + scrobble).
    handler.player.positionDiscontinuityStream.listen((d) {
      if (d.reason == PositionDiscontinuityReason.autoAdvance &&
          handler.player.loopMode == LoopMode.one) {
        _counted = false;
        _startedAt = DateTime.now();
        final song = current;
        if (song != null) scrobbler.nowPlaying(song);
      }
    });
    handler.player.playingStream.listen((playing) {
      if (!playing) _writePosition();
    });
    _restoreFavorites();
  }

  final MusicAudioHandler handler;
  final PlayStats stats;
  final Scrobbler scrobbler;
  final SettingsService settings;

  bool _counted = false;
  DateTime _startedAt = DateTime.now();
  final OnAudioQuery _query = OnAudioQuery();

  List<Song> _queue = [];
  int _index = -1;
  RepeatMode repeat = RepeatMode.off;
  bool shuffle = false;
  bool lyricsVisible = false;
  Lyrics? lyrics;
  bool lyricsBusy = false;
  Color artworkColor = const Color(0xFF4A6FA5);
  Timer? _sleepTimer;
  Duration? sleepRemaining;
  final Set<int> favorites = {};

  List<Song> get queue => List.unmodifiable(_queue);
  int get index => _index;
  Song? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get isPlaying => handler.player.playing;
  bool get hasTrack => current != null;

  Stream<Duration> get positionStream => handler.player.positionStream;
  Duration get position => handler.player.position;
  Duration get duration => handler.player.duration ?? Duration.zero;

  bool isCurrent(Song s) => current?.id == s.id;
  bool isFavorite(Song s) => favorites.contains(s.id);

  Future<void> playAll(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    final start = startIndex.clamp(0, songs.length - 1);
    _queue = List.of(songs);
    _index = start;
    await handler.setQueue(_queue, startIndex: start);
    unawaited(handler.play());
    _onTrackChanged();
    notifyListeners();
    _saveQueue();
  }

  Future<void> toggle() =>
      isPlaying ? handler.pause() : handler.play();
  Future<void> next() => handler.skipToNext();
  Future<void> previous() => handler.skipToPrevious();
  Future<void> seek(Duration p) => handler.seek(p);

  Future<void> stopPlayback() async {
    await handler.stop();
    await handler.clearQueue();
    _queue = [];
    _index = -1;
    notifyListeners();
    _saveQueue();
  }

  Future<void> playNext(Song s) async {
    // Nothing loaded yet: "play next" just starts the song.
    if (_queue.isEmpty) return playAll([s], 0);
    await handler.addNext(s);
    _queue.insert((_index + 1).clamp(0, _queue.length), s);
    notifyListeners();
    _saveQueue();
  }

  Future<void> addToQueue(Song s) async {
    if (_queue.isEmpty) return playAll([s], 0);
    await handler.addToQueue(s);
    _queue.add(s);
    notifyListeners();
    _saveQueue();
  }

  Future<void> playQueueItem(int i) async {
    await handler.skipToQueueItem(i);
    unawaited(handler.play());
  }

  Future<void> reorderQueue(int from, int to) async {
    if (to > from) to -= 1;
    await handler.moveQueueItem(from, to);
    _queue.insert(to, _queue.removeAt(from));
    _saveQueue();
    if (_index == from) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index -= 1;
    } else if (from > _index && to <= _index) {
      _index += 1;
    }
    notifyListeners();
  }

  Future<void> removeFromQueue(int i) async {
    await handler.removeQueueItemAt(i);
    _queue.removeAt(i);
    if (i < _index) _index -= 1;
    notifyListeners();
    _saveQueue();
  }

  Future<void> clearQueue() async {
    await handler.clearQueue();
    _queue = [];
    _index = -1;
    notifyListeners();
    _saveQueue();
  }

  /// Off -> Repeat All -> Repeat One (§6.4).
  Future<void> cycleRepeat() async {
    repeat = switch (repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    await handler.setRepeatMode(switch (repeat) {
      RepeatMode.off => AudioServiceRepeatMode.none,
      RepeatMode.all => AudioServiceRepeatMode.all,
      RepeatMode.one => AudioServiceRepeatMode.one,
    });
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    await handler.setShuffleMode(
      shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    notifyListeners();
  }

  void toggleLyrics() {
    lyricsVisible = !lyricsVisible;
    notifyListeners();
  }

  Future<void> toggleFavorite(Song s) async {
    favorites.contains(s.id) ? favorites.remove(s.id) : favorites.add(s.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'favorites', favorites.map((e) => '$e').toList());
    notifyListeners();
  }

  double get speed => handler.player.speed;
  double get pitch => handler.player.pitch;

  Future<void> setSpeed(double v) async {
    await handler.player.setSpeed(v);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    await handler.player.setPitch(v);
    notifyListeners();
  }

  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    sleepRemaining = d;
    if (d == null) {
      notifyListeners();
      return;
    }
    final end = DateTime.now().add(d);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        t.cancel();
        sleepRemaining = null;
        handler.pause();
      } else {
        sleepRemaining = left;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _restoreFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    favorites
      ..clear()
      ..addAll((prefs.getStringList('favorites') ?? [])
          .map(int.tryParse)
          .whereType<int>());
    notifyListeners();
  }

  int? _lastChangeId;
  DateTime _lastChangeAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ---- Session persistence: queue + position survive app restarts ----

  Timer? _saveTimer;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Debounced: the id list can be large, so only write it when it changes.
  void _saveQueue() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _writeQueue);
  }

  Future<void> _writeQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_queue.isEmpty) {
        await prefs.remove('session_ids');
        await prefs.remove('session_current');
        await prefs.remove('session_pos');
        return;
      }
      await prefs.setStringList(
          'session_ids', _queue.map((s) => '${s.id}').toList());
      await prefs.setInt('session_current', current?.id ?? _queue.first.id);
      await prefs.setInt('session_pos', handler.player.position.inMilliseconds);
    } catch (e) {
      debugPrint('session save failed: $e');
    }
  }

  Future<void> _writePosition() async {
    _lastPositionSave = DateTime.now();
    if (_queue.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('session_current', current?.id ?? _queue.first.id);
      await prefs.setInt('session_pos', handler.player.position.inMilliseconds);
    } catch (_) {}
  }

  /// Puts the last queue back (paused) once the library is loaded.
  Future<void> restoreSession(List<Song> library) async {
    if (_queue.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('session_ids');
      if (ids == null || ids.isEmpty) return;
      final byId = {for (final s in library) s.id: s};
      final songs = [
        for (final raw in ids)
          if (byId[int.tryParse(raw)] case final song?) song,
      ];
      if (songs.isEmpty) return;
      final currentId = prefs.getInt('session_current');
      var start = songs.indexWhere((s) => s.id == currentId);
      var position = Duration(milliseconds: prefs.getInt('session_pos') ?? 0);
      if (start < 0) {
        start = 0;
        position = Duration.zero;
      }
      _queue = songs;
      _index = start;
      await handler.setQueue(songs, startIndex: start, position: position);
      _onTrackChanged(announce: false);
      notifyListeners();
    } catch (e) {
      debugPrint('session restore failed: $e');
    }
  }

  void _onTrackChanged({bool announce = true}) {
    final now = DateTime.now();
    final id = current?.id;
    if (id != null &&
        _lastChangeId == id &&
        now.difference(_lastChangeAt) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastChangeId = id;
    _lastChangeAt = now;
    _counted = false;
    _startedAt = now;
    _loadLyrics();
    _updateArtworkColor();
    _applyReplayGain();
    final song = current;
    if (announce && song != null) scrobbler.nowPlaying(song);
    _saveQueue();
  }

  void _onPosition(Duration pos) {
    if (handler.player.playing &&
        DateTime.now().difference(_lastPositionSave) >
            const Duration(seconds: 15)) {
      _writePosition();
    }
    final song = current;
    if (song == null || _counted || !handler.player.playing) return;
    final total = duration;
    if (total == Duration.zero) return;
    final threshold =
        Duration(milliseconds: math.min(total.inMilliseconds ~/ 2, 240000));
    if (pos < threshold) return;
    _counted = true;
    stats.recordPlay(song);
    if (total >= const Duration(seconds: 30)) {
      scrobbler.scrobble(song, _startedAt);
    }
  }

  Future<void> _applyReplayGain() async {
    final song = current;
    if (song == null) return;
    var volume = 1.0;
    if (settings.replayGain) {
      final gain = await ReplayGain.read(song.data);
      if (gain != null) {
        volume = math.min(1.0, math.pow(10, gain / 20).toDouble());
      }
    }
    if (current?.id != song.id) return;
    handler.baseVolume = volume;
    await handler.player.setVolume(volume);
  }

  Future<void> _loadLyrics() async {
    final song = current;
    if (song == null) return;
    lyrics = null;
    lyricsBusy = true;
    notifyListeners();

    var loaded = await LyricsService.load(song);
    if (loaded == null && settings.autoDownloadLyrics) {
      final text = await LyricsService.download(song);
      if (text != null) {
        await LyricsService.save(song, text);
        loaded = LyricsService.parseText(text);
      }
    }
    if (current?.id != song.id) return;
    lyrics = loaded;
    lyricsBusy = false;
    notifyListeners();
  }

  Future<bool> downloadLyrics(Song song) async {
    final isCurrent = current?.id == song.id;
    if (isCurrent) {
      lyricsBusy = true;
      notifyListeners();
    }
    final text = await LyricsService.download(song);
    if (text != null) await LyricsService.save(song, text);
    if (isCurrent && current?.id == song.id) {
      lyrics = text == null ? lyrics : LyricsService.parseText(text);
      lyricsBusy = false;
      notifyListeners();
    }
    return text != null;
  }

  Future<void> refreshLyrics(Song song) async {
    if (current?.id == song.id) await _loadLyrics();
  }

  /// Dynamic background from album art (§6.4).
  Future<void> _updateArtworkColor() async {
    final song = current;
    if (song == null) return;
    try {
      final bytes = await _query.queryArtwork(song.id, ArtworkType.AUDIO,
          size: 200, quality: 100);
      if (bytes == null) return;
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        size: const Size(160, 160),
        maximumColorCount: 12,
      );
      artworkColor = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          artworkColor;
      notifyListeners();
    } catch (_) {
      // Artwork is optional; keep the previous color.
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
