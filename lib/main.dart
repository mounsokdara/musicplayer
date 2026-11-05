import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/audio_handler.dart';
import 'services/auto_browser.dart';
import 'services/media_library.dart';
import 'services/play_stats.dart';
import 'services/scrobbler.dart';
import 'services/settings_service.dart';
import 'state/library_state.dart';
import 'state/player_state.dart';
import 'theme.dart';
import 'ui/home_shell.dart';

late MusicAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    audioHandler = await initAudioService().timeout(
      const Duration(seconds: 15),
    );
    final settings = await SettingsService.load();
    final stats = await PlayStats.load();
    final scrobbler = await Scrobbler.load();
    final library = LibraryState(MediaLibrary());
    final player = PlayerState(
      audioHandler,
      stats: stats,
      scrobbler: scrobbler,
      settings: settings,
    );

    audioHandler.fadeEnabled = settings.fadeAudio;
    library.setMinTrackSeconds(settings.minTrackSeconds);
    settings.addListener(() {
      audioHandler.fadeEnabled = settings.fadeAudio;
      library.setMinTrackSeconds(settings.minTrackSeconds);
    });

    AutoBrowser(
      handler: audioHandler,
      library: library,
      stats: stats,
      player: player,
      settings: settings,
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider.value(value: scrobbler),
        ],
        child: const MusicApp(),
      ),
    );

    library.load().then((_) => player.restoreSession(library.songs));
  } catch (e, st) {
    runApp(_StartupError(error: '$e\n\n$st'));
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ),
      ),
    );
  }
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Music',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(
          brightness: Brightness.light,
          settings: settings,
          dynamicScheme: lightDynamic,
        ),
        darkTheme: AppTheme.build(
          brightness: Brightness.dark,
          settings: settings,
          dynamicScheme: darkDynamic,
        ),
        themeMode: settings.themeMode,
        home: const HomeShell(),
      ),
    );
  }
}
