import 'package:flutter/material.dart';

/// Read-only star rating supporting half stars (0.5 steps).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.size = 22,
    this.color = const Color(0xFFF6A609),
    this.showValue = false,
  });

  final double value; // 0..5
  final double size;
  final Color color;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      final IconData icon;
      if (value >= i) {
        icon = Icons.star_rounded;
      } else if (value >= i - 0.5) {
        icon = Icons.star_half_rounded;
      } else {
        icon = Icons.star_outline_rounded;
      }
      children.add(Icon(icon, size: size, color: color));
    }
    if (showValue) {
      children
        ..add(SizedBox(width: size * 0.3))
        ..add(Text(value.toStringAsFixed(1),
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: size * 0.8, color: color)));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
