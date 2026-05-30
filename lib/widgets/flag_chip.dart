import 'package:flutter/material.dart';

import '../data/ingredient_flags.dart';

class SeverityStyle {
  final Color fg;
  final Color bg;
  final IconData icon;
  const SeverityStyle(this.fg, this.bg, this.icon);

  static SeverityStyle of(FlagSeverity s) => switch (s) {
        FlagSeverity.bad => const SeverityStyle(
            Color(0xFFB3261E), Color(0xFFFCE9E7), Icons.dangerous_rounded),
        FlagSeverity.caution => const SeverityStyle(
            Color(0xFF8A5A00), Color(0xFFFFF3DC), Icons.warning_amber_rounded),
        FlagSeverity.info => const SeverityStyle(
            Color(0xFF1B6E2E), Color(0xFFE7F4EA), Icons.info_outline_rounded),
      };
}

class FlagChip extends StatelessWidget {
  const FlagChip({super.key, required this.label, required this.severity, this.dense = false});
  final String label;
  final FlagSeverity severity;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final st = SeverityStyle.of(severity);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: dense ? 13 : 15, color: st.fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: st.fg,
                  fontWeight: FontWeight.w600,
                  fontSize: dense ? 11.5 : 13)),
        ],
      ),
    );
  }
}
