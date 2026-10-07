import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../state/library_state.dart';
import '../state/player_state.dart';
import 'tabs/songs_tab.dart';

/// Folder browser, grouped from the scanned library paths (§4 drawer).
class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();

    final byFolder = <String, List<Song>>{};
    for (final song in library.songs) {
      byFolder.putIfAbsent(song.folder, () => []).add(song);
    }
    final folders = byFolder.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, i) {
          final path = folders[i];
          final songs = byFolder[path]!;
          return ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(path.split('/').last),
            subtitle: Text('${songs.length} songs • $path',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FolderSongs(path: path, songs: songs),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FolderSongs extends StatelessWidget {
  const _FolderSongs({required this.path, required this.songs});

  final String path;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(path.split('/').last)),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 160),
        itemCount: songs.length,
        itemBuilder: (context, i) => Consumer<PlayerState>(
          builder: (_, player, __) => SongRow(
            song: songs[i],
            playing: player.isCurrent(songs[i]),
            isPlaying: player.isPlaying,
            onTap: () => player.playAll(songs, i),
          ),
        ),
      ),
    );
  }
}
