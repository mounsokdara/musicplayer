import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_state.dart';
import 'mini_player.dart';
import 'now_playing.dart';

/// The Mini Player and Now Playing are ONE widget morphing between two states
/// (§6.3). [_expansion] drives everything: sheet height, corner radius,
/// mini-player fade, and the bottom navigation bar sliding out of view.
class PlayerContainer extends StatefulWidget {
  const PlayerContainer({super.key, required this.hasTrack, this.bottomBar});

  final bool hasTrack;
  final Widget? bottomBar;

  @override
  State<PlayerContainer> createState() => _PlayerContainerState();
}

class _PlayerContainerState extends State<PlayerContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  static const double _miniHeight = 66;
  double _screenHeight = 800;
  double _navBarHeight = 80;

  double get _expansion => _controller.value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void expand() => _controller.animateTo(1, curve: Curves.easeOutCubic);
  void collapse() => _controller.animateTo(0, curve: Curves.easeOutCubic);

  void _onDragUpdate(DragUpdateDetails d) {
    final travel = _screenHeight - _miniHeight;
    _controller.value = (_controller.value - d.primaryDelta! / travel)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (v < -180) {
      expand();
    } else if (v > 180) {
      // Drag down from the collapsed mini player stops playback (§6.3).
      if (_expansion < 0.02) {
        context.read<PlayerState>().stopPlayback();
      } else {
        collapse();
      }
    } else {
      _expansion > 0.4 ? expand() : collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    _screenHeight = MediaQuery.sizeOf(context).height;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _expansion;
        final height =
            _miniHeight + (_screenHeight - _miniHeight) * t;

        return Stack(
          children: [
            // Bottom navigation slides down as the player expands.
            if (widget.bottomBar != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: -_navBarHeight * t,
                child: IgnorePointer(
                  ignoring: t > 0.5,
                  child: Opacity(
                    opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                    child: _MeasureHeight(
                      onHeight: (h) => _navBarHeight = h,
                      child: widget.bottomBar!,
                    ),
                  ),
                ),
              ),
            if (widget.hasTrack)
              Positioned(
                left: 0,
                right: 0,
                bottom: (widget.bottomBar == null ? 0 : _navBarHeight) * (1 - t),
                height: height,
                child: GestureDetector(
                  onTap: t < 0.5 ? expand : null,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  // Horizontal drags skip tracks while collapsed (§6.3).
                  onHorizontalDragEnd: t < 0.5
                      ? (d) {
                          final vx = d.velocity.pixelsPerSecond.dx;
                          if (vx < -120) {
                            player.next();
                          } else if (vx > 120) {
                            player.previous();
                          }
                        }
                      : null,
                  child: Material(
                    elevation: 3,
                    color: Color.lerp(
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                      player.artworkColor,
                      t * 0.35,
                    ),
                    // Rounded top corners in both states (§6.3).
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (t < 0.999)
                          Opacity(
                            opacity: (1 - t * 2).clamp(0.0, 1.0),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                height: _miniHeight,
                                child: const MiniPlayer(),
                              ),
                            ),
                          ),
                        if (t > 0.001)
                          Opacity(
                            opacity: ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                            child: NowPlaying(onCollapse: collapse),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MeasureHeight extends StatelessWidget {
  const _MeasureHeight({required this.child, required this.onHeight});

  final Widget child;
  final ValueChanged<double> onHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) onHeight(box.size.height);
        });
        return child;
      },
    );
  }
}
