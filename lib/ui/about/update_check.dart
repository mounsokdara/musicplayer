import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'about_info.dart';
import 'about_widgets.dart';

class _Latest {
  const _Latest({required this.updated, this.apkUrl, required this.pageUrl});
  final DateTime updated;
  final String? apkUrl;
  final String pageUrl;
}

/// The app is always v1.0.0, so "newer" means the published APK was rebuilt
/// after this one (CI stamps BUILD_TIME; the release asset has an update time).
Future<(_Latest?, String?)> _fetchLatest() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/${AboutInfo.repoSlug}/releases/latest'));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'music-player-app');
    final res = await req.close().timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return (null, 'GitHub answered ${res.statusCode}');
    final j = jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    final assets = (j['assets'] as List?) ?? const [];
    Map<String, dynamic>? apk;
    for (final a in assets) {
      if (a is Map<String, dynamic> &&
          '${a['name']}'.toLowerCase().endsWith('.apk')) {
        apk = a;
        break;
      }
    }
    final stamp = (apk?['updated_at'] ?? j['published_at']) as String?;
    final updated = stamp == null ? null : DateTime.tryParse(stamp);
    if (updated == null) return (null, 'No build was found');
    return (
      _Latest(
        updated: updated,
        apkUrl: apk?['browser_download_url'] as String?,
        pageUrl: (j['html_url'] as String?) ?? AboutInfo.releasesUrl,
      ),
      null,
    );
  } catch (e) {
    return (null, '$e');
  } finally {
    client.close(force: true);
  }
}

String _fmt(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

Future<void> checkForUpdate(BuildContext context) async {
  final rootNav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 20),
          Expanded(child: Text('Checking for updates...')),
        ]),
      ),
    ),
  );
  final (latest, error) = await _fetchLatest();
  rootNav.pop();
  if (!context.mounted) return;

  Future<void> info(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );

  if (latest == null) {
    await info('Could not check for updates',
        '${error ?? 'No release was found'}. Check your connection and try again.');
    return;
  }

  final builtAt = AboutInfo.buildTime;
  final newer = builtAt > 0 &&
      latest.updated.millisecondsSinceEpoch ~/ 1000 > builtAt + 15 * 60;

  if (!newer) {
    await info(
      "You're up to date",
      '${AboutInfo.name} v${AboutInfo.displayVersion} is the latest build.\n\n'
      'Latest published: ${_fmt(latest.updated)}',
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Update available'),
      content: Text(
        'A newer build of v${AboutInfo.displayVersion} was published on '
        '${_fmt(latest.updated)}.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            openExternal(latest.apkUrl ?? latest.pageUrl);
          },
          child: Text(latest.apkUrl != null ? 'Download' : 'View release'),
        ),
      ],
    ),
  );
}
