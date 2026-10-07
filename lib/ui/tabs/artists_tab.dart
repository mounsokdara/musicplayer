import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../state/library_state.dart';
import 'collection_grid.dart';
import 'library_header.dart';

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    return CollectionGrid(
      artworkType: ArtworkType.ARTIST,
      trailing: const GridDensityButton(),
      items: [
        for (final a in library.artists)
          CollectionItem(
            id: a.id,
            title: a.artist,
            subtitle: '${a.numberOfAlbums ?? 0} albums • ${a.numberOfTracks ?? 0} songs',
            songCount: a.numberOfTracks ?? 0,
            loadSongs: () => library.songsOfArtist(a.id),
          ),
      ],
    );
  }
}
