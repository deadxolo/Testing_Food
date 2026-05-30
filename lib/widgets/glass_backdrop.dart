import 'package:flutter/material.dart';

import '../theme.dart';

/// The colourful canvas every page sits on. Renders a bold gradient with
/// four large saturated "blobs" — what the frosted glass cards above will
/// blur. Wrap the app's home with this once (via [MaterialApp.builder]).
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vibrant base gradient — diagonal sweep with multiple stops so the
        // glass picks up obvious colour shifts as you scroll.
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.45, 0.85, 1.0],
                colors: [
                  Color(0xFFD7F0DC), // mint
                  Color(0xFFF0F5DC), // celadon
                  Color(0xFFFFE3C8), // peach
                  Color(0xFFFFD0DA), // soft pink
                ],
              ),
            ),
          ),
        ),
        // Big saturated blobs at higher alpha so the glass card actually
        // shows colour bleed when stacked over them.
        Positioned(
          top: -140,
          right: -110,
          child: _Blob(
              size: 420, color: AppColors.seed.withValues(alpha: 0.55)),
        ),
        Positioned(
          bottom: -180,
          left: -140,
          child: _Blob(
              size: 460, color: const Color(0xFFF6A609).withValues(alpha: 0.45)),
        ),
        Positioned(
          top: 220,
          left: -100,
          child: _Blob(
              size: 300, color: const Color(0xFF7CB342).withValues(alpha: 0.40)),
        ),
        Positioned(
          bottom: 260,
          right: -110,
          child: _Blob(
              size: 320, color: const Color(0xFFE91E63).withValues(alpha: 0.30)),
        ),
        Positioned(
          top: 480,
          left: 80,
          child: _Blob(
              size: 240, color: const Color(0xFF26C6DA).withValues(alpha: 0.30)),
        ),
        // App content.
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

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
