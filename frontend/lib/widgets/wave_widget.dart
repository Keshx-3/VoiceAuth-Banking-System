import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated sine-wave widget used as a decorative header on auth screens.
///
/// Renders a continuously-animating wave at the given [yOffset] from the top.
/// The area **below** the wave is filled with [color] (typically white),
/// creating the illusion of a wavy separator between the coloured header
/// and the form area beneath it.
class WaveWidget extends StatefulWidget {
  final Size size;
  final double yOffset;
  final Color color;

  const WaveWidget({
    super.key,
    required this.size,
    required this.yOffset,
    required this.color,
  });

  @override
  State<WaveWidget> createState() => _WaveWidgetState();
}

class _WaveWidgetState extends State<WaveWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Offset> _wavePoints = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..addListener(() {
        _wavePoints.clear();

        final double waveSpeed = _controller.value * 1080;
        final double fullSphere = _controller.value * math.pi * 2;
        final double normalizer = math.cos(fullSphere);
        const double waveWidth = math.pi / 270;
        const double waveHeight = 20.0;

        for (int i = 0; i <= widget.size.width.toInt(); ++i) {
          double calc = math.sin((waveSpeed - i) * waveWidth);
          _wavePoints.add(
            Offset(
              i.toDouble(),
              calc * waveHeight * normalizer + widget.yOffset,
            ),
          );
        }
      });

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipPath(
          clipper: _WaveClipper(waveList: _wavePoints),
          child: Container(
            width: widget.size.width,
            height: widget.size.height,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Custom clipper that traces the wave polygon along the top edge and
/// fills the remaining area below it.
class _WaveClipper extends CustomClipper<Path> {
  final List<Offset> waveList;
  _WaveClipper({required this.waveList});

  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.addPolygon(waveList, false);
    path.lineTo(size.width, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
