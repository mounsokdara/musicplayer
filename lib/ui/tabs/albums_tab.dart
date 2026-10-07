import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../state/library_state.dart';
import 'collection_grid.dart';
import 'library_header.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    return CollectionGrid(
      artworkType: ArtworkType.ALBUM,
      trailing: const GridDensityButton(),
      items: [
        for (final a in library.albums)
          CollectionItem(
            id: a.id,
            title: a.album,
            subtitle: '${a.artist ?? 'Unknown artist'} • ${a.numOfSongs} songs',
            songCount: a.numOfSongs,
            loadSongs: () => library.songsOfAlbum(a.id),
          ),
      ],
    );
  }
}
