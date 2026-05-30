/// A small, curated risk database of food additives (E-numbers / INS numbers).
///
/// Risk levels are a pragmatic blend of how EU/FSSAI regulators and food-safety
/// groups (e.g. EFSA re-evaluations, EWG, IARC notes) treat each additive.
/// This is intentionally conservative and is NOT medical advice.
library;

enum AdditiveRisk { low, moderate, high }

class AdditiveInfo {
  final String code; // canonical, e.g. "e150d"
  final String name;
  final String klass; // colour, preservative, emulsifier, sweetener, ...
  final AdditiveRisk risk;
  final String note;

  const AdditiveInfo(this.code, this.name, this.klass, this.risk, this.note);
}

/// Map of canonical code -> info. Codes are lower-case, no spaces, e.g. "e102".
const Map<String, AdditiveInfo> kAdditives = {
  // ---- Colours --------------------------------------------------------------
  'e102': AdditiveInfo('e102', 'Tartrazine (Yellow 5)', 'colour',
      AdditiveRisk.high, 'Synthetic azo dye; linked to hyperactivity in children, warning label required in EU.'),
  'e104': AdditiveInfo('e104', 'Quinoline Yellow', 'colour', AdditiveRisk.high,
      'Synthetic dye; "may have an adverse effect on activity and attention in children" warning in EU.'),
  'e110': AdditiveInfo('e110', 'Sunset Yellow (Yellow 6)', 'colour',
      AdditiveRisk.high, 'Azo dye; Southampton-study additive linked to hyperactivity.'),
  'e122': AdditiveInfo('e122', 'Carmoisine / Azorubine', 'colour',
      AdditiveRisk.high, 'Azo dye; hyperactivity warning in EU; banned in some countries.'),
  'e124': AdditiveInfo('e124', 'Ponceau 4R', 'colour', AdditiveRisk.high,
      'Azo dye; hyperactivity warning in EU; restricted/banned elsewhere.'),
  'e127': AdditiveInfo('e127', 'Erythrosine (Red 3)', 'colour', AdditiveRisk.high,
      'Banned from food in the US (2025) over cancer concerns in animal studies.'),
  'e129': AdditiveInfo('e129', 'Allura Red (Red 40)', 'colour', AdditiveRisk.high,
      'Azo dye; hyperactivity warning in EU; under scrutiny for gut inflammation.'),
  'e131': AdditiveInfo('e131', 'Patent Blue V', 'colour', AdditiveRisk.moderate,
      'Synthetic dye; can trigger allergic reactions in sensitive people.'),
  'e133': AdditiveInfo('e133', 'Brilliant Blue (Blue 1)', 'colour',
      AdditiveRisk.moderate, 'Synthetic dye; generally considered low-risk but avoid heavy exposure.'),
  'e150c': AdditiveInfo('e150c', 'Ammonia Caramel', 'colour', AdditiveRisk.moderate,
      'Caramel colour made with ammonia.'),
  'e150d': AdditiveInfo('e150d', 'Sulphite Ammonia Caramel', 'colour',
      AdditiveRisk.moderate, 'Common in colas; may contain 4-MEI, a possible carcinogen at high doses.'),
  'e160b': AdditiveInfo('e160b', 'Annatto', 'colour', AdditiveRisk.low,
      'Natural orange-red colour; rare allergen.'),
  'e171': AdditiveInfo('e171', 'Titanium Dioxide', 'colour', AdditiveRisk.high,
      'Banned as a food additive in the EU (2022) — cannot rule out genotoxicity.'),

  // ---- Preservatives --------------------------------------------------------
  'e200': AdditiveInfo('e200', 'Sorbic Acid', 'preservative', AdditiveRisk.low,
      'Generally well tolerated.'),
  'e202': AdditiveInfo('e202', 'Potassium Sorbate', 'preservative',
      AdditiveRisk.low, 'Common, low-risk preservative.'),
  'e210': AdditiveInfo('e210', 'Benzoic Acid', 'preservative', AdditiveRisk.moderate,
      'Can form benzene with vitamin C; possible reactions in sensitive people.'),
  'e211': AdditiveInfo('e211', 'Sodium Benzoate', 'preservative',
      AdditiveRisk.moderate, 'With ascorbic acid can form trace benzene; part of hyperactivity studies.'),
  'e220': AdditiveInfo('e220', 'Sulphur Dioxide', 'preservative', AdditiveRisk.moderate,
      'Sulphite — can trigger asthma/allergic reactions; must be declared.'),
  'e223': AdditiveInfo('e223', 'Sodium Metabisulphite', 'preservative',
      AdditiveRisk.moderate, 'Sulphite; asthma/allergy trigger.'),
  'e249': AdditiveInfo('e249', 'Potassium Nitrite', 'preservative', AdditiveRisk.high,
      'Nitrite in cured meat; forms nitrosamines — processed-meat carcinogen group.'),
  'e250': AdditiveInfo('e250', 'Sodium Nitrite', 'preservative', AdditiveRisk.high,
      'Nitrite in cured/processed meat; nitrosamine formation, IARC links processed meat to cancer.'),
  'e251': AdditiveInfo('e251', 'Sodium Nitrate', 'preservative', AdditiveRisk.high,
      'Curing salt; converts to nitrite — same processed-meat concerns.'),
  'e320': AdditiveInfo('e320', 'BHA (Butylated Hydroxyanisole)', 'antioxidant',
      AdditiveRisk.high, '"Reasonably anticipated to be a human carcinogen" (US NTP).'),
  'e321': AdditiveInfo('e321', 'BHT (Butylated Hydroxytoluene)', 'antioxidant',
      AdditiveRisk.moderate, 'Synthetic antioxidant; some animal-study concerns.'),

  // ---- Flavour enhancers ----------------------------------------------------
  'e621': AdditiveInfo('e621', 'Monosodium Glutamate (MSG)', 'flavour enhancer',
      AdditiveRisk.moderate, 'Generally recognised as safe, but adds hidden sodium and is a marker of ultra-processing.'),
  'e627': AdditiveInfo('e627', 'Disodium Guanylate', 'flavour enhancer',
      AdditiveRisk.moderate, 'Almost always paired with MSG; not for infants; gout caution.'),
  'e631': AdditiveInfo('e631', 'Disodium Inosinate', 'flavour enhancer',
      AdditiveRisk.moderate, 'Often from meat/fish; paired with MSG; gout caution.'),

  // ---- Sweeteners -----------------------------------------------------------
  'e950': AdditiveInfo('e950', 'Acesulfame K', 'sweetener', AdditiveRisk.moderate,
      'Artificial sweetener; WHO advises against using non-sugar sweeteners for weight control.'),
  'e951': AdditiveInfo('e951', 'Aspartame', 'sweetener', AdditiveRisk.moderate,
      'IARC classified as "possibly carcinogenic" (2023); not for people with PKU.'),
  'e952': AdditiveInfo('e952', 'Cyclamate', 'sweetener', AdditiveRisk.moderate,
      'Banned in the US; allowed elsewhere with limits.'),
  'e954': AdditiveInfo('e954', 'Saccharin', 'sweetener', AdditiveRisk.moderate,
      'Old artificial sweetener; once linked to bladder tumours in rats.'),
  'e955': AdditiveInfo('e955', 'Sucralose', 'sweetener', AdditiveRisk.moderate,
      'Artificial sweetener; recent studies flag possible DNA/gut effects, especially when heated.'),
  'e960': AdditiveInfo('e960', 'Steviol Glycosides (Stevia)', 'sweetener',
      AdditiveRisk.low, 'Plant-derived sweetener; still a non-sugar sweetener per WHO guidance.'),
  'e420': AdditiveInfo('e420', 'Sorbitol', 'sweetener', AdditiveRisk.low,
      'Sugar alcohol; laxative effect in larger amounts.'),
  'e421': AdditiveInfo('e421', 'Mannitol', 'sweetener', AdditiveRisk.low,
      'Sugar alcohol; laxative effect in larger amounts.'),
  'e965': AdditiveInfo('e965', 'Maltitol', 'sweetener', AdditiveRisk.low,
      'Sugar alcohol; laxative effect, raises blood sugar more than other polyols.'),

  // ---- Emulsifiers / stabilisers / others -----------------------------------
  'e322': AdditiveInfo('e322', 'Lecithins', 'emulsifier', AdditiveRisk.low,
      'Usually soy/sunflower lecithin; widely used, low risk.'),
  'e407': AdditiveInfo('e407', 'Carrageenan', 'thickener', AdditiveRisk.moderate,
      'Some studies link degraded carrageenan to gut inflammation.'),
  'e433': AdditiveInfo('e433', 'Polysorbate 80', 'emulsifier', AdditiveRisk.moderate,
      'Emulsifier; animal studies suggest gut-microbiome / inflammation effects.'),
  'e466': AdditiveInfo('e466', 'Carboxymethylcellulose (CMC)', 'thickener',
      AdditiveRisk.moderate, 'Emulsifier; recent human studies suggest microbiome changes.'),
  'e471': AdditiveInfo('e471', 'Mono- & Diglycerides of Fatty Acids', 'emulsifier',
      AdditiveRisk.moderate, 'Can be made from palm oil; can hide trans fats; marker of ultra-processing.'),
  'e500': AdditiveInfo('e500', 'Sodium Bicarbonate', 'raising agent', AdditiveRisk.low,
      'Baking soda; safe.'),
  'e503': AdditiveInfo('e503', 'Ammonium Bicarbonate', 'raising agent',
      AdditiveRisk.low, 'Common in biscuits; safe.'),
  'e330': AdditiveInfo('e330', 'Citric Acid', 'acidity regulator', AdditiveRisk.low,
      'Very common; safe (though usually industrially produced).'),
  'e296': AdditiveInfo('e296', 'Malic Acid', 'acidity regulator', AdditiveRisk.low,
      'Common acidulant; safe.'),
  'e338': AdditiveInfo('e338', 'Phosphoric Acid', 'acidity regulator',
      AdditiveRisk.moderate, 'Gives colas their tang; high phosphate intake linked to bone-density concerns.'),
  'e951x': AdditiveInfo('e951x', 'Artificial Flavour (unspecified)', 'flavour',
      AdditiveRisk.moderate, 'A blanket "flavour" with no detail is a hallmark of ultra-processed food.'),
};

/// Normalise an additive token from any source into a canonical key.
/// Handles: "E150d", "e 150 d", "ins 150 (d)", "INS150D", "330", etc.
String? normalizeAdditiveCode(String raw) {
  var s = raw.toLowerCase().trim();
  s = s.replaceAll('insertion', ''); // guard against odd OCR
  s = s.replaceAll(RegExp(r'ins\.?'), 'e'); // INS -> E
  s = s.replaceAll(RegExp(r'[^a-z0-9]'), ''); // strip spaces, brackets, dots
  // bare number like "330" -> "e330"
  if (RegExp(r'^\d{3,4}[a-z]?$').hasMatch(s)) s = 'e$s';
  if (!RegExp(r'^e\d{3,4}[a-z]?$').hasMatch(s)) return null;
  if (kAdditives.containsKey(s)) return s;
  // try without the trailing letter (e150 vs e150d)
  final base = s.replaceAll(RegExp(r'[a-z]$'), '');
  if (kAdditives.containsKey(base)) return base;
  return s; // unknown but well-formed; caller may still show it as "unknown additive"
}

AdditiveInfo? lookupAdditive(String raw) {
  final code = normalizeAdditiveCode(raw);
  if (code == null) return null;
  return kAdditives[code];
}
