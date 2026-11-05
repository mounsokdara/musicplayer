import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../services/permissions.dart';
import '../../state/library_state.dart';
import '../../state/player_state.dart';
import '../sheets/song_sheet.dart';
import '../sheets/sort_sheet.dart';
import '../widgets/fast_scroll_list.dart';
import '../widgets/song_artwork.dart';
import '../widgets/visualizer.dart';
import 'library_header.dart';

class SongsTab extends StatefulWidget {
  const SongsTab({super.key});

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final player = context.watch<PlayerState>();
    final songs = library.search(_query);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          LibraryHeader(
            sortLabel: library.songSort.label,
            countLabel: '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
            ascending: library.songAscending,
            onSearchChanged: (v) => setState(() => _query = v),
            onSortTap: () => showSortSheet(
              context: context,
              fields: SongSortField.values,
              labelOf: (f) => f.label,
              active: library.songSort,
              ascending: library.songAscending,
              onSelected: library.setSongSort,
            ),
          ),
          Expanded(
            child: library.loading
                ? const Center(child: CircularProgressIndicator())
                : songs.isEmpty
                    ? _EmptyLibrary(library: library, searching: _query.isNotEmpty)
                    : FastScrollList(
                        itemCount: songs.length,
                        itemExtent: 68,
                        padding: const EdgeInsets.only(bottom: 160),
                        labelAt: (i) {
                          final t = songs[i].title;
                          // runes: title[0] would split emoji/surrogate pairs
                          return t.isEmpty
                              ? '#'
                              : String.fromCharCode(t.runes.first)
                                  .toUpperCase();
                        },
                        itemBuilder: (context, i) => SongRow(
                          song: songs[i],
                          playing: player.isCurrent(songs[i]),
                          isPlaying: player.isPlaying,
                          onTap: () => player.playAll(songs, i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.song,
    required this.playing,
    required this.isPlaying,
    required this.onTap,
  });

  final Song song;
  final bool playing;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: playing ? scheme.secondaryContainer.withValues(alpha: 0.6) : null,
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          children: [
            SongArtwork(id: song.id),
            if (playing)
              Positioned.fill(
                child: BarVisualizer(playing: isPlaying, color: Colors.white),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: playing ? FontWeight.w600 : FontWeight.w400,
            color: playing ? scheme.onSecondaryContainer : null,
          ),
        ),
        subtitle: Text(
          '${song.artist} • ${formatDuration(song.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => showSongSheet(context, song),
        ),
      ),
    );
  }
}

/// Explains *why* the list is empty instead of a bare "No music found".
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.library, required this.searching});

  final LibraryState library;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final String detail;
    if (searching) {
      detail = 'No songs match your search.';
    } else if (library.loadError != null) {
      detail = 'The system could not list your music:\n${library.loadError}';
    } else if (library.systemTrackCount == 0) {
      detail = 'Android reports no audio files. If you just added music, '
          'tap Rescan. Otherwise check that audio permission is allowed.';
    } else {
      detail = '${library.systemTrackCount} tracks found, but all are hidden '
          'by folder filters or the minimum track length setting.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off_outlined, size: 56),
            const SizedBox(height: 12),
            Text('No music found', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: text.bodyMedium),
            if (!searching) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: library.rescan,
                icon: const Icon(Icons.refresh),
                label: const Text('Rescan'),
              ),
              TextButton(
                onPressed: MediaPermissions.openSettings,
                child: const Text('Open app settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
