import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_state.dart';
import '../state/player_state.dart';
import 'library_drawer.dart';
import 'player/player_container.dart';
import 'tabs/albums_tab.dart';
import 'tabs/artists_tab.dart';
import 'tabs/genres_tab.dart';
import 'tabs/playlists_tab.dart';
import 'tabs/songs_tab.dart';

/// Bottom navigation on phones, navigation rail on tablets/foldables (§7),
/// with the Mini Player ⇄ Now Playing widget docked above it (§6.3).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _destinations = [
    (icon: Icons.music_note_outlined, selected: Icons.music_note, label: 'Songs'),
    (icon: Icons.album_outlined, selected: Icons.album, label: 'Albums'),
    (
      icon: Icons.playlist_play_outlined,
      selected: Icons.playlist_play,
      label: 'Playlists'
    ),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Artists'),
    (icon: Icons.category_outlined, selected: Icons.category, label: 'Genres'),
  ];

  Widget get _body => switch (_tab) {
        0 => const SongsTab(),
        1 => const AlbumsTab(),
        2 => const PlaylistsTab(),
        3 => const ArtistsTab(),
        _ => const GenresTab(),
      };

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final player = context.watch<PlayerState>();
    final wide = MediaQuery.sizeOf(context).width >= 640;

    if (library.permissionDenied) return const _PermissionScreen();

    final content = wide
        ? Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Builder(
                    builder: (c) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(c).openDrawer(),
                    ),
                  ),
                ),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _body),
            ],
          )
        : _body;

    return Scaffold(
      drawer: const LibraryDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: content),
          // Mini Player / Now Playing morph, plus the bottom bar it slides away.
          PlayerContainer(
            hasTrack: player.hasTrack,
            bottomBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: d.label,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Music access needed',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Allow access to audio files so your library can be scanned.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<LibraryState>().load(),
                child: const Text('Grant access'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
