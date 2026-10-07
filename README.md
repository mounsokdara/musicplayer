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

## Storage permission approach (documented choice)

This project uses **granular media permissions**, not
`MANAGE_EXTERNAL_STORAGE`:

- Android 13+ (API 33+): `READ_MEDIA_AUDIO`.
- Android 11–12: `READ_EXTERNAL_STORAGE`.
- Android ≤10: `READ_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE`.

Writes (tag editing, artwork) go through `MediaStore`. Deletes and renames
outside the app's own scope go through the system delete/write request
(`MediaStore.createDeleteRequest`) or a Storage Access Framework prompt, so the
user confirms each destructive action. `MANAGE_EXTERNAL_STORAGE` is left
declared but commented out in the manifest — uncomment it only for sideloaded
builds if you want silent bulk deletes; Play Store review requires a
justification for it.

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
