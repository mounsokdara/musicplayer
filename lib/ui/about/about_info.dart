/// Static facts shown on the About page. The app is always v1.0.0.
class AboutInfo {
  AboutInfo._();

  static const name = 'Music Player';
  static const author = 'Moun Sokdara';
  static const displayVersion = '1.0.0';
  static const tagline =
      'Local-only Material 3 music player. Your music never leaves the device.';

  /// Epoch seconds when this APK was built (set by CI via --dart-define).
  static const buildTime = int.fromEnvironment('BUILD_TIME', defaultValue: 0);

  static const githubLogin = 'mounsokdara';
  static const profileUrl = 'https://github.com/$githubLogin';
  static const repoSlug = '$githubLogin/musicplayer';
  static const repoUrl = 'https://github.com/$repoSlug';
  static const releasesUrl = '$repoUrl/releases';
  static const issuesUrl = '$repoUrl/issues';

  static const authorRole = 'Lead Developer';
  static const supportUrl = 'https://github.com/sponsors/$githubLogin';
}
