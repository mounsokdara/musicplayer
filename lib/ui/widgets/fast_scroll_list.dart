import 'package:flutter/material.dart';

/// A–Z draggable index attached to the scrollbar for long lists (§5).
class FastScrollList extends StatefulWidget {
  const FastScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.labelAt,
    this.itemExtent = 64,
    this.padding,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// First sort-relevant character of the item at an index.
  final String Function(int index) labelAt;
  final double itemExtent;
  final EdgeInsets? padding;

  @override
  State<FastScrollList> createState() => _FastScrollListState();
}

class _FastScrollListState extends State<FastScrollList> {
  final ScrollController _controller = ScrollController();
  String? _bubble;

  static const _alphabet = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToLetter(String letter) {
    for (var i = 0; i < widget.itemCount; i++) {
      final l = widget.labelAt(i).toUpperCase();
      final normalized = RegExp(r'[A-Z]').hasMatch(l) ? l : '#';
      if (normalized == letter) {
        _controller.jumpTo(
          (i * widget.itemExtent)
              .clamp(0, _controller.position.maxScrollExtent)
              .toDouble(),
        );
        return;
      }
    }
  }

  void _handleDrag(Offset local, double height) {
    final i = (local.dy / height * _alphabet.length)
        .floor()
        .clamp(0, _alphabet.length - 1);
    final letter = _alphabet[i];
    if (letter != _bubble) {
      setState(() => _bubble = letter);
      _jumpToLetter(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showIndex = widget.itemCount > 30;

    return Stack(
      children: [
        Scrollbar(
          controller: _controller,
          child: ListView.builder(
            controller: _controller,
            padding: widget.padding,
            itemExtent: widget.itemExtent,
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          ),
        ),
        if (showIndex)
          Positioned(
            top: 8,
            bottom: 8,
            right: 0,
            width: 28,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (d) =>
                    _handleDrag(d.localPosition, box.maxHeight),
                onVerticalDragUpdate: (d) =>
                    _handleDrag(d.localPosition, box.maxHeight),
                onVerticalDragEnd: (_) => setState(() => _bubble = null),
                onTapDown: (d) => _handleDrag(d.localPosition, box.maxHeight),
                onTapUp: (_) => setState(() => _bubble = null),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final letter in _alphabet.split(''))
                      Text(
                        letter,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _bubble == letter
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              fontWeight: _bubble == letter
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (_bubble != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Material(
                color: scheme.primaryContainer,
                shape: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 56,
                  child: Center(
                    child: Text(
                      _bubble!,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
