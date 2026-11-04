import 'package:permission_handler/permission_handler.dart';

/// Requests media access plus "All files access" (MANAGE_EXTERNAL_STORAGE) so
/// the app can read, write, rename and delete any file without per-file prompts.
class MediaPermissions {
  static Future<bool> request() async {
    // All files access (Android 11+). Opens the system settings page.
    var allFiles = await Permission.manageExternalStorage.status;
    if (!allFiles.isGranted) {
      allFiles = await Permission.manageExternalStorage.request();
    }

    final audio = await Permission.audio.request();
    final storage =
        audio.isGranted ? audio : await Permission.storage.request();

    return allFiles.isGranted || audio.isGranted || storage.isGranted;
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
