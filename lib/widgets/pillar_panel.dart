import 'package:flutter/material.dart';

import '../models/health_report.dart';
import '../theme.dart';
import 'glass_panel.dart';

/// Renders the four transparent sub-scores that make up the overall rating.
/// Each pillar gets a label, a colour-coded score bar (0–100), and a one-
/// line takeaway. Tap-target is intentionally wide so users can read the
/// "why" without diving into the breakdown below.
class PillarPanel extends StatelessWidget {
  const PillarPanel({super.key, required this.pillars});
  final PillarScores pillars;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.tune_rounded, color: AppColors.seed),
              const SizedBox(width: 8),
              Text('Four things we check',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _OverallChip(value: pillars.overall),
            ]),
            const SizedBox(height: 10),
            _PillarRow(
              icon: Icons.bar_chart_rounded,
              label: 'Nutrition',
              hint: 'Bad vs. good nutrients, judged within category',
              score: pillars.nutrition,
              note: pillars.nutritionNote,
              weight: PillarScores.wNutrition,
            ),
            _PillarRow(
              icon: Icons.spa_rounded,
              label: 'Ingredients',
              hint: 'Whole / real ingredients vs. refined fillers',
              score: pillars.ingredient,
              note: pillars.ingredientNote,
              weight: PillarScores.wIngredient,
            ),
            _PillarRow(
              icon: Icons.precision_manufacturing_rounded,
              label: 'Processing',
              hint: 'NOVA scale — closer to nature is better',
              score: pillars.processing,
              note: pillars.processingNote,
              weight: PillarScores.wProcessing,
            ),
            _PillarRow(
              icon: Icons.science_rounded,
              label: 'Additives',
              hint: 'Only globally-flagged additives reduce the score',
              score: pillars.additive,
              note: pillars.additiveNote,
              weight: PillarScores.wAdditive,
            ),
          ],
        ),
    );
  }
}

class _OverallChip extends StatelessWidget {
  const _OverallChip({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.forPercent(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('OVERALL',
            style: TextStyle(
                color: c.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 1.0)),
        const SizedBox(width: 6),
        Text('$value',
            style: TextStyle(
                color: c, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.score,
    required this.note,
    required this.weight,
  });
  final IconData icon;
  final String label;
  final String hint;
  final int score;
  final String note;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(score);
    final pct = (weight * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('$score',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(note,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkSoft)),
          Text(hint,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black38,
                  letterSpacing: 0.2,
                  height: 1.3)),
        ],
      ),
    );
  }
}
