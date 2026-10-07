import 'package:flutter/material.dart';

/// Sort bottom sheet (§5): tapping the active field reverses the order.
Future<void> showSortSheet<T>({
  required BuildContext context,
  required List<T> fields,
  required String Function(T) labelOf,
  required T active,
  required bool ascending,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in fields)
                  ListTile(
                    title: Text(labelOf(f)),
                    selected: f == active,
                    leading: Icon(f == active
                        ? (ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.sort),
                    onTap: () {
                      onSelected(f);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
