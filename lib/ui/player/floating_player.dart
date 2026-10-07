import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../state/player_state.dart';

/// Lightweight floating player shown when the app is launched by an audio
/// intent from another app (§6.10): title, position slider, pause/resume only.
class FloatingPlayerScreen extends StatelessWidget {
  const FloatingPlayerScreen({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  elevation: 6,
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              iconSize: 32,
                              icon: Icon(player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                              onPressed: player.toggle,
                            ),
                          ],
                        ),
                        StreamBuilder<Duration>(
                          stream: player.positionStream,
                          builder: (context, snap) {
                            final total = player.duration.inMilliseconds;
                            final pos = (snap.data ?? Duration.zero)
                                .inMilliseconds
                                .clamp(0, total == 0 ? 1 : total);
                            return Slider(
                              value: pos.toDouble(),
                              max: total == 0 ? 1 : total.toDouble(),
                              onChanged: (v) => player
                                  .seek(Duration(milliseconds: v.round())),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
