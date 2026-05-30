import 'package:flutter/material.dart';

import '../data/additives_db.dart';
import '../data/ingredient_flags.dart';
import '../data/product_categories.dart';

/// A single line in the "why this score" breakdown.
class ScoreFactor {
  final String label;
  final int points; // negative = penalty, positive = bonus, 0 = neutral note
  final String detail;
  final FlagSeverity severity;

  const ScoreFactor({
    required this.label,
    required this.points,
    required this.detail,
    this.severity = FlagSeverity.info,
  });
}

enum Verdict { trust, okay, careful, poor, avoid }

extension VerdictX on Verdict {
  String get title => switch (this) {
        Verdict.trust => 'Genuinely good — you can trust it',
        Verdict.okay => 'Decent — fine in moderation',
        Verdict.careful => 'Be careful — more processed than it looks',
        Verdict.poor => 'Not great — occasional treat at best',
        Verdict.avoid => 'Avoid — ultra-processed with red flags',
      };

  String get short => switch (this) {
        Verdict.trust => 'TRUST IT',
        Verdict.okay => 'OK IN MODERATION',
        Verdict.careful => 'BE CAREFUL',
        Verdict.poor => 'NOT GREAT',
        Verdict.avoid => 'AVOID',
      };

  Color get color => switch (this) {
        Verdict.trust => const Color(0xFF1B8A3A),
        Verdict.okay => const Color(0xFF7CB342),
        Verdict.careful => const Color(0xFFF6A609),
        Verdict.poor => const Color(0xFFEF6C00),
        Verdict.avoid => const Color(0xFFD32F2F),
      };

  IconData get icon => switch (this) {
        Verdict.trust => Icons.verified_rounded,
        Verdict.okay => Icons.thumb_up_alt_rounded,
        Verdict.careful => Icons.warning_amber_rounded,
        Verdict.poor => Icons.report_problem_rounded,
        Verdict.avoid => Icons.dangerous_rounded,
      };
}

/// The 4 transparent sub-scores that make up the final rating.
///
/// 1. **Nutrition** — bad-vs-good nutrients vs. category-aware thresholds.
/// 2. **Ingredient** — per-ingredient health grades, position-weighted.
/// 3. **Processing** — degree of processing (NOVA 1 → 4).
/// 4. **Additive** — penalty for additives flagged by global research (EFSA / IARC / FSSAI).
class PillarScores {
  final int nutrition; // 0..100
  final int ingredient; // 0..100
  final int processing; // 0..100
  final int additive; // 0..100

  /// Short, one-line takeaways for each pillar, shown next to the bar.
  final String nutritionNote;
  final String ingredientNote;
  final String processingNote;
  final String additiveNote;

  /// Weights — sum to 1.0. Calibrated so no single pillar can dominate.
  static const double wNutrition = 0.35;
  static const double wIngredient = 0.25;
  static const double wProcessing = 0.20;
  static const double wAdditive = 0.20;

  const PillarScores({
    required this.nutrition,
    required this.ingredient,
    required this.processing,
    required this.additive,
    required this.nutritionNote,
    required this.ingredientNote,
    required this.processingNote,
    required this.additiveNote,
  });

  /// Weighted overall 0..100 — drives the final stars + verdict.
  int get overall => (nutrition * wNutrition +
          ingredient * wIngredient +
          processing * wProcessing +
          additive * wAdditive)
      .round()
      .clamp(0, 100);
}

class HealthReport {
  /// 0–100 "how healthy is it really" percentage.
  final int healthPercent;

  /// 0.5–5.0 in 0.5 steps.
  final double stars;

  final Verdict verdict;

  /// Estimated degree of processing, 1 (whole food) … 4 (ultra-processed).
  final int novaGroup;
  final bool novaEstimated;

  /// Nutri-Score-style letter A…E (lower-case), computed locally if not provided.
  final String nutriGrade;

  /// Detected red/amber flags from the ingredient list.
  final List<FlagHit> flags;

  /// Additives found, resolved against the risk DB (unknown ones included as null info).
  final List<MapEntry<String, AdditiveInfo?>> additives;

  /// Health-washing words spotted on the pack vs. the real score.
  final List<String> marketingClaims;

  /// Line-by-line scoring breakdown (sorted: worst penalties first).
  final List<ScoreFactor> factors;

  /// Plain-language summary sentence(s).
  final String summary;

  /// Confidence: lower when data was thin (e.g. AI-estimated, missing nutrition).
  final double confidence; // 0..1

  /// The 4 transparent sub-scores. See [PillarScores].
  final PillarScores pillars;

  /// What category the engine compared this product against.
  final ProductCategory category;

  const HealthReport({
    required this.healthPercent,
    required this.stars,
    required this.verdict,
    required this.novaGroup,
    required this.novaEstimated,
    required this.nutriGrade,
    required this.flags,
    required this.additives,
    required this.marketingClaims,
    required this.factors,
    required this.summary,
    required this.confidence,
    required this.pillars,
    required this.category,
  });

  int get highRiskAdditiveCount =>
      additives.where((e) => e.value?.risk == AdditiveRisk.high).length;

  List<ScoreFactor> get penalties =>
      factors.where((f) => f.points < 0).toList();
  List<ScoreFactor> get bonuses => factors.where((f) => f.points > 0).toList();
  List<ScoreFactor> get notes => factors.where((f) => f.points == 0).toList();
}
