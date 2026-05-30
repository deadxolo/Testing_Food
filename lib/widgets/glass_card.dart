import 'dart:ui';

import 'package:flutter/material.dart';

/// Drop-in replacement for [Card] with a real `BackdropFilter` blur, so the
/// surface actually looks like frosted glass on top of a colourful backdrop.
///
/// API mirrors `Card(child: ...)`. Most existing call sites just need
/// `Card(` → `GlassCard(`.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.color,
    this.borderColor,
    this.borderRadius = 20,
    this.blurSigma = 14,
    this.elevation = false,
  });

  final Widget? child;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final double blurSigma;

  /// If true, draws a faint drop shadow under the card. Off by default — most
  /// glass surfaces look cleaner without one.
  final bool elevation;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: elevation
          ? BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            )
          : const BoxDecoration(),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.42),
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
