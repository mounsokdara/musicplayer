import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
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
                    ? const Center(child: Text('No music found'))
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
