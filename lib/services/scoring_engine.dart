import 'dart:math';

import '../data/additives_db.dart';
import '../data/ingredient_flags.dart';
import '../data/ingredient_grades.dart';
import '../data/product_categories.dart';
import '../models/health_report.dart';
import '../models/product.dart';

/// Turns a [Product] into a [HealthReport].
///
/// The engine builds **four transparent sub-scores** (0–100 each) and then
/// blends them by fixed weights:
///
///   1. Nutrition   — bad nutrients (sugar/sat-fat/salt/energy) vs.
///                    good nutrients (fibre/protein/fruit-veg), judged
///                    against thresholds for the product's *category*.
///   2. Ingredient  — every ingredient gets a -3..+3 grade; position-
///                    weighted so the first listed ingredients matter more.
///   3. Processing  — NOVA 1..4 (unprocessed → ultra-processed).
///   4. Additive    — penalty for additives flagged by global research
///                    (EFSA, IARC, FSSAI / EU rules).
///
/// Brands and marketing claims have **no influence** on the score. The
/// "health-washing" check below is purely informational and only affects
/// the displayed summary.
class ScoringEngine {
  static const _healthWashWords = [
    'healthy', 'health', 'natural', 'nature', 'wholesome', 'guilt free',
    'guilt-free', 'no added sugar', 'sugar free', 'sugar-free', 'zero sugar',
    'diet', 'lite', 'light', 'fit', 'active', 'protein', 'immunity', 'wellness',
    'real ', 'pure', 'farm fresh', 'organic', 'detox', 'superfood', 'low fat',
    'fat free', 'baked not fried', 'multigrain', 'made with real',
  ];

