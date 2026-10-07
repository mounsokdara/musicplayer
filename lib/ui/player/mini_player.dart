import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';
import '../widgets/song_artwork.dart';

/// Collapsed state of the player: thumbnail → title/artist → controls, with a
/// thin progress bar along the bottom edge (§6.3).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SongArtwork(id: song.id, size: 46, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScrollingText(
                        text: song.title,
                        style: Theme.of(context).textTheme.titleSmall!,
                        height: 20,
                      ),
                      _ScrollingText(
                        text: song.artist,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .copyWith(color: scheme.onSurfaceVariant),
                        height: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: player.previous,
                ),
                IconButton.filled(
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: player.toggle,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.next,
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snap) {
            final total = player.duration.inMilliseconds;
            final pos = (snap.data ?? Duration.zero).inMilliseconds;
            return LinearProgressIndicator(
              value: total == 0 ? 0 : (pos / total).clamp(0.0, 1.0),
              minHeight: 2.5,
              backgroundColor: scheme.surfaceContainerHighest,
            );
          },
        ),
      ],
    );
  }
}

/// Marquee-scrolls instead of truncating awkwardly (§6.3).
class _ScrollingText extends StatelessWidget {
  const _ScrollingText({
    required this.text,
    required this.style,
    required this.height,
  });

  final String text;
  final TextStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          if (painter.width <= box.maxWidth) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(text, style: style, maxLines: 1),
            );
          }
          return Marquee(
            text: '$text   ',
            style: style,
            velocity: 26,
            blankSpace: 40,
            pauseAfterRound: const Duration(seconds: 2),
            startPadding: 0,
          );
        },
      ),
    );
  }
}
