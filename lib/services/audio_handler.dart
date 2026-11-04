import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

Future<MusicAudioHandler> initAudioService() async {
  return AudioService.init(
    builder: MusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mounsokdara.musicplayer.audio',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

/// Background handler: owns the just_audio player and the media session so
/// notification, lockscreen, headset buttons and home-screen widgets all
/// control the same playback.
class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  MusicAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcastState,
      // A missing/corrupt file must not freeze playback: skip to the next one.
      onError: (Object e, StackTrace st) {
        debugPrint('playback error: $e');
        if (_player.hasNext) _player.seekToNext();
      },
    );
    _player.currentIndexStream.listen((i) {
      if (i != null && i < queue.value.length) {
        mediaItem.add(queue.value[i]);
      }
    });
    _player.processingStateStream.listen((s) async {
      // End of the queue: stay on the last track, paused at the start.
      if (s == ProcessingState.completed && !_player.hasNext) {
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  AudioPlayer get player => _player;

  bool fadeEnabled = false;
  double baseVolume = 1.0;

  Future<List<MediaItem>> Function(String parentMediaId)? onBrowse;
  Future<void> Function(String mediaId)? onPlayFromId;

  int _rampId = 0;

  /// Linear volume ramp. Returns false if a newer ramp/play/pause took over,
  /// so quick play/pause taps can never leave the volume stuck at 0.
  Future<bool> _ramp(double from, double to) async {
    final id = ++_rampId;
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      if (id != _rampId) return false;
      await _player.setVolume(from + (to - from) * i / steps);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return id == _rampId;
  }

  void _startPlayback() {
    // just_audio's play() only completes when playback pauses or ends, so it
    // must never be awaited by callers.
    unawaited(_player.play().catchError((Object e) {
      debugPrint('play failed: $e');
    }));
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
          [Map<String, dynamic>? options]) async =>
      await onBrowse?.call(parentMediaId) ?? <MediaItem>[];

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    await onPlayFromId?.call(mediaId);
  }

  Future<void> setQueue(
    List<Song> songs, {
    int startIndex = 0,
    Duration position = Duration.zero,
  }) async {
    if (songs.isEmpty) return;
    final index = startIndex.clamp(0, songs.length - 1);
    final items = songs.map(_toItem).toList();
    queue.add(items);
    mediaItem.add(items[index]);
    // A fresh source each time: clearing a playing ConcatenatingAudioSource
    // briefly reports "completed" and could stop playback at random.
    _playlist = ConcatenatingAudioSource(children: [
      for (var i = 0; i < songs.length; i++)
        AudioSource.file(songs[i].data, tag: items[i]),
    ]);
    try {
      await _player.setAudioSource(
        _playlist,
        initialIndex: index,
        initialPosition: position,
      );
    } catch (e) {
      debugPrint('setAudioSource failed: $e');
    }
  }

  Future<void> addNext(Song song) async {
    final index = (_player.currentIndex ?? -1) + 1;
    await _playlist.insert(index, AudioSource.file(song.data, tag: _toItem(song)));
    final q = List<MediaItem>.of(queue.value)..insert(index, _toItem(song));
    queue.add(q);
  }

  Future<void> addToQueue(Song song) async {
    await _playlist.add(AudioSource.file(song.data, tag: _toItem(song)));
    queue.add([...queue.value, _toItem(song)]);
  }

  Future<void> moveQueueItem(int from, int to) async {
    await _playlist.move(from, to);
    final q = List<MediaItem>.of(queue.value);
    q.insert(to, q.removeAt(from));
    queue.add(q);
  }

  Future<void> removeQueueItemAt(int index) async {
    await _playlist.removeAt(index);
    final q = List<MediaItem>.of(queue.value)..removeAt(index);
    queue.add(q);
  }

  Future<void> clearQueue() async {
    await _player.stop();
    _playlist = ConcatenatingAudioSource(children: []);
    queue.add([]);
    mediaItem.add(null);
  }

  @override
  Future<void> play() async {
    if (!fadeEnabled) {
      _rampId++; // cancel any running fade
      await _player.setVolume(baseVolume);
      _startPlayback();
      return;
    }
    _rampId++;
    await _player.setVolume(0);
    _startPlayback();
    await _ramp(0, baseVolume);
  }

  @override
  Future<void> pause() async {
    if (!fadeEnabled || !_player.playing) {
      _rampId++;
      await _player.pause();
      return;
    }
    final finished = await _ramp(_player.volume, 0);
    if (!finished) return; // play() took over while fading out
    await _player.pause();
    await _player.setVolume(baseVolume);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final on = mode == AudioServiceShuffleMode.all;
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
    playbackState.add(playbackState.value.copyWith(shuffleMode: mode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _player.setLoopMode(switch (mode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: mode));
  }

  MediaItem _toItem(Song s) => MediaItem(
        id: s.data,
        title: s.title,
        artist: s.artist,
        album: s.album,
        genre: s.genre,
        duration: s.duration,
        artUri: s.albumId == null
            ? null
            : Uri.parse('content://media/external/audio/albumart/${s.albumId}'),
        extras: {'songId': s.id, 'albumId': s.albumId},
      );

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}
