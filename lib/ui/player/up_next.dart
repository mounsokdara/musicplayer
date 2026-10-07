import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../state/player_state.dart';
import '../sheets/song_sheet.dart';
import 'mini_player.dart';

/// Up Next, revealed by swiping up on the Now Playing action bar (§6.5).
/// Rows carry a 3-dot menu on the left and a drag handle on the right; the
/// Mini Player stays pinned to the top while the queue is open.
class UpNextSheet extends StatelessWidget {
  const UpNextSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => const UpNextSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Mini Player pinned to the top of the queue view.
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const SizedBox(height: 66, child: MiniPlayer()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Text('Up next', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: player.clearQueue,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              buildDefaultDragHandles: false,
              itemCount: player.queue.length,
              onReorder: player.reorderQueue,
              itemBuilder: (context, i) {
                final Song song = player.queue[i];
                final active = i == player.index;
                return Material(
                  key: ValueKey('${song.id}-$i'),
                  color: active
                      ? scheme.secondaryContainer.withValues(alpha: 0.6)
                      : Colors.transparent,
                  child: ListTile(
                    onTap: () => player.playQueueItem(i),
                    leading: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showSongSheet(context, song),
                    ),
                    title: Text(song.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${song.artist} • ${formatDuration(song.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
