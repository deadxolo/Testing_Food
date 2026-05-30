/// Keyword-based "red / amber flags" for ingredient lists — the things the
/// "foodfat" videos always call out: palm oil, maida, vanaspati,
/// glucose/fructose syrups, artificial flavours & colours, etc.
library;

enum FlagSeverity { info, caution, bad }

class IngredientFlag {
  final String id;
  final String label; // short name to show the user
  final String why; // one-line explanation
  final FlagSeverity severity;
  final List<RegExp> patterns; // any match => flag fires

  IngredientFlag({
    required this.id,
    required this.label,
    required this.why,
    required this.severity,
    required List<String> any,
  }) : patterns = any
            .map((p) => RegExp(r'\b' + p + r'\b', caseSensitive: false))
            .toList();
}

final List<IngredientFlag> kIngredientFlags = [
  IngredientFlag(
    id: 'palm_oil',
    label: 'Palm oil',
    why: 'High in saturated fat; refined palm oil can contain process contaminants (3-MCPD, glycidyl esters).',
    severity: FlagSeverity.bad,
    any: ['palm ?oil', 'palm ?olein', 'palm ?kernel ?oil', 'palmolein', 'rbd palm'],
  ),
  IngredientFlag(
    id: 'hydrogenated',
    label: 'Hydrogenated / vanaspati oil',
    why: 'Partially hydrogenated fat = trans fat. WHO calls for its global elimination.',
    severity: FlagSeverity.bad,
    any: [
      'partially hydrogenated',
      'hydrogenated (vegetable )?(oil|fat)',
      'vanaspati',
      'interesterified',
      'shortening'
    ],
  ),
  IngredientFlag(
    id: 'maida',
    label: 'Refined wheat flour (maida)',
    why: 'Refined flour — fibre and most nutrients stripped out; spikes blood sugar.',
    severity: FlagSeverity.caution,
    any: ['maida', 'refined wheat flour', 'refined flour', 'wheat flour \\(refined\\)'],
  ),
  IngredientFlag(
    id: 'added_sugar',
    label: 'Added sugar',
    why: 'Free sugar — WHO advises keeping it under ~10% (ideally 5%) of daily energy.',
    severity: FlagSeverity.caution,
    any: [
      'sugar', 'sucrose', 'cane sugar', 'invert sugar', 'caster sugar',
      'icing sugar', 'demerara', 'jaggery', 'gur'
    ],
  ),
  IngredientFlag(
    id: 'syrups',
    label: 'Glucose / fructose syrup',
    why: 'Cheap liquid sugar (incl. HFCS) — same metabolic effects as sugar, often more of it.',
    severity: FlagSeverity.bad,
    any: [
      'high fructose corn syrup', 'hfcs', 'corn syrup', 'glucose syrup',
      'fructose syrup', 'glucose-fructose syrup', 'liquid glucose',
      'invert syrup', 'maltose syrup', 'rice syrup'
    ],
  ),
  IngredientFlag(
    id: 'maltodextrin',
    label: 'Maltodextrin',
    why: 'Highly processed starch with a very high glycemic index; bulking filler.',
    severity: FlagSeverity.caution,
    any: ['maltodextrin'],
  ),
  IngredientFlag(
    id: 'artificial_flavour',
    label: 'Artificial flavour',
    why: 'Lab-made flavour with no detail listed — a hallmark of ultra-processed food.',
    severity: FlagSeverity.caution,
    any: [
      'artificial flavou?rs?(ing)?', 'synthetic flavou?rs?',
      'nature.identical flavou?rs?', 'identical flavou?ring substances'
    ],
  ),
  IngredientFlag(
    id: 'artificial_colour',
    label: 'Artificial colour',
    why: 'Synthetic dyes add nothing nutritionally; some are linked to hyperactivity in kids.',
    severity: FlagSeverity.bad,
    any: ['artificial colou?rs?', 'synthetic colou?rs?', 'added colou?rs?', 'colou?r \\(class'],
  ),
  IngredientFlag(
    id: 'msg',
    label: 'MSG / flavour enhancer',
    why: 'Adds hidden sodium and signals a heavily engineered taste profile.',
    severity: FlagSeverity.caution,
    any: [
      'monosodium glutamate', 'm\\.?s\\.?g', 'ajinomoto',
      'flavou?r enhancer', 'yeast extract'
    ],
  ),
  IngredientFlag(
    id: 'preservative_named',
    label: 'Chemical preservative',
    why: 'Named preservatives (benzoates, nitrites, sulphites…) — fine in small amounts but mark long-shelf-life processing.',
    severity: FlagSeverity.caution,
    any: [
      'sodium benzoate', 'potassium benzoate', 'sodium nitrite', 'potassium nitrite',
      'sodium nitrate', 'sulphur dioxide', 'sulfur dioxide', 'sodium metabisulphite',
      'potassium metabisulphite', 'calcium propionate', 'bha', 'bht', 'tbhq',
      'preservative'
    ],
  ),
  IngredientFlag(
    id: 'artificial_sweetener',
    label: 'Artificial sweetener',
    why: 'WHO advises against non-sugar sweeteners for weight control; aspartame is "possibly carcinogenic" (IARC).',
    severity: FlagSeverity.caution,
    any: [
      'aspartame', 'sucralose', 'acesulfame', 'saccharin', 'cyclamate',
      'neotame', 'advantame', 'artificial sweeten'
    ],
  ),
  IngredientFlag(
    id: 'refined_oil',
    label: 'Refined / "edible vegetable oil"',
    why: 'Vague "edible vegetable oil" hides which oil it is — often the cheapest, most refined option.',
    severity: FlagSeverity.info,
    any: ['edible vegetable oil', 'refined vegetable oil', 'vegetable fat'],
  ),
  IngredientFlag(
    id: 'salt',
    label: 'Added salt',
    why: 'Too much sodium raises blood pressure; check the per-100g salt figure.',
    severity: FlagSeverity.info,
    any: ['salt', 'iodised salt', 'iodized salt', 'sea salt', 'rock salt'],
  ),
  IngredientFlag(
    id: 'dough_conditioner',
    label: 'Dough conditioner / improver',
    why: 'Industrial baking aids (e.g. emulsifiers, enzymes) — another ultra-processing marker.',
    severity: FlagSeverity.info,
    any: ['dough conditioner', 'flour treatment agent', 'bread improver', 'emulsifier'],
  ),
  IngredientFlag(
    id: 'whole_grain',
    label: 'Whole grain',
    why: 'Good sign — whole grains keep their fibre and nutrients.',
    severity: FlagSeverity.info, // positive note; handled specially by the engine
    any: ['whole ?wheat', 'whole ?grain', 'whole ?oat', 'atta', 'whole ?meal', 'brown rice'],
  ),
  IngredientFlag(
    id: 'real_fruit',
    label: 'Real fruit / vegetable',
    why: 'Good sign — actual fruit/veg content rather than just flavouring.',
    severity: FlagSeverity.info,
    any: ['fruit (pulp|puree|concentrate)?', 'mango pulp', 'tomato (puree|paste)', 'vegetable (puree|pieces)'],
  ),
];

class FlagHit {
  final IngredientFlag flag;
  final String matchedText;
  FlagHit(this.flag, this.matchedText);
}

/// Run all flags against an ingredients blob.
List<FlagHit> detectFlags(String ingredientsBlob) {
  final hits = <FlagHit>[];
  final seen = <String>{};
  for (final f in kIngredientFlags) {
    for (final p in f.patterns) {
      final m = p.firstMatch(ingredientsBlob);
      if (m != null && seen.add(f.id)) {
        hits.add(FlagHit(f, m.group(0) ?? f.label));
        break;
      }
    }
  }
  return hits;
}
