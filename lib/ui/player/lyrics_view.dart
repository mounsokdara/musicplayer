import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/lyrics/smi_parser.dart';
import '../../state/player_state.dart';

/// Karaoke-style synced lyrics: highlights the current line and auto-scrolls
/// it to the middle of the view (§6.6).
class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scroll = ScrollController();
  static const double _lineExtent = 44;
  int _active = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _centerOn(int index, int total) {
    if (!_scroll.hasClients || index < 0) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (index * _lineExtent - viewport / 2 + _lineExtent / 2)
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
    final lyrics = player.lyrics;
    final scheme = Theme.of(context).colorScheme;

    if (lyrics == null || lyrics.isEmpty) {
      return const Center(child: Text('No synced lyrics for this track'));
    }
    final lines = lyrics.lines;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final index = lyrics.indexAt(snap.data ?? Duration.zero);
        if (index != _active) {
          _active = index;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _centerOn(index, lines.length),
          );
        }

        return ListView.builder(
          controller: _scroll,
          itemExtent: _lineExtent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final LyricLine line = lines[i];
            final isActive = i == index;
            return Align(
              alignment: Alignment.centerLeft,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: isActive ? 20 : 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.55),
                ),
                child: Text(
                  line.isBlank ? '♪' : line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
