import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bar-graph audio visualizer overlaid on the playing row's thumbnail (§6.2).
///
/// Drawn with a single ticker-driven [CustomPaint] so list scrolling stays
/// jank-free: no per-frame widget rebuilds, no layout work.
class BarVisualizer extends StatefulWidget {
  const BarVisualizer({
    super.key,
    required this.playing,
    this.bars = 4,
    this.color,
  });

  final bool playing;
  final int bars;
  final Color? color;

  @override
  State<BarVisualizer> createState() => _BarVisualizerState();
}

class _BarVisualizerState extends State<BarVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(BarVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _BarPainter(_c.value, widget.bars, color),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.t, this.bars, this.color);

  final double t;
  final int bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final gap = size.width * 0.08;
    final barWidth = (size.width * 0.6 - gap * (bars - 1)) / bars;
    final left = (size.width - (barWidth * bars + gap * (bars - 1))) / 2;
    final maxHeight = size.height * 0.6;

    for (var i = 0; i < bars; i++) {
      final phase = t * 2 * math.pi + i * math.pi / 2.2;
      final h = maxHeight * (0.25 + 0.75 * (0.5 + 0.5 * math.sin(phase)).abs());
      final x = left + i * (barWidth + gap);
      final y = size.height / 2 + maxHeight / 2 - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.t != t || old.color != color;
}