  HealthReport analyse(Product p) {
    final blob = p.ingredientsBlob;
    final n = p.nutriments;
    final category = detectCategory(p);
    final thresholds = thresholdsFor(category);

    // --------------------------------------------------------- additives gather
    final additiveCodes = <String>{...p.additiveCodes};
    for (final m in RegExp(r'\b(?:ins|e)\s?\.?\s?\d{3,4}\s?[a-z]?\b',
            caseSensitive: false)
        .allMatches(blob)) {
      final c = normalizeAdditiveCode(m.group(0)!);
      if (c != null) additiveCodes.add(c);
    }
    final additives = additiveCodes
        .map((c) => MapEntry(c, kAdditives[c]))
        .toList()
      ..sort((a, b) {
        int r(AdditiveInfo? i) => switch (i?.risk) {
              AdditiveRisk.high => 0,
              AdditiveRisk.moderate => 1,
              _ => 2,
            };
        return r(a.value).compareTo(r(b.value));
      });

    // --------------------------------------------------------------- flags
    final flagHits = blob.trim().length > 3 ? detectFlags(blob) : <FlagHit>[];

    // ============== Pillar 1 — NUTRITION ====================================
    final factors = <ScoreFactor>[];
    final (nutritionScore, nutritionNote, nutritionFactors) =
        _nutritionPillar(n, thresholds, category);
    factors.addAll(nutritionFactors);

    // ============== Pillar 2 — INGREDIENT ===================================
    final ingredientList = _splitIngredients(p);
    final (ingredientScore, ingredientNote, ingredientFactors) =
        _ingredientPillar(ingredientList);
    factors.addAll(ingredientFactors);

    // ============== Pillar 3 — PROCESSING ===================================
    final (novaGroup, novaEstimated) = _novaFor(p, additiveCodes, flagHits);
    final (processingScore, processingNote, processingFactor) =
        _processingPillar(novaGroup, novaEstimated);
    if (processingFactor != null) factors.add(processingFactor);

    // ============== Pillar 4 — ADDITIVES ====================================
    final (additiveScore, additiveNote, additiveFactor) =
        _additivePillar(additives);
    if (additiveFactor != null) factors.add(additiveFactor);

    final pillars = PillarScores(
      nutrition: nutritionScore,
      ingredient: ingredientScore,
      processing: processingScore,
      additive: additiveScore,
      nutritionNote: nutritionNote,
      ingredientNote: ingredientNote,
      processingNote: processingNote,
      additiveNote: additiveNote,
    );

    // ---------------------------------------------------------------- claims
    final packText =
        '${p.name} ${p.brand ?? ''} ${p.categories.join(' ')}'.toLowerCase();
    final claims = <String>[];
    for (final w in _healthWashWords) {
      if (packText.contains(w)) claims.add(w.trim());
    }
    final claimsDistinct = claims.toSet().toList();

    // ---------------------------------------------------------------- combine
    final overall = pillars.overall;
    final stars = (max(0.5, overall / 20)).clamp(0.5, 5.0);
    final starsRounded = (stars * 2).round() / 2;
    final verdict = overall >= 80
        ? Verdict.trust
        : overall >= 62
            ? Verdict.okay
            : overall >= 45
                ? Verdict.careful
                : overall >= 25
                    ? Verdict.poor
                    : Verdict.avoid;

    // Letter grade: prefer Nutri-Score from OFF when available, else derive.
    final nutriGrade = (p.nutriScoreGrade != null &&
            'abcde'.contains(p.nutriScoreGrade!))
        ? p.nutriScoreGrade!
        : overall >= 80
            ? 'a'
            : overall >= 65
                ? 'b'
                : overall >= 50
                    ? 'c'
                    : overall >= 35
                        ? 'd'
                        : 'e';

    // Confidence: nutrition table thinness + NOVA estimated.
    double confidence = 1.0;
    if (n.isEmpty) confidence -= 0.2;
    if (novaEstimated) confidence -= 0.1;
    if (ingredientList.isEmpty) confidence -= 0.2;
    confidence = confidence.clamp(0.25, 1.0);

    // sort factors: biggest penalties first, then bonuses, then notes
    factors.sort((a, b) {
      if (a.points == b.points) return 0;
      if (a.points < 0 && b.points < 0) return a.points.compareTo(b.points);
      if (a.points < 0) return -1;
      if (b.points < 0) return 1;
      return b.points.compareTo(a.points);
    });

    final summary = _buildSummary(
      p: p,
      pct: overall,
      verdict: verdict,
      nova: novaGroup,
      additivesHighCount:
          additives.where((e) => e.value?.risk == AdditiveRisk.high).length,
      flagHits: flagHits,
      claims: claimsDistinct,
      sugars: n.sugars,
      sat: n.saturatedFat,
      salt: n.salt,
      noNutrition: n.isEmpty,
      category: category,
    );

    return HealthReport(
      healthPercent: overall,
      stars: starsRounded,
      verdict: verdict,
      novaGroup: novaGroup,
      novaEstimated: novaEstimated,
      nutriGrade: nutriGrade,
      flags: flagHits,
      additives: additives,
      marketingClaims: claimsDistinct,
      factors: factors,
      summary: summary,
      confidence: confidence,
      pillars: pillars,
      category: category,
    );
  }

