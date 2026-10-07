import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../state/player_state.dart';
import '../sheets/song_sheet.dart';

/// Playing Queue as a full screen, opened from the drawer (§4).
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playing Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear queue',
            onPressed: player.clearQueue,
          ),
        ],
      ),
      body: player.queue.isEmpty
          ? const Center(child: Text('Queue is empty'))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: player.queue.length,
              onReorder: player.reorderQueue,
              itemBuilder: (context, i) {
                final Song song = player.queue[i];
                return Material(
                  key: ValueKey('q-${song.id}-$i'),
                  color: i == player.index
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
                    subtitle: Text(song.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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
    );
  }
}
