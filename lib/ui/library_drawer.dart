import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_state.dart';
import 'equalizer_screen.dart';
import 'folders_screen.dart';
import 'player/queue_screen.dart';
import 'about/about_info.dart';
import 'about/about_page.dart';
import 'settings/settings_screen.dart';

/// Side drawer opened from the search bar's hamburger icon (§4).
class LibraryDrawer extends StatelessWidget {
  const LibraryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryState>();

    void go(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    return NavigationDrawer(
      selectedIndex: 0,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            Navigator.pop(context);
          case 1:
            go(const FoldersScreen());
          case 2:
            go(const QueueScreen());
          case 3:
            go(const EqualizerScreen());
          case 4:
            Navigator.pop(context);
            library.rescan();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Scanning media…')),
            );
          case 5:
            go(const SettingsScreen());
          case 6:
            go(const AboutPage());
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AboutInfo.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('v${AboutInfo.displayVersion}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.library_music_outlined),
          label: Text('Library'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.folder_outlined),
          label: Text('Folders'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.queue_music_outlined),
          label: Text('Playing Queue'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.equalizer_outlined),
          label: Text('Equalizer'),
        ),
        const Divider(indent: 28, endIndent: 28),
        const NavigationDrawerDestination(
          icon: Icon(Icons.refresh),
          label: Text('Scan Media'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          label: Text('Settings'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.info_outline),
          label: Text('About'),
        ),
      ],
    );
  }
}