  // =============== Pillar 1 — Nutrition ====================================
  (int, String, List<ScoreFactor>) _nutritionPillar(
      Nutriments n, NutritionThresholds t, ProductCategory cat) {
    final factors = <ScoreFactor>[];
    if (n.isEmpty) {
      factors.add(const ScoreFactor(
        label: 'Nutrition facts not available',
        points: 0,
        detail: 'No per-100g panel — nutrition pillar is set to neutral (50).',
        severity: FlagSeverity.caution,
      ));
      return (
        50,
        'Nutrition panel missing — scored neutrally.',
        factors,
      );
    }
    int score = 100;

    int applyTiers(double? v, List<Tier> tiers, String label,
        String unit, FlagSeverity worstSeverity) {
      if (v == null) return 0;
      for (final tier in tiers) {
        if (v >= tier.atLeast) {
          score -= tier.penalty;
          factors.add(ScoreFactor(
            label: '$label ${_g(v)}/$unit',
            points: -tier.penalty,
            detail:
                'At or above ${tier.atLeast}$unit per 100${cat.isLiquid ? "ml" : "g"} for ${cat.label.toLowerCase()}s.',
            severity: tier.penalty >= 12 ? worstSeverity : FlagSeverity.caution,
          ));
          return tier.penalty;
        }
      }
      return 0;
    }

    final unit = cat.isLiquid ? 'ml' : 'g';
    applyTiers(n.sugars, t.sugar, 'Sugar', unit, FlagSeverity.bad);
    applyTiers(n.saturatedFat, t.satFat, 'Saturated fat', unit, FlagSeverity.bad);
    applyTiers(n.salt, t.salt, 'Salt', unit, FlagSeverity.bad);
    applyTiers(n.energyKcal, t.energyKcal, 'Energy', 'kcal/100$unit',
        FlagSeverity.caution);

    int applyBonuses(double? v, List<Tier> tiers, String label, String detail) {
      if (v == null) return 0;
      for (final tier in tiers) {
        if (v >= tier.atLeast) {
          score += tier.penalty;
          factors.add(ScoreFactor(
            label: '$label ${_g(v)}/100$unit',
            points: tier.penalty,
            detail: detail,
            severity: FlagSeverity.info,
          ));
          return tier.penalty;
        }
      }
      return 0;
    }

    // Don't reward protein on a junk-food product (sugar > heavy or sat fat > heavy)
    final lowJunk = (n.sugars ?? 0) < 15 && (n.saturatedFat ?? 0) < 6;
    applyBonuses(
        n.fiber, t.fiberBonus, 'Fibre', 'Good fibre content — gut & satiety.');
    if (lowJunk) {
      applyBonuses(
          n.proteins, t.proteinBonus, 'Protein', 'Useful protein content.');
    }
    applyBonuses(n.fruitsVegNuts, t.fruitVegBonus,
        'Fruit / veg / nuts', 'Real plant content rather than just flavour.');

    score = score.clamp(0, 100);

    // Human-readable takeaway
    String note;
    if (score >= 80) {
      note = 'Strong nutrition profile for a ${cat.label.toLowerCase()}.';
    } else if (score >= 60) {
      note = 'Average nutrition profile for its category.';
    } else if (score >= 40) {
      note = 'Below-average nutrition — high in at least one bad nutrient.';
    } else {
      note = 'Poor nutrition profile — too much sugar / salt / saturated fat.';
    }
    return (score, note, factors);
  }

  // =============== Pillar 2 — Ingredient ===================================
  (int, String, List<ScoreFactor>) _ingredientPillar(List<String> ingredients) {
    final factors = <ScoreFactor>[];
    if (ingredients.isEmpty) {
      factors.add(const ScoreFactor(
        label: 'Ingredient list unavailable',
        points: 0,
        detail: 'Without ingredients, the per-ingredient pillar is neutral (50).',
        severity: FlagSeverity.caution,
      ));
      return (50, 'No ingredient list — scored neutrally.', factors);
    }

    // Position weights: first ingredient ~3×, second 2×, third 1.5×, then 1×, taper after #5.
    double weightFor(int i) =>
        i == 0 ? 3.0 : (i == 1 ? 2.0 : (i == 2 ? 1.5 : (i < 5 ? 1.0 : 0.6)));

    double weighted = 0;
    double weightSum = 0;
    final hits = <IngredientHit>[];
    for (var i = 0; i < ingredients.length; i++) {
      final raw = ingredients[i];
      final g = gradeFor(raw);
      final w = weightFor(i);
      weightSum += w;
      if (g != null) {
        hits.add(IngredientHit(g, i, raw));
        weighted += g.grade * w;
      }
      // Unmatched ingredients contribute 0 grade × w (neutral).
    }
    if (weightSum == 0) {
      return (
        50,
        'No ingredient list — scored neutrally.',
        const <ScoreFactor>[]
      );
    }

    // Average grade in [-3..+3] → map to [0..100]
    final avg = weighted / weightSum;
    final score = (((avg + 3) / 6) * 100).round().clamp(0, 100);

    // Build a few factor lines from the strongest hits.
    final worst = [...hits.where((h) => h.grade.grade < 0)]
      ..sort((a, b) => a.grade.grade.compareTo(b.grade.grade));
    final best = [...hits.where((h) => h.grade.grade > 0)]
      ..sort((a, b) => b.grade.grade.compareTo(a.grade.grade));
    for (final h in worst.take(3)) {
      final pos = h.position + 1;
      factors.add(ScoreFactor(
        label: '${h.grade.label} (ingredient #$pos)',
        points: -((-h.grade.grade) * 3),
        detail: h.grade.reason,
        severity: h.grade.grade <= -3 ? FlagSeverity.bad : FlagSeverity.caution,
      ));
    }
    for (final h in best.take(2)) {
      factors.add(ScoreFactor(
        label: '${h.grade.label} (ingredient #${h.position + 1})',
        points: h.grade.grade * 2,
        detail: h.grade.reason,
        severity: FlagSeverity.info,
      ));
    }

    String note;
    if (score >= 75) {
      note = 'Mostly whole / real ingredients.';
    } else if (score >= 55) {
      note = 'Mixed — some real food, some refined fillers.';
    } else if (score >= 35) {
      note = 'Refined or lab-made ingredients dominate.';
    } else {
      note = 'Almost entirely refined / artificial ingredients.';
    }
    return (score, note, factors);
  }

