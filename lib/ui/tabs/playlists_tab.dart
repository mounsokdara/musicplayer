import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../state/library_state.dart';
import '../../state/player_state.dart';
import '../sheets/sort_sheet.dart';
import '../widgets/song_artwork.dart';
import 'collection_grid.dart';
import 'library_header.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final player = context.read<PlayerState>();

    final sorted = List<PlaylistModel>.of(library.playlists)
      ..sort((a, b) {
        final c = switch (library.collectionSort) {
          CollectionSortField.songCount => a.numOfSongs.compareTo(b.numOfSongs),
          _ => a.playlist.toLowerCase().compareTo(b.playlist.toLowerCase()),
        };
        return library.collectionAscending ? c : -c;
      });

    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 96),
          child: FloatingActionButton(
            onPressed: () => _showFabSheet(context, library),
            child: const Icon(Icons.add),
          ),
        ),
        body: Column(
          children: [
            LibraryHeader(
              sortLabel: library.collectionSort.label,
              ascending: library.collectionAscending,
              trailing: const GridDensityButton(),
              onSortTap: () => showSortSheet(
                context: context,
                fields: CollectionSortField.values,
                labelOf: (f) => f.label,
                active: library.collectionSort,
                ascending: library.collectionAscending,
                onSelected: library.setCollectionSort,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openVirtual(
                        context,
                        'Favorites',
                        library.songs
                            .where((s) => player.isFavorite(s))
                            .toList(),
                      ),
                      icon: const Icon(Icons.favorite_outline),
                      label: const Text('Favorites'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          _openVirtual(context, 'History', player.queue),
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: library.gridColumns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: library.gridColumns == 1 ? 4.5 : 0.9,
                ),
                itemCount: sorted.length,
                itemBuilder: (context, i) => _PlaylistTile(
                  playlist: sorted[i],
                  single: library.gridColumns == 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVirtual(BuildContext context, String title, List<Song> songs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(
          artworkType: ArtworkType.PLAYLIST,
          item: CollectionItem(
            id: -1,
            title: title,
            subtitle: '${songs.length} songs',
            songCount: songs.length,
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
  }

  void _showFabSheet(BuildContext context, LibraryState library) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Import playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import — coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Create playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                _promptName(context, 'Create playlist', library.createPlaylist);
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _promptName(
  BuildContext context,
  String title,
  Future<void> Function(String) onSubmit, {
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            Navigator.pop(dialogContext);
            if (name.isNotEmpty) onSubmit(name);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.single});

  final PlaylistModel playlist;
  final bool single;

  void _open(BuildContext context) {
    final library = context.read<LibraryState>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(
          artworkType: ArtworkType.PLAYLIST,
          item: CollectionItem(
            id: playlist.id,
            title: playlist.playlist,
            subtitle: '${playlist.numOfSongs} songs',
            songCount: playlist.numOfSongs,
            loadSongs: () => library.songsOfPlaylist(playlist.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showPlaylistSheet(context, playlist),
    );

    if (single) {
      return Card(
        child: ListTile(
          onTap: () => _open(context),
          leading: SongArtwork(
              id: playlist.id, type: ArtworkType.PLAYLIST, size: 48),
          title: Text(playlist.playlist,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${playlist.numOfSongs} songs'),
          trailing: menu,
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Icon(Icons.queue_music,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.playlist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${playlist.numOfSongs} songs',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  menu,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Playlist 3-dot bottom sheet (§6.7).
void _showPlaylistSheet(BuildContext context, PlaylistModel playlist) {
  final library = context.read<LibraryState>();
  final player = context.read<PlayerState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      void close() => Navigator.pop(sheetContext);
      Future<List<Song>> songs() => library.songsOfPlaylist(playlist.id);

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.playlist),
                subtitle: Text('${playlist.numOfSongs} songs'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: const Text('Play next'),
                onTap: () async {
                  close();
                  for (final s in (await songs()).reversed) {
                    await player.playNext(s);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Play'),
                onTap: () async {
                  close();
                  await player.playAll(await songs(), 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_outlined),
                title: const Text('Add to playing queue'),
                onTap: () async {
                  close();
                  for (final s in await songs()) {
                    await player.addToQueue(s);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to playlist'),
                onTap: close,
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Choose artwork'),
                onTap: close,
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () {
                  close();
                  _promptName(
                    context,
                    'Rename playlist',
                    (name) => library.renamePlaylist(playlist.id, name),
                    initial: playlist.playlist,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Save as file'),
                onTap: close,
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete playlist'),
                onTap: () {
                  close();
                  library.deletePlaylist(playlist.id);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
