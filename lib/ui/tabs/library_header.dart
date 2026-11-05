import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/library_state.dart';

/// Search bar with hamburger (drawer) + clear button, and the sort bar below
/// it with an optional item count (§6.1). Reused by every library tab.
class LibraryHeader extends StatefulWidget {
  const LibraryHeader({
    super.key,
    required this.sortLabel,
    required this.ascending,
    required this.onSortTap,
    this.onSearchChanged,
    this.trailing,
    this.countLabel,
  });

  final String sortLabel;
  final bool ascending;
  final VoidCallback onSortTap;
  final ValueChanged<String>? onSearchChanged;

  /// Grid-density selector on collection tabs.
  final Widget? trailing;

  /// e.g. "1,204 songs", shown next to the sort button.
  final String? countLabel;

  @override
  State<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<LibraryHeader> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SearchBar(
            controller: _controller,
            hintText: 'Search your library',
            onChanged: widget.onSearchChanged,
            leading: Builder(
              builder: (c) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(c).openDrawer(),
              ),
            ),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged?.call('');
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: widget.onSortTap,
                icon: Icon(
                  widget.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                ),
                label: Text(widget.sortLabel),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (widget.countLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.countLabel!,
                    style: text.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (widget.trailing != null) widget.trailing!,
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