  // =============== Pillar 3 — Processing ===================================
  (int, String, ScoreFactor?) _processingPillar(int nova, bool estimated) {
    // Calibrated so NOVA 4 (ultra-processed) alone drags overall scoring
    // meaningfully even when the nutrition panel "looks ok".
    final score = switch (nova) {
      1 => 100,
      2 => 80,
      3 => 50,
      _ => 15,
    };
    final note = switch (nova) {
      1 => 'Unprocessed or minimally processed.',
      2 => 'Processed culinary ingredients (oils, salt, sugar).',
      3 => 'Processed food — sugar/salt/oil/preservatives added to whole foods.',
      _ => 'Ultra-processed — industrial formulation of refined substances & additives.',
    };
    final factor = ScoreFactor(
      label: 'Processing level NOVA $nova/4${estimated ? ' (estimated)' : ''}',
      points: score - 50,
      detail: note,
      severity: nova >= 4
          ? FlagSeverity.bad
          : (nova == 3 ? FlagSeverity.caution : FlagSeverity.info),
    );
    return (score, note, factor);
  }

  // =============== Pillar 4 — Additive =====================================
  (int, String, ScoreFactor?) _additivePillar(
      List<MapEntry<String, AdditiveInfo?>> additives) {
    int penalty = 0;
    int highCount = 0;
    int modCount = 0;
    for (final e in additives) {
      switch (e.value?.risk) {
        case AdditiveRisk.high:
          highCount++;
          penalty += 18;
        case AdditiveRisk.moderate:
          modCount++;
          penalty += 7;
        default:
          break;
      }
    }
    // Many additives in total is itself a smell, even at "low" risk.
    if (additives.length >= 6) penalty += 8;

    final score = (100 - penalty).clamp(0, 100);

    String note;
    if (additives.isEmpty) {
      note = 'No additives detected.';
    } else if (highCount == 0 && modCount == 0) {
      note = '${additives.length} additive${additives.length > 1 ? 's' : ''}, none on the global watch-list.';
    } else if (highCount == 0) {
      note = '$modCount additive${modCount > 1 ? 's' : ''} of moderate concern.';
    } else {
      note =
          '$highCount high-risk + $modCount moderate-risk additive${highCount + modCount > 1 ? 's' : ''}.';
    }

    ScoreFactor? factor;
    if (penalty > 0) {
      factor = ScoreFactor(
        label: highCount > 0
            ? '$highCount high-risk additive${highCount > 1 ? 's' : ''}'
                '${modCount > 0 ? ' + $modCount more' : ''}'
            : '$modCount additive${modCount > 1 ? 's' : ''} of concern',
        points: -penalty,
        detail: additives
            .where((e) =>
                e.value?.risk == AdditiveRisk.high ||
                e.value?.risk == AdditiveRisk.moderate)
            .map((e) => e.value == null
                ? e.key.toUpperCase()
                : '${e.value!.name} (${e.key.toUpperCase()})')
            .take(6)
            .join(', '),
        severity: highCount > 0 ? FlagSeverity.bad : FlagSeverity.caution,
      );
    }
    return (score, note, factor);
  }

