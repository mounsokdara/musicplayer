import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../about/about_info.dart';
import '../about/about_page.dart';
import '../library_filters_screen.dart';
import 'scrobble_settings.dart';
import 'theme_settings.dart';

/// Settings hub (same layout as the Video Player app): pinned app bar and
/// icon-avatar category rows. Add new sections to [_sections].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    Widget avatar(IconData icon) => CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          child: Icon(icon),
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Settings')),
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottom + 24),
            sliver: SliverList.list(
              children: [
                for (final s in _sections)
                  ListTile(
                    leading: avatar(s.icon),
                    title: Text(s.title),
                    subtitle: Text(s.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            s.page?.call() ??
                            SettingsSection(title: s.title, builder: s.builder),
                      ),
                    ),
                  ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: avatar(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: Text('${AboutInfo.name} v${AboutInfo.displayVersion}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef SectionBuilder = List<Widget> Function(
    BuildContext context, SettingsService s);

class _Section {
  const _Section(this.icon, this.title, this.subtitle, this.builder,
      {this.page});
  final IconData icon;
  final String title;
  final String subtitle;
  final SectionBuilder builder;

  /// A dedicated page instead of the generic list of [builder] widgets.
  final Widget Function()? page;
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.builder});

  final String title;
  final SectionBuilder builder;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: builder(context, settings),
      ),
    );
  }
}

final _sections = <_Section>[
  _Section(
    Icons.palette_outlined,
    'Theme',
    'Light / dark, accent color, pure black',
    (context, s) => const [],
    page: ThemeSettingsPage.new,
  ),
  _Section(
    Icons.play_circle_outline,
    'Now Playing',
    'Controls, display content, lockscreen',
    (context, s) => [
      SwitchListTile(
        title: const Text('Extra controls'),
        subtitle: const Text('Show sleep timer and lyrics shortcuts'),
        value: s.showExtraControls,
        onChanged: (v) => s.showExtraControls = v,
      ),
      SwitchListTile(
        title: const Text('Album art on lockscreen'),
        value: s.albumArtOnLockscreen,
        onChanged: (v) => s.albumArtOnLockscreen = v,
      ),
    ],
  ),
  _Section(
    Icons.library_music_outlined,
    'Library',
    'Multiple artists, filters, navigation',
    (context, s) => [
      SwitchListTile(
        title: const Text('Split multiple artists'),
        subtitle: const Text('Treat "A & B" as two artists'),
        value: s.splitMultipleArtists,
        onChanged: (v) => s.splitMultipleArtists = v,
      ),
      ListTile(
        title: const Text('Folder filters'),
        subtitle: const Text('Blacklist and whitelist folders'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LibraryFiltersScreen()),
        ),
      ),
      ListTile(
        title: const Text('Ignore tracks shorter than'),
        subtitle: Text('${s.minTrackSeconds} seconds'),
        trailing: SizedBox(
          width: 180,
          child: Slider(
            value: s.minTrackSeconds.toDouble(),
            max: 60,
            divisions: 12,
            onChanged: (v) => s.minTrackSeconds = v.round(),
          ),
        ),
      ),
    ],
  ),
  _Section(
    Icons.image_outlined,
    'Images',
    'Caching and metadata download',
    (context, s) => [
      SwitchListTile(
        title: const Text('Cache artwork'),
        value: s.cacheImages,
        onChanged: (v) => s.cacheImages = v,
      ),
      SwitchListTile(
        title: const Text('Download artist images'),
        subtitle: const Text('Fetched from Deezer and cached on the device'),
        value: s.downloadMetadata,
        onChanged: (v) => s.downloadMetadata = v,
      ),
    ],
  ),
  _Section(
    Icons.graphic_eq,
    'Audio',
    'Fade, replay gain, gapless',
    (context, s) => [
      SwitchListTile(
        title: const Text('Fade audio'),
        value: s.fadeAudio,
        onChanged: (v) => s.fadeAudio = v,
      ),
      SwitchListTile(
        title: const Text('Replay gain'),
        subtitle: const Text('Lowers loud tracks using their ReplayGain tags'),
        value: s.replayGain,
        onChanged: (v) => s.replayGain = v,
      ),
      SwitchListTile(
        title: const Text('Gapless playback'),
        value: s.gaplessPlayback,
        onChanged: (v) => s.gaplessPlayback = v,
      ),
    ],
  ),
  _Section(
    Icons.lyrics_outlined,
    'Lyrics',
    'Download, translations',
    (context, s) => [
      SwitchListTile(
        title: const Text('Download lyrics automatically'),
        subtitle: const Text('Fetched from LRCLIB when a track has none'),
        value: s.autoDownloadLyrics,
        onChanged: (v) => s.autoDownloadLyrics = v,
      ),
      SwitchListTile(
        title: const Text('Show translations'),
        subtitle: const Text('Dual-language LRC and TTML lyrics'),
        value: s.showLyricsTranslation,
        onChanged: (v) => s.showLyricsTranslation = v,
      ),
    ],
  ),
  _Section(
    Icons.podcasts,
    'Scrobbling',
    'Last.fm and ListenBrainz',
    (context, s) => [
      ListTile(
        title: const Text('Scrobbling accounts'),
        subtitle: const Text('Sign in to Last.fm or ListenBrainz'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScrobbleSettingsScreen()),
        ),
      ),
    ],
  ),
  _Section(
    Icons.queue_music_outlined,
    'Playlists',
    'Recently added/played, import & export',
    (context, s) => [
      ListTile(
        title: const Text('Recently added window'),
        subtitle: Text('${s.recentlyAddedDays} days'),
        trailing: SizedBox(
          width: 180,
          child: Slider(
            value: s.recentlyAddedDays.toDouble(),
            min: 1,
            max: 90,
            onChanged: (v) => s.recentlyAddedDays = v.round(),
          ),
        ),
      ),
      ListTile(
        title: const Text('Recently played window'),
        subtitle: Text('${s.recentlyPlayedDays} days'),
        trailing: SizedBox(
          width: 180,
          child: Slider(
            value: s.recentlyPlayedDays.toDouble(),
            min: 1,
            max: 90,
            onChanged: (v) => s.recentlyPlayedDays = v.round(),
          ),
        ),
      ),
    ],
  ),
  _Section(
    Icons.backup_outlined,
    'Backup & restore',
    'Copy or paste all settings',
    (context, s) => [
      ListTile(
        title: const Text('Back up settings'),
        subtitle: const Text('Copies settings JSON to the clipboard'),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: s.exportJson()));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings copied to clipboard')),
            );
          }
        },
      ),
      ListTile(
        title: const Text('Restore settings'),
        subtitle: const Text('Reads settings JSON from the clipboard'),
        onTap: () async {
          final text = (await Clipboard.getData('text/plain'))?.text ?? '';
          final ok = await s.importJson(text);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Settings restored' : 'Clipboard has no valid backup'),
              ),
            );
          }
        },
      ),
    ],
  ),
];
