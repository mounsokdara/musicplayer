import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../state/library_state.dart';
import 'collection_grid.dart';
import 'library_header.dart';

class GenresTab extends StatelessWidget {
  const GenresTab({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    return CollectionGrid(
      artworkType: ArtworkType.GENRE,
      trailing: const GridDensityButton(),
      items: [
        for (final g in library.genres)
          CollectionItem(
            id: g.id,
            title: g.genre,
            subtitle: '${g.numOfSongs} songs',
            songCount: g.numOfSongs,
            loadSongs: () => library.songsOfGenre(g.id),
          ),
      ],
    );
  }
}
