import 'package:flutter/material.dart';

/// Bottom navigation bar with a fixed, predictable layout: icon pill + label
/// are packed together at the top of a 64dp row, and the system inset is added
/// below as plain padding (no stray empty space above the icons).
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<({IconData icon, IconData selected, String label})> destinations;

  static const double barHeight = 64;

  /// Total height including the system bottom inset.
  static double heightOf(BuildContext context) =>
      barHeight + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => onSelected(i),
                    radius: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 28,
                          decoration: BoxDecoration(
                            color: i == selectedIndex
                                ? scheme.secondaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            i == selectedIndex
                                ? destinations[i].selected
                                : destinations[i].icon,
                            size: 22,
                            color: i == selectedIndex
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          destinations[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == selectedIndex
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
