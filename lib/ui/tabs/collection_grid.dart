import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../state/library_state.dart';
import '../../state/player_state.dart';
import '../sheets/sort_sheet.dart';
import '../widgets/song_artwork.dart';
import 'library_header.dart';
import 'songs_tab.dart';

/// Shared grid for Albums / Artists / Genres (§6.8): header, sort bar,
/// grid-density selector, tap-through to a detail list.
class CollectionGrid extends StatelessWidget {
  const CollectionGrid({
    super.key,
    required this.items,
    required this.artworkType,
    required this.trailing,
  });

  final List<CollectionItem> items;
  final ArtworkType artworkType;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final sorted = List<CollectionItem>.of(items)
      ..sort((a, b) {
        final c = switch (library.collectionSort) {
          CollectionSortField.songCount => a.songCount.compareTo(b.songCount),
          _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        };
        return library.collectionAscending ? c : -c;
      });

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          LibraryHeader(
            sortLabel: library.collectionSort.label,
            ascending: library.collectionAscending,
            trailing: trailing,
            onSortTap: () => showSortSheet(
              context: context,
              fields: const [
                CollectionSortField.name,
                CollectionSortField.songCount,
                CollectionSortField.year,
                CollectionSortField.dateModified,
                CollectionSortField.dateAdded,
              ],
              labelOf: (f) => f.label,
              active: library.collectionSort,
              ascending: library.collectionAscending,
              onSelected: library.setCollectionSort,
            ),
          ),
          Expanded(
            child: library.loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 160),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: library.gridColumns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: library.gridColumns == 1 ? 3.2 : 0.8,
                    ),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) => _Tile(
                      item: sorted[i],
                      artworkType: artworkType,
                      single: library.gridColumns == 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.songCount,
    required this.loadSongs,
  });

  final int id;
  final String title;
  final String subtitle;
  final int songCount;
  final Future<List<Song>> Function() loadSongs;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.artworkType,
    required this.single,
  });

  final CollectionItem item;
  final ArtworkType artworkType;
  final bool single;

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(item: item, artworkType: artworkType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (single) {
      return Card(
        child: ListTile(
          onTap: () => _open(context),
          leading: SongArtwork(id: item.id, type: artworkType, size: 56),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (_, box) => SongArtwork(
                id: item.id,
                type: artworkType,
                size: box.maxWidth,
                radius: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
          Text(item.subtitle,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
        ],
      ),
    );
  }
}

class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({
    super.key,
    required this.item,
    required this.artworkType,
  });

  final CollectionItem item;
  final ArtworkType artworkType;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();
    final wide = MediaQuery.sizeOf(context).width >= 640;

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: FutureBuilder<List<Song>>(
        future: item.loadSongs(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final songs = snap.data!;
          final list = ListView.builder(
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: songs.length,
            itemBuilder: (context, i) => Consumer<PlayerState>(
              builder: (_, p, __) => SongRow(
                song: songs[i],
                playing: p.isCurrent(songs[i]),
                isPlaying: p.isPlaying,
                onTap: () => player.playAll(songs, i),
              ),
            ),
          );

          // Multi-pane list + detail on large screens (§7).
          if (!wide) return list;
          return Row(
            children: [
              SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SongArtwork(id: item.id, type: artworkType, size: 240, radius: 20),
                      const SizedBox(height: 16),
                      Text(item.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${songs.length} songs'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => player.playAll(songs, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}