  // =============== NOVA estimation =========================================
  (int, bool) _novaFor(
      Product p, Set<String> additiveCodes, List<FlagHit> flagHits) {
    if (p.novaGroup != null && p.novaGroup! >= 1 && p.novaGroup! <= 4) {
      return (p.novaGroup!, false);
    }
    final highRiskAdds = additiveCodes
        .map((c) => kAdditives[c])
        .where((a) => a?.risk == AdditiveRisk.high)
        .length;
    final ultraMarkers = flagHits
        .where((h) => const {
              'syrups',
              'artificial_flavour',
              'artificial_colour',
              'hydrogenated',
              'maltodextrin',
              'artificial_sweetener',
              'msg',
              'dough_conditioner',
            }.contains(h.flag.id))
        .length;
    int nova;
    if (highRiskAdds > 0 ||
        ultraMarkers >= 1 ||
        additiveCodes.length >= 4) {
      nova = 4;
    } else if (additiveCodes.isNotEmpty ||
        flagHits.any((h) =>
            h.flag.id == 'added_sugar' || h.flag.id == 'maida')) {
      nova = 3;
    } else if (p.ingredientsBlob.split(',').length > 3) {
      nova = 2;
    } else {
      nova = 1;
    }
    return (nova, true);
  }

  // ===================================================================== util
  List<String> _splitIngredients(Product p) {
    if (p.ingredients.isNotEmpty) {
      return p.ingredients
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final raw = p.ingredientsText;
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    // Strip parenthetical detail like "wheat flour (refined)" once for splitting,
    // but keep original for grading.
    return raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String _g(double v) =>
      (v == v.roundToDouble()) ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';

  String _buildSummary({
    required Product p,
    required int pct,
    required Verdict verdict,
    required int nova,
    required int additivesHighCount,
    required List<FlagHit> flagHits,
    required List<String> claims,
    required double? sugars,
    required double? sat,
    required double? salt,
    required bool noNutrition,
    required ProductCategory category,
  }) {
    final b = StringBuffer();
    final name = p.name.isEmpty ? 'This product' : p.name;
    b.write('$name scores $pct% — judged against other ${category.label.toLowerCase()}s. ');

    final bigFlags = flagHits
        .where((h) =>
            h.flag.severity == FlagSeverity.bad &&
            !{'whole_grain', 'real_fruit'}.contains(h.flag.id))
        .map((h) => h.flag.label.toLowerCase())
        .toList();
    final bullets = <String>[];
    if (nova >= 4) bullets.add('ultra-processed');
    if (additivesHighCount > 0) {
      bullets.add(
          '$additivesHighCount high-risk additive${additivesHighCount > 1 ? 's' : ''}');
    }
    if (bigFlags.isNotEmpty) bullets.add('contains ${bigFlags.take(3).join(', ')}');
    if ((sugars ?? 0) > 13.5) bullets.add('high sugar');
    if ((sat ?? 0) > 6) bullets.add('high saturated fat');
    if ((salt ?? 0) > 1.5) bullets.add('high salt');

    if (bullets.isNotEmpty) {
      b.write('Main concerns: ${bullets.join('; ')}. ');
    } else if (verdict == Verdict.trust) {
      b.write('Clean ingredient list and reasonable nutrition. ');
    } else if (noNutrition) {
      b.write('Nutrition facts unavailable — based on ingredient list only. ');
    } else {
      b.write('Nothing alarming, but it is still a processed packaged food — portion sensibly. ');
    }

    if (claims.isNotEmpty &&
        (verdict == Verdict.careful ||
            verdict == Verdict.poor ||
            verdict == Verdict.avoid)) {
      b.write('Note the pack leans on words like "${claims.take(3).join('", "')}" — '
          'the ingredients don\'t fully back that up.');
    }
    return b.toString().trim();
  }
}
