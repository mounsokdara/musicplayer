import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../library_filters_screen.dart';
import 'scrobble_settings.dart';

/// Settings sections per §6.9. Add new sections to [_sections].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          for (final s in _sections)
            ListTile(
              leading: Icon(s.icon),
              title: Text(s.title),
              subtitle: Text(s.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsSection(
                    title: s.title,
                    builder: s.builder,
                  ),
                ),
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
  const _Section(this.icon, this.title, this.subtitle, this.builder);
  final IconData icon;
  final String title;
  final String subtitle;
  final SectionBuilder builder;
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
      body: ListView(children: builder(context, settings)),
    );
  }
}

final _sections = <_Section>[
  _Section(
    Icons.palette_outlined,
    'Themes & Colors',
    'Theme, accent color, light/dark/auto',
    (context, s) => [
      ListTile(
        title: const Text('Theme'),
        subtitle: Text(switch (s.themeMode) {
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
          ThemeMode.system => 'Follow system',
        }),
        onTap: () => showModalBottomSheet(
          context: context,
          builder: (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: mode,
                    groupValue: s.themeMode,
                    title: Text(switch (mode) {
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                      ThemeMode.system => 'Follow system',
                    }),
                    onChanged: (v) {
                      if (v != null) s.themeMode = v;
                      Navigator.pop(sheet);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      SwitchListTile(
        title: const Text('Use wallpaper colors'),
        subtitle: const Text('Material You dynamic color'),
        value: s.useDynamicColor,
        onChanged: (v) => s.useDynamicColor = v,
      ),
      ListTile(
        title: const Text('Accent color'),
        trailing: CircleAvatar(backgroundColor: s.accentColor, radius: 14),
        onTap: () => showModalBottomSheet(
          context: context,
          builder: (sheet) => SafeArea(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final c in const [
                  Color(0xFF4A6FA5),
                  Color(0xFF1DB954),
                  Color(0xFFE5533D),
                  Color(0xFFF2A93B),
                  Color(0xFF00897B),
                  Color(0xFF8E44AD),
                ])
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: InkWell(
                      onTap: () {
                        s.accentColor = c;
                        Navigator.pop(sheet);
                      },
                      child: CircleAvatar(backgroundColor: c, radius: 22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
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
