/// Per-ingredient health grades, used by pillar #2 (ingredient health impact).
///
/// Each ingredient pattern is given a grade from `-3` (clearly harmful in
/// quantity) to `+3` (whole, real, beneficial). The scoring engine matches
/// every item on a product's ingredient list against these patterns,
/// weights them by position (first ingredients matter most), and rolls the
/// result into a 0–100 pillar score.
///
/// Grades reflect a pragmatic synthesis of the same sources the rest of the
/// engine uses (Nutri-Score, NOVA, EFSA additive re-evaluations, EWG,
/// FSSAI/EU labelling). Branded names are intentionally excluded — the
/// score is decided by what's in the ingredient, not by who made it.
library;

class IngredientGrade {
  final String label; // user-friendly name for the matched ingredient
  final int grade; // -3 .. +3
  final String reason; // shown in the "why" breakdown
  final List<RegExp> patterns;

  IngredientGrade({
    required this.label,
    required this.grade,
    required this.reason,
    required List<String> any,
  }) : patterns = any
            .map((p) => RegExp(r'\b' + p + r'\b', caseSensitive: false))
            .toList();
}

class IngredientHit {
  final IngredientGrade grade;
  final int position; // 0-based index in the ingredient list
  final String matchedText;
  IngredientHit(this.grade, this.position, this.matchedText);
}

