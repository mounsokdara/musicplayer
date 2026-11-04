import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
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
    _queue = List.of(songs);
    _index = startIndex;
    await handler.setQueue(_queue, startIndex: startIndex);
    unawaited(handler.play());
    _onTrackChanged();
    notifyListeners();
  }

  Future<void> toggle() =>
      isPlaying ? handler.pause() : handler.play();
  Future<void> next() => handler.skipToNext();
  Future<void> previous() => handler.skipToPrevious();
  Future<void> seek(Duration p) => handler.seek(p);

  Future<void> stopPlayback() async {
    await handler.stop();
    _queue = [];
    _index = -1;
    notifyListeners();
  }

  Future<void> playNext(Song s) async {
    await handler.addNext(s);
    if (_index + 1 <= _queue.length) _queue.insert(_index + 1, s);
    notifyListeners();
  }

  Future<void> addToQueue(Song s) async {
    await handler.addToQueue(s);
    _queue.add(s);
    notifyListeners();
  }

  Future<void> playQueueItem(int i) async {
    await handler.skipToQueueItem(i);
    unawaited(handler.play());
  }

  Future<void> reorderQueue(int from, int to) async {
    if (to > from) to -= 1;
    await handler.moveQueueItem(from, to);
    _queue.insert(to, _queue.removeAt(from));
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
  }

  Future<void> clearQueue() async {
    await handler.clearQueue();
    _queue = [];
    _index = -1;
    notifyListeners();
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

  void _onTrackChanged() {
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
    if (song != null) scrobbler.nowPlaying(song);
  }

  void _onPosition(Duration pos) {
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
    super.dispose();
  }
}
