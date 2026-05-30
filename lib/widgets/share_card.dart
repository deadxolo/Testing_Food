import 'dart:io';

import 'package:flutter/material.dart';

import '../data/additives_db.dart';
import '../models/health_report.dart';
import '../models/product.dart';
import '../theme.dart';
import 'score_gauge.dart';
import 'star_rating.dart';

/// A self-contained, fixed-size poster of a health report — designed to be
/// captured to a PNG and shared as an image. Don't use this in normal app UI;
/// it has its own layout, padding and branding intended for the share sheet.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.product, required this.report});

  final Product product;
  final HealthReport report;

  static const double width = 900; // logical px — square-ish poster

  @override
  Widget build(BuildContext context) {
    final v = report.verdict;
    final topReasons = report.penalties.take(4).toList();
    final highRisk = report.additives
        .where((e) => e.value?.risk == AdditiveRisk.high)
        .map((e) => e.value!.name)
        .toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- header band (verdict-coloured) -----------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    v.color.withValues(alpha: 0.95),
                    v.color.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // tiny product thumbnail (if we have one)
                  if (product.localImagePath != null &&
                      File(product.localImagePath!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(product.localImagePath!),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if ((product.imageUrl ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          product.imageUrl!,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FOODFAT HEALTH CHECK',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 8),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w800),
                        ),
                        if ((product.brand ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              product.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- score + verdict ---------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ScoreGauge(percent: report.healthPercent, size: 220),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: v.color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(v.icon, color: v.color, size: 22),
                                const SizedBox(width: 8),
                                Text(v.short,
                                    style: TextStyle(
                                        color: v.color,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6)),
                              ]),
                        ),
                        const SizedBox(height: 14),
                        Text(v.title,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        const SizedBox(height: 10),
                        Row(children: [
                          StarRating(value: report.stars, size: 26),
                          const SizedBox(width: 10),
                          Text('${report.stars.toStringAsFixed(1)} / 5',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppColors.inkSoft)),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          _MetaPill(
                              label: 'NOVA',
                              value: '${report.novaGroup}/4',
                              color: report.novaGroup >= 4
                                  ? AppColors.bad
                                  : (report.novaGroup == 3
                                      ? AppColors.watch
                                      : AppColors.good)),
                          const SizedBox(width: 8),
                          _MetaPill(
                              label: 'GRADE',
                              value: report.nutriGrade.toUpperCase(),
                              color: _gradeColor(report.nutriGrade)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- divider -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Divider(
                  height: 32, color: Colors.black.withValues(alpha: 0.08)),
            ),

            // ---- reasons -----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topReasons.isEmpty
                        ? 'WHY IT SCORES WELL'
                        : 'TOP REASONS',
                    style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (topReasons.isEmpty)
                    const _ReasonRow(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.good,
                      label: 'Clean ingredient list',
                      detail:
                          'No major red flags — reasonable nutrition and minimal additives.',
                    )
                  else
                    ...topReasons.map((f) => _ReasonRow(
                          icon: Icons.cancel_rounded,
                          color: f.points <= -12
                              ? AppColors.bad
                              : AppColors.poor,
                          label: f.label,
                          detail: f.detail,
                          delta: '${f.points}',
                        )),
                  if (highRisk.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bad.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.science_rounded,
                              color: AppColors.bad, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('High-risk additives',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.bad,
                                        fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(highRisk.take(4).join(', '),
                                    style: const TextStyle(
                                        color: AppColors.ink,
                                        fontSize: 14,
                                        height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (report.marketingClaims.isNotEmpty &&
                      (v == Verdict.careful ||
                          v == Verdict.poor ||
                          v == Verdict.avoid)) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.watch.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.watch, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14,
                                    height: 1.35),
                                children: [
                                  const TextSpan(
                                      text: 'Health-washing watch — ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.watch)),
                                  TextSpan(
                                      text:
                                          'pack uses words like "${report.marketingClaims.take(3).join('", "')}", but the ingredients tell a different story.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ---- footer ------------------------------------------------------
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              color: AppColors.bg,
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.seed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.eco_rounded,
                      color: AppColors.seed, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('FoodFat',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const Spacer(),
                Text(
                  product.barcode != null && product.barcode!.isNotEmpty
                      ? '#${product.barcode}  ·  per 100 g'
                      : 'per 100 g',
                  style: TextStyle(
                      color: AppColors.inkSoft.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static Color _gradeColor(String g) => switch (g) {
        'a' => const Color(0xFF1E8E3E),
        'b' => const Color(0xFF7CB342),
        'c' => const Color(0xFFF6A609),
        'd' => const Color(0xFFEF6C00),
        _ => const Color(0xFFD32F2F),
      };
}

class _MetaPill extends StatelessWidget {
  const _MetaPill(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.1)),
        const SizedBox(width: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
    this.delta,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              if (delta != null)
                Text(delta!,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
            ]),
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: AppColors.inkSoft)),
          ]),
        ),
      ]),
    );
  }
}
