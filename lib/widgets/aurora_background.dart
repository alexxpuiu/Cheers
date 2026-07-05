import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A calm, slowly drifting gradient backdrop with two soft "aurora"
/// blobs behind the base gradient. Everything else in the app sits on
/// top of this — glass panels blur *this* backdrop.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
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
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.background),
            ),
            Positioned(
              left: 120 + math.sin(t) * 60,
              top: 80 + math.cos(t * 0.7) * 40,
              child: _Blob(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.55),
                size: 360,
              ),
            ),
            Positioned(
              right: -60 + math.cos(t * 0.9) * 40,
              top: 220 + math.sin(t * 1.1) * 60,
              child: _Blob(
                color: const Color(0xFFFF6B8A).withValues(alpha: 0.45),
                size: 320,
              ),
            ),
            Positioned(
              left: -40 + math.sin(t * 1.2) * 30,
              bottom: 60 + math.cos(t) * 40,
              child: _Blob(
                color: const Color(0xFFFFB86B).withValues(alpha: 0.35),
                size: 280,
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