/// Order matters: the engine takes the **minimum (worst)** grade among
/// matches per ingredient, so put the most damaging patterns first.
final List<IngredientGrade> kIngredientGrades = [
  // ---------- Worst-in-class fats and oils -------------------------------
  IngredientGrade(
    label: 'Hydrogenated / vanaspati fat',
    grade: -3,
    reason: 'Partially hydrogenated fat = trans fat. WHO calls for elimination.',
    any: [
      'partially hydrogenated',
      'hydrogenated (vegetable )?(oil|fat)',
      'vanaspati',
      'interesterified',
      'shortening'
    ],
  ),
  IngredientGrade(
    label: 'Palm oil',
    grade: -3,
    reason: 'Very high saturated fat; refined palm oil can carry 3-MCPD / GE contaminants.',
    any: ['palm ?oil', 'palm ?olein', 'palm ?kernel ?oil', 'palmolein', 'rbd palm'],
  ),

  // ---------- Worst-in-class sweeteners ----------------------------------
  IngredientGrade(
    label: 'High-fructose corn syrup',
    grade: -3,
    reason: 'Liquid free sugar; metabolically similar to / worse than sucrose.',
    any: ['high fructose corn syrup', 'hfcs', 'corn syrup solids'],
  ),
  IngredientGrade(
    label: 'Glucose / fructose syrup',
    grade: -2,
    reason: 'Cheap liquid sugar with very high glycemic load.',
    any: [
      'glucose syrup', 'fructose syrup', 'glucose-fructose syrup',
      'liquid glucose', 'invert syrup', 'corn syrup', 'rice syrup', 'maltose syrup'
    ],
  ),
  IngredientGrade(
    label: 'Maltodextrin',
    grade: -2,
    reason: 'Heavily processed starch; spikes blood sugar faster than table sugar.',
    any: ['maltodextrin'],
  ),
  IngredientGrade(
    label: 'Refined flour (maida)',
    grade: -2,
    reason: 'Bran & germ stripped — almost no fibre or micronutrients.',
    any: ['maida', 'refined wheat flour', 'refined flour', 'all.purpose flour',
        r'wheat flour \(refined\)'],
  ),
  IngredientGrade(
    label: 'Added sugar',
    grade: -1,
    reason: 'Free sugar — WHO advises < ~10% of daily energy.',
    any: [
      'sugar', 'sucrose', 'cane sugar', 'caster sugar', 'icing sugar',
      'demerara', 'brown sugar'
    ],
  ),
  IngredientGrade(
    label: 'Artificial sweetener',
    grade: -2,
    reason: 'WHO advises against non-sugar sweeteners for weight control.',
    any: [
      'aspartame', 'sucralose', 'acesulfame', 'saccharin', 'cyclamate',
      'neotame', 'advantame', 'artificial sweeten'
    ],
  ),

  // ---------- Artificial / "extracted" substances ------------------------
  IngredientGrade(
    label: 'Artificial flavour',
    grade: -2,
    reason: 'Lab-made flavour without detail — a hallmark of ultra-processed food.',
    any: [
      'artificial flavou?rs?(ing)?',
      'synthetic flavou?rs?',
      'nature.identical flavou?rs?',
      'identical flavou?ring substances'
    ],
  ),
  IngredientGrade(
    label: 'Artificial colour',
    grade: -3,
    reason: 'Synthetic dyes (e.g. INS 102 / 110 / 122 / 124 / 129) add nothing nutritionally; several have hyperactivity warnings in the EU.',
    any: ['artificial colou?rs?', 'synthetic colou?rs?', 'added colou?rs?', r'colou?r \(class'],
  ),
  IngredientGrade(
    label: 'MSG / flavour enhancer',
    grade: -1,
    reason: 'Hidden sodium and a marker of heavily engineered taste.',
    any: [
      'monosodium glutamate', r'm\.?s\.?g', 'ajinomoto', 'flavou?r enhancer',
      'yeast extract'
    ],
  ),
  IngredientGrade(
    label: 'Chemical preservative',
    grade: -1,
    reason: 'Named preservatives mark long-shelf-life processing.',
    any: [
      'sodium benzoate', 'potassium benzoate', 'sodium nitrite', 'potassium nitrite',
      'sodium nitrate', 'sulphur dioxide', 'sulfur dioxide', 'sodium metabisulphite',
      'potassium metabisulphite', 'calcium propionate', 'bha', 'bht', 'tbhq',
      'preservative'
    ],
  ),
  IngredientGrade(
    label: 'Dough conditioner / improver',
    grade: -1,
    reason: 'Industrial baking aids — another ultra-processing marker.',
    any: ['dough conditioner', 'flour treatment agent', 'bread improver'],
  ),
  IngredientGrade(
    label: 'Refined / "edible vegetable oil"',
    grade: -1,
    reason: 'Vague "edible vegetable oil" hides which oil it is — usually the cheapest, most refined option.',
    any: ['edible vegetable oil', 'refined vegetable oil', 'vegetable fat'],
  ),

  // ---------- Neutrals (acknowledged but not penalised heavily) ----------
  IngredientGrade(
    label: 'Salt',
    grade: 0,
    reason: 'Some salt is normal; the actual amount is judged by the nutrition pillar.',
    any: ['salt', 'iodised salt', 'iodized salt', 'sea salt', 'rock salt'],
  ),
  IngredientGrade(
    label: 'Water',
    grade: 0,
    reason: 'Neutral.',
    any: ['water', 'aqua'],
  ),
  IngredientGrade(
    label: 'Citric / malic acid',
    grade: 0,
    reason: 'Common acidulants; not a health concern in food amounts.',
    any: ['citric acid', 'malic acid', 'lactic acid'],
  ),

  // ---------- Real / whole / beneficial ingredients -----------------------
  IngredientGrade(
    label: 'Whole grain',
    grade: 3,
    reason: 'Whole grains keep their fibre, minerals and micronutrients.',
    any: ['whole ?wheat', 'whole ?grain', 'whole ?oat', 'whole ?meal', 'atta', 'brown rice', 'millet', 'ragi', 'bajra', 'jowar'],
  ),
  IngredientGrade(
    label: 'Real fruit / vegetable',
    grade: 3,
    reason: 'Actual fruit/veg content rather than just flavouring.',
    any: [
      r'fruit (pulp|puree|concentrate|pieces)?',
      'mango pulp', 'tomato (puree|paste)', r'vegetable (puree|pieces)',
      'orange', 'apple', 'spinach', 'carrot'
    ],
  ),
  IngredientGrade(
    label: 'Nuts / seeds',
    grade: 3,
    reason: 'Whole nuts and seeds — fibre, protein, healthy fats.',
    any: ['almond', 'cashew', 'walnut', 'peanut', 'pistachio', 'sunflower seed', 'flax', 'chia', 'sesame'],
  ),
  IngredientGrade(
    label: 'Legume / pulse',
    grade: 2,
    reason: 'Pulses bring protein and fibre.',
    any: ['chickpea', 'kabuli chana', 'gram', 'besan', 'soybean', 'soy protein', 'lentil', 'moong', 'masoor'],
  ),
  IngredientGrade(
    label: 'Dairy (milk / curd / paneer)',
    grade: 1,
    reason: 'Provides protein and calcium; sat-fat content is graded separately.',
    any: ['milk solids', 'milk powder', 'milk fat', 'paneer', 'yogurt', 'curd', 'whey'],
  ),
  IngredientGrade(
    label: 'Honey / jaggery',
    grade: 0,
    reason: 'Less refined than white sugar but still a free sugar — limit intake.',
    any: ['honey', 'jaggery', 'gur'],
  ),
  IngredientGrade(
    label: 'Cold-pressed / cocoa solids',
    grade: 1,
    reason: 'Higher-quality fat / cocoa source.',
    any: ['cold.pressed', 'cocoa solids', 'cocoa butter', 'olive oil', 'ghee', 'mustard oil'],
  ),
];

/// Look up the grade for a single ingredient string, returning the minimum
/// (worst) grade among all matching patterns, or null if nothing matched.
IngredientGrade? gradeFor(String ingredient) {
  IngredientGrade? best;
  for (final g in kIngredientGrades) {
    for (final p in g.patterns) {
      if (p.hasMatch(ingredient)) {
        if (best == null || g.grade < best.grade) best = g;
        break;
      }
    }
  }
  return best;
}
