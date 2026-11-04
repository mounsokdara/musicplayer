import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/song.dart';
import '../../state/library_state.dart';
import '../../state/player_state.dart';
import '../player/lyrics_editor.dart';
import '../tag_editor.dart';
import '../widgets/song_artwork.dart';

/// 3-dot bottom sheet for a song row (§6.2).
Future<void> showSongSheet(BuildContext context, Song song) {
  final player = context.read<PlayerState>();
  final library = context.read<LibraryState>();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      void close() => Navigator.pop(context);
      void todo(String what) {
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
                leading: SongArtwork(id: song.id),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${song.artist} • ${formatDuration(song.duration)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: const Text('Play next'),
                onTap: () {
                  player.playNext(song);
                  close();
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: const Text('Add to playing queue'),
                onTap: () {
                  player.addToQueue(song);
                  close();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to playlist'),
                onTap: () {
                  close();
                  _showAddToPlaylist(context, song, library);
                },
              ),
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: const Text('Go to album'),
                onTap: () => todo('Album'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Go to artist'),
                onTap: () => todo('Artist'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Go to album artist'),
                onTap: () => todo('Album artist'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Go to folder'),
                subtitle: Text(song.folder, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => todo('Folder'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Tag editor'),
                onTap: () {
                  final nav = Navigator.of(context);
                  close();
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => TagEditorScreen(song: song),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: const Text('Edit lyrics'),
                onTap: () {
                  final nav = Navigator.of(context);
                  close();
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => LyricsEditorScreen(song: song),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blacklist'),
                onTap: () {
                  library.blacklistFolder(song.folder);
                  close();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () {
                  close();
                  _showDetails(context, song);
                },
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
                onTap: () => todo('Delete'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showDetails(BuildContext context, Song song) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Title', song.title),
            _row('Artist', song.artist),
            _row('Album', song.album),
            _row('Album artist', song.albumArtist),
            _row('Genre', song.genre),
            _row('Composer', song.composer),
            _row('Track', '${song.track}'),
            _row('Year', '${song.year}'),
            _row('Duration', formatDuration(song.duration)),
            _row('Format', song.fileType),
            _row('Bitrate', '${song.bitrateKbps} kbps'),
            _row('Size', '${(song.size / 1048576).toStringAsFixed(1)} MB'),
            _row('Path', song.data),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );

void _showAddToPlaylist(BuildContext context, Song song, LibraryState library) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final p in library.playlists)
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: Text(p.playlist),
              onTap: () {
                library.addToPlaylist(p.id, song.id);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  );
}
