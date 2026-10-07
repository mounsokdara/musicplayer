import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/library_state.dart';

/// Search bar with hamburger (drawer) + cast icon, and the sort bar below it
/// (§6.1). Reused by every library tab.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.sortLabel,
    required this.ascending,
    required this.onSortTap,
    this.onSearchChanged,
    this.trailing,
  });

  final String sortLabel;
  final bool ascending;
  final VoidCallback onSortTap;
  final ValueChanged<String>? onSearchChanged;

  /// Grid-density selector on collection tabs.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SearchBar(
            hintText: 'Search your library',
            onChanged: onSearchChanged,
            leading: Builder(
              builder: (c) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(c).openDrawer(),
              ),
            ),
            trailing: [
              IconButton(
                icon: const Icon(Icons.cast),
                tooltip: 'Cast',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Searching for devices…')),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onSortTap,
                icon: Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                ),
                label: Text(sortLabel),
                style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

/// 1–4 column grid-density selector (§6.7).
class GridDensityButton extends StatelessWidget {
  const GridDensityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    return PopupMenuButton<int>(
      tooltip: 'Grid size',
      icon: const Icon(Icons.grid_view_rounded),
      initialValue: library.gridColumns,
      onSelected: library.setGridColumns,
      itemBuilder: (_) => [
        for (var n = 1; n <= 4; n++)
          PopupMenuItem(value: n, child: Text('$n column${n > 1 ? 's' : ''}')),
      ],
    );
  }
}
