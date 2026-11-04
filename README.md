# Flutter Android Music Player

Local music player for Android, Material Design 3.

## Before you build

1. Replace the package id `com.mounsokdara.musicplayer` with your own GitHub
   username (all lowercase) in:
   - `android/app/build.gradle` (`namespace`, `applicationId`)
   - `android/app/src/main/AndroidManifest.xml` (only if you reference it)
   - `android/app/src/main/kotlin/com/mounsokdara/musicplayer/MainActivity.kt`
     (package line + folder path)
2. `flutter pub get`
3. `flutter run` on a device with music on it (emulators usually have none).

## Version

The app is always **v1.0.0** (`pubspec.yaml` and the release workflow are pinned
to it; every CI run updates the single `v1.0.0` release).

## Storage permissions

The app requests **All files access** (`MANAGE_EXTERNAL_STORAGE`) so it can
read, write, rename and delete any file without per-file prompts, plus the
usual media permissions as a fallback:

- Android 11+: All files access (granted on the system settings page).
- Android 13+: `READ_MEDIA_AUDIO`; Android 11–12: `READ_EXTERNAL_STORAGE`;
  Android ≤10: `READ_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE`.

Note: Google Play restricts `MANAGE_EXTERNAL_STORAGE`; this build targets
sideloading.

## Structure

```
lib/
  main.dart                  app bootstrap, M3 theme, dynamic color
  theme.dart                 Material 3 color schemes + text theme
  models/                    song/album/playlist/lyrics models
  services/
    audio_handler.dart       audio_service + just_audio background handler
    media_library.dart       MediaStore scanning via on_audio_query
    permissions.dart         permission flow described above
    lyrics/smi_parser.dart   SAMI (.smi) synced-lyrics parser
    settings_service.dart    persisted settings
  state/
    player_state.dart        queue, repeat, shuffle, favorites, now playing
    library_state.dart       lists, sorting, grid density
  ui/
    home_shell.dart          bottom nav / navigation rail + drawer + mini player
    tabs/                    songs, albums, playlists, artists, genres
    player/                  mini player ⇄ now playing morph, queue, lyrics
    sheets/                  sort sheet, song sheet, playlist sheet, now-playing menu
    settings/                settings screens
    widgets/                 visualizer, fast-scroll list, thumbnails
android/
  app/src/main/AndroidManifest.xml   permissions, media session, intents, widgets
  .../MusicWidgetProvider.kt         small + medium home-screen widgets
```

## Build order used here

Phases 1–5 of the spec are implemented in Dart. Phase 6 (intent opening,
floating mini player, home-screen widgets) has the Android plumbing and Dart
entry points in place. Test on a real device before publishing.

## APK

`flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

## Features added from the BoomingMusic feature list

Written from scratch for this project (BoomingMusic itself is GPL-3.0 and no
code was copied from it):

- Lyrics: LRC, word-by-word (enhanced LRC), TTML and SAMI; dual-language
  translations; automatic download from LRCLIB; built-in lyrics editor with a
  "insert timestamp" helper
- Smart playlists: History, Most played, Recently played, Recently added
- Scrobbling to Last.fm and ListenBrainz with an offline retry queue
- AutoEq import (ParametricEQ / GraphicEQ text) mapped onto the device
  equalizer bands, plus saved equalizer profiles
- Artist images (Deezer) with on-device caching
- Folder blacklist and whitelist, persisted
- Android Auto media browsing (Songs, Favorites, Most played, History,
  Recently added)
- Fade in/out on play/pause and ReplayGain (attenuation only)
