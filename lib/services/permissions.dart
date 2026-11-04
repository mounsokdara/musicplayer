import 'package:permission_handler/permission_handler.dart';

/// Requests media access plus "All files access" (MANAGE_EXTERNAL_STORAGE) so
/// the app can read, write, rename and delete any file without per-file prompts.
class MediaPermissions {
  /// Media access needed to list the library. Never opens the all-files
  /// settings page, so it always completes quickly.
  ///
  /// The media permission itself is always required: on Android 13+ the
  /// system returns an empty list without READ_MEDIA_AUDIO, even when
  /// "All files access" is granted.
  static Future<bool> request() async {
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }
    if ((await Permission.audio.request()).isGranted) return true;
    if ((await Permission.storage.request()).isGranted) return true;
    return false;
  }

  /// All files access (Android 11+). Opens the system settings page; call it
  /// without awaiting it from the loading path.
  static Future<void> requestAllFilesAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return;
    await Permission.manageExternalStorage.request();
  }

  static Future<bool> get hasAllFilesAccess =>
      Permission.manageExternalStorage.isGranted;

  static Future<bool> get isGranted async =>
      await Permission.manageExternalStorage.isGranted ||
      await Permission.audio.isGranted ||
      await Permission.storage.isGranted;

  static Future<bool> get isPermanentlyDenied async =>
      await Permission.manageExternalStorage.isPermanentlyDenied &&
      await Permission.audio.isPermanentlyDenied &&
      await Permission.storage.isPermanentlyDenied;

  static Future<void> openSettings() => openAppSettings();

  /// Notification permission is needed on Android 13+ for the media
  /// notification / lockscreen controls.
  static Future<void> requestNotifications() =>
      Permission.notification.request();
}
