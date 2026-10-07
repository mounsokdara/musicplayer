import 'package:audio_service/audio_service.dart';
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
    _player.playbackEventStream.listen(_broadcastState);
    _player.currentIndexStream.listen((i) {
      if (i != null && i < queue.value.length) {
        mediaItem.add(queue.value[i]);
      }
    });
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && !_player.hasNext) {
        stop();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  AudioPlayer get player => _player;

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    final items = songs.map(_toItem).toList();
    queue.add(items);
    await _playlist.clear();
    await _playlist.addAll(
      songs.map((s) => AudioSource.file(s.data, tag: _toItem(s))).toList(),
    );
    if (_player.audioSource == null) {
      await _player.setAudioSource(_playlist, initialIndex: startIndex);
    } else {
      await _player.seek(Duration.zero, index: startIndex);
    }
    mediaItem.add(items[startIndex]);
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
    await _playlist.clear();
    queue.add([]);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
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
