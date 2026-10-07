import 'package:permission_handler/permission_handler.dart';

/// Granular-media-permission flow (see README for the documented rationale).
///
/// Android 13+  -> READ_MEDIA_AUDIO
/// Android 11-12 -> READ_EXTERNAL_STORAGE
/// Android <=10  -> READ + WRITE_EXTERNAL_STORAGE
///
/// Deletes and renames outside our own scope are performed through the system
/// delete request / SAF prompt, so no all-files access is required.
class MediaPermissions {
  static Future<bool> request() async {
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;

    // Older Android versions have no READ_MEDIA_AUDIO.
    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    return false;
  }

  static Future<bool> get isGranted async =>
      await Permission.audio.isGranted || await Permission.storage.isGranted;

  static Future<bool> get isPermanentlyDenied async =>
      await Permission.audio.isPermanentlyDenied &&
      await Permission.storage.isPermanentlyDenied;

  static Future<void> openSettings() => openAppSettings();

  /// Notification permission is needed on Android 13+ for the media
  /// notification / lockscreen controls.
  static Future<void> requestNotifications() =>
      Permission.notification.request();
}
