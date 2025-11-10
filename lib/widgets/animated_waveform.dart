import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedWaveform extends StatefulWidget {
  const AnimatedWaveform({
    super.key,
    required this.amplitude,
    this.barCount = 18,
    this.minBarHeight = 12.0,
    this.maxBarHeight = 42.0,
  });

  final double amplitude;
  final int barCount;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.amplitude > oldWidget.amplitude) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: WaveformPainter(
            amplitude: widget.amplitude,
            animationValue: _animation.value,
            barCount: widget.barCount,
            minBarHeight: widget.minBarHeight,
            maxBarHeight: widget.maxBarHeight,
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.amplitude,
    required this.animationValue,
    required this.barCount,
    required this.minBarHeight,
    required this.maxBarHeight,
  });

  final double amplitude;
  final double animationValue;
  final int barCount;
  final double minBarHeight;
  final double maxBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (barCount * 2 - 1);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFF6F6F), const Color(0xFFFFB4B4)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < barCount; i++) {
      final barHeight = lerpDouble(
        minBarHeight,
        maxBarHeight,
        (amplitude * (1 + i / barCount) * animationValue).clamp(0.0, 1.0),
      )!;
      final x = i * 2 * barWidth;
      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return amplitude != oldDelegate.amplitude ||
        animationValue != oldDelegate.animationValue;
  }
}
