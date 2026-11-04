import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../models/song.dart';
import '../../state/player_state.dart';
import '../equalizer_screen.dart';
import '../widgets/song_artwork.dart';
import 'lyrics_editor.dart';
import 'lyrics_view.dart';
import 'up_next.dart';

/// Expanded state of the player (§6.4). Background adapts to album art.
class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    final scheme = ColorScheme.fromSeed(
      seedColor: player.artworkColor,
      brightness: Theme.of(context).brightness,
    );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: onCollapse,
                  ),
                  const Spacer(),
                  Text('Now playing',
                      style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMenu(context, song),
                  ),
                ],
              ),
              Expanded(
                child: player.lyricsVisible
                    ? const LyricsView()
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: LayoutBuilder(
                            builder: (_, box) => SongArtwork(
                              id: song.id,
                              size: box.maxWidth,
                              radius: 24,
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: Icon(
                        player.isFavorite(song)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: player.isFavorite(song) ? scheme.primary : null,
                      ),
                      onPressed: () => player.toggleFavorite(song),
                    ),
                  ],
                ),
              ),
              _SeekBar(player: player),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: player.previous,
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    iconSize: 40,
                    padding: const EdgeInsets.all(14),
                    icon: Icon(player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    onPressed: player.toggle,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next),
                    onPressed: player.next,
                  ),
                ],
              ),
              const _VolumeSlider(),
              _InfoBadge(song: song),
              _ActionBar(song: song),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration;
        final pos = snap.data ?? Duration.zero;
        final max = total.inMilliseconds.toDouble();
        return Column(
          children: [
            Slider(
              value: pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
              max: max <= 0 ? 1 : max,
              onChanged: (v) =>
                  player.seek(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(pos),
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(formatDuration(total),
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bound to the system media volume stream (§6.4).
class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider();

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double _volume = 0.5;

  @override
  void initState() {
    super.initState();
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((v) {
      if (mounted) setState(() => _volume = v);
    });
    VolumeController.instance.addListener((v) {
      if (mounted) setState(() => _volume = v);
    });
  }

  @override
  void dispose() {
    VolumeController.instance.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.volume_down, size: 20),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                VolumeController.instance.setVolume(v);
              },
            ),
          ),
          const Icon(Icons.volume_up, size: 20),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${song.fileType} • ${song.bitrateKbps} kbps • 44.1 kHz',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

/// Bottom action bar; swiping up on it reveals Up Next (§6.4/§6.5).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final scheme = Theme.of(context).colorScheme;

    final repeatIcon = switch (player.repeat) {
      RepeatMode.off => Icons.repeat,
      RepeatMode.all => Icons.repeat_on,
      RepeatMode.one => Icons.repeat_one_on,
    };

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.velocity.pixelsPerSecond.dy < -100) UpNextSheet.show(context);
      },
      child: Container(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Lyrics',
                  isSelected: player.lyricsVisible,
                  icon: const Icon(Icons.lyrics_outlined),
                  selectedIcon: const Icon(Icons.lyrics),
                  onPressed: player.toggleLyrics,
                ),
                IconButton(
                  tooltip: 'Shuffle',
                  isSelected: player.shuffle,
                  icon: const Icon(Icons.shuffle),
                  selectedIcon: const Icon(Icons.shuffle_on),
                  onPressed: player.toggleShuffle,
                ),
                IconButton(
                  tooltip: 'Sleep timer',
                  icon: const Icon(Icons.bedtime_outlined),
                  onPressed: () => _showSleepTimer(context, player),
                ),
                IconButton(
                  tooltip: 'Repeat',
                  icon: Icon(repeatIcon),
                  onPressed: player.cycleRepeat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showSleepTimer(BuildContext context, PlayerState player) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final minutes in const [15, 30, 45, 60])
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text('$minutes minutes'),
              onTap: () {
                player.setSleepTimer(Duration(minutes: minutes));
                Navigator.pop(sheetContext);
              },
            ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: const Text('Off'),
            onTap: () {
              player.setSleepTimer(null);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    ),
  );
}

/// Now Playing 3-dot menu (§6.4).
void _showMenu(BuildContext context, Song song) {
  final player = context.read<PlayerState>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      void close() => Navigator.pop(sheetContext);
      void soon(String what) {
        close();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$what — coming soon')));
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.equalizer),
                title: const Text('Equalizer'),
                onTap: () {
                  close();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('Save playing queue'),
                onTap: () => soon('Save queue'),
              ),
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Clear playing queue'),
                onTap: () {
                  close();
                  player.clearQueue();
                },
              ),
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: const Text('Go to album'),
                onTap: () => soon('Album'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Go to artist'),
                onTap: () => soon('Artist'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Go to album artist'),
                onTap: () => soon('Album artist'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Go to folder'),
                onTap: () => soon('Folder'),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to playlist'),
                onTap: () => soon('Add to playlist'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Tag editor'),
                onTap: () => soon('Tag editor'),
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: const Text('Edit lyrics'),
                onTap: () {
                  close();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LyricsEditorScreen(song: song),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () => soon('Details'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share'),
                onTap: () {
                  close();
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(song.data)], text: song.title),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete from device'),
                onTap: () => soon('Delete'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Kept so ArtworkType stays imported for artwork queries in this file's tree.
const ArtworkType nowPlayingArtworkType = ArtworkType.AUDIO;
