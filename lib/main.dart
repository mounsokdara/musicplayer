import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/audio_handler.dart';
import 'services/media_library.dart';
import 'services/settings_service.dart';
import 'state/library_state.dart';
import 'state/player_state.dart';
import 'theme.dart';
import 'ui/home_shell.dart';

late MusicAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await initAudioService();
  final settings = await SettingsService.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) => LibraryState(MediaLibrary())..load(),
        ),
        ChangeNotifierProvider(create: (_) => PlayerState(audioHandler)),
      ],
      child: const MusicApp(),
    ),
  );
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
        theme: AppTheme.light(
          settings.useDynamicColor ? lightDynamic : null,
          settings.accentColor,
        ),
        darkTheme: AppTheme.dark(
          settings.useDynamicColor ? darkDynamic : null,
          settings.accentColor,
        ),
        themeMode: settings.themeMode,
        home: const HomeShell(),
      ),
    );
  }
}
