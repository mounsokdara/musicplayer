import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/lyrics/lyrics.dart';
import '../../services/settings_service.dart';
import '../../state/player_state.dart';
import 'lyrics_editor.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scroll = ScrollController();
  double _extent = 64;
  int _active = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _centerOn(int index) {
    if (!_scroll.hasClients || index < 0) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (index * _extent - viewport / 2 + _extent / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final settings = context.watch<SettingsService>();
    final lyrics = player.lyrics;
    final scheme = Theme.of(context).colorScheme;
    final song = player.current;

    if (player.lyricsBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lyrics == null || lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No lyrics for this track'),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: song == null
                  ? null
                  : () async {
                      final ok = await player.downloadLyrics(song);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No lyrics found online')),
                        );
                      }
                    },
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Download lyrics'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: song == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LyricsEditorScreen(song: song),
                        ),
                      ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Write lyrics'),
            ),
          ],
        ),
      );
    }

    final showTranslation = settings.showLyricsTranslation && lyrics.hasTranslation;
    final lines = lyrics.lines;

    if (!lyrics.synced) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: lines.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            lines[i].text,
            style: TextStyle(fontSize: 17, color: scheme.onSurface),
          ),
        ),
      );
    }

    _extent = showTranslation ? 92 : 64;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final position = snap.data ?? Duration.zero;
        final index = lyrics.indexAt(position);
        if (index != _active) {
          _active = index;
          WidgetsBinding.instance.addPostFrameCallback((_) => _centerOn(index));
        }

        return ListView.builder(
          controller: _scroll,
          itemExtent: _extent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final line = lines[i];
            final isActive = i == index;
            return InkWell(
              onTap: () => player.seek(line.start),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _LineView(
                  line: line,
                  active: isActive,
                  position: position,
                  showTranslation: showTranslation,
                  scheme: scheme,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LineView extends StatelessWidget {
  const _LineView({
    required this.line,
    required this.active,
    required this.position,
    required this.showTranslation,
    required this.scheme,
  });

  final LyricLine line;
  final bool active;
  final Duration position;
  final bool showTranslation;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final dim = scheme.onSurface.withValues(alpha: 0.55);
    final baseStyle = TextStyle(
      fontSize: active ? 20 : 16,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active ? scheme.primary : dim,
    );

    final Widget main;
    if (active && line.hasWords) {
      main = Text.rich(
        TextSpan(
          children: [
            for (final w in line.words)
              TextSpan(
                text: w.text,
                style: TextStyle(
                  color: position >= w.start ? scheme.primary : dim,
                ),
              ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    } else {
      main = Text(
        line.isBlank ? '♪' : line.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        if (showTranslation && line.hasTranslation)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line.translation!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: active ? 0.75 : 0.4),
              ),
            ),
          ),
      ],
    );
  }
}
