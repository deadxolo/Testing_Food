import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';

/// In-app explainer screen — mirrors the 4-pillar scoring engine and goes
/// deep on what each pillar checks, what the thresholds are, and which
/// label-side signals a human should still eyeball. Accessible from:
///  • About → "How we judge it"
///  • Result screen → AppBar "?" button
///
/// Two reading modes — Quick (the 6 must-knows in one card) and Full (every
/// section). Quick is the default so newcomers aren't drowned in detail.
class HowWeJudgeScreen extends StatefulWidget {
  const HowWeJudgeScreen({super.key});

  @override
  State<HowWeJudgeScreen> createState() => _HowWeJudgeScreenState();
}

enum _Mode { quick, full }

class _HowWeJudgeScreenState extends State<HowWeJudgeScreen> {
  _Mode _mode = _Mode.quick;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How we judge it')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _PillarsHero(),
          const SizedBox(height: 14),
          _ModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 14),
          const _QuickEssentials(),
          if (_mode == _Mode.full) ...[
            const SizedBox(height: 18),
            const _DeepDiveHeader(),
            const SizedBox(height: 10),
            ..._fullSections(),
          ],
          const SizedBox(height: 16),
          _DisclaimerCard(),
        ],
      ),
    );
  }

  List<Widget> _fullSections() => [
        _Section(
            icon: Icons.campaign_rounded,
            title: '1. Marketing words to distrust',
            subtitle:
                'The front of pack is advertising — read the back instead.',
            children: const [
              _Note(
                'These have no legal definition in India and don\'t guarantee anything:',
              ),
              SizedBox(height: 6),
              _ClaimRow(
                  word: '"Healthy", "Wholesome", "Natural"',
                  reality: 'Means nothing in regulation.'),
              _ClaimRow(
                  word: '"No added sugar"',
                  reality:
                      'Often replaced with maltodextrin / fruit-juice concentrate (still sugar).'),
              _ClaimRow(
                  word: '"Diet" / "Lite" / "Light"',
                  reality:
                      'May only mean "less than the regular version" — still high.'),
              _ClaimRow(
                  word: '"Multigrain" / "Made with whole wheat"',
                  reality:
                      'Could be 5% whole grain + 95% maida by weight.'),
              _ClaimRow(
                  word: '"Real fruit", "Made with real X"',
                  reality:
                      'Could be 2% fruit pulp plus flavour.'),
              _ClaimRow(
                  word: '"Zero trans fat"',
                  reality:
                      'In India, < 0.2 g per 100 g can be declared zero. Check ingredients for "hydrogenated".'),
              _ClaimRow(
                  word: '"Sugar free"',
                  reality:
                      'Usually means artificial sweeteners (aspartame, sucralose) — WHO advises against them.'),
              _ClaimRow(
                  word: '"Baked not fried"',
                  reality:
                      'Still high in palm oil, refined flour, salt.'),
              _ClaimRow(
                  word: '"Immunity / Power / Protein / Wellness"',
                  reality: 'Marketing buzzwords without a metric.'),
            ],
          ),
          _Section(
            icon: Icons.list_alt_rounded,
            title: '2. Ingredient list — red flags',
            subtitle:
                'Ingredients are listed by weight. The first 3–5 tell 80% of the story.',
            children: const [
              _BadRow(
                ingredient: 'Palm oil / palmolein / palm kernel oil',
                why:
                    'Very high saturated fat; refined palm oil can carry 3-MCPD and glycidyl-ester contaminants.',
              ),
              _BadRow(
                ingredient:
                    'Hydrogenated / vanaspati / shortening / interesterified fat',
                why:
                    'Source of trans fat — WHO wants this eliminated globally.',
              ),
              _BadRow(
                ingredient:
                    'Refined wheat flour / maida / all-purpose flour',
                why:
                    'Bran + germ stripped — almost no fibre / micronutrients; spikes blood sugar.',
              ),
              _BadRow(
                ingredient:
                    'High-fructose corn syrup / glucose-fructose syrup / liquid glucose',
                why:
                    'Cheap liquid sugar — same metabolic effects as sucrose, often worse.',
              ),
              _BadRow(
                ingredient: 'Maltodextrin',
                why:
                    'Highly processed starch with a very high glycemic index — bulking filler.',
              ),
              _BadRow(
                ingredient:
                    'Sugar (any spelling: sucrose, cane, demerara, jaggery, brown, invert…)',
                why:
                    'Free sugar — WHO says keep below ~10% of daily energy, ideally 5%.',
              ),
              _BadRow(
                ingredient:
                    'Artificial sweeteners (aspartame, sucralose, acesulfame K…)',
                why:
                    'WHO advises against non-sugar sweeteners for weight control; aspartame is "possibly carcinogenic" (IARC 2023).',
              ),
              _BadRow(
                ingredient:
                    'Artificial flavour / synthetic flavour / nature-identical',
                why:
                    'Lab-made flavour with no detail listed — a hallmark of ultra-processed food.',
              ),
              _BadRow(
                ingredient:
                    'Artificial colour / synthetic dyes (INS 102 / 110 / 122 / 124 / 129)',
                why:
                    'Add nothing nutritionally; several carry hyperactivity warnings in the EU.',
              ),
              _BadRow(
                ingredient:
                    'MSG / monosodium glutamate / E621 / "flavour enhancer"',
                why:
                    'Hidden sodium and a marker of heavily engineered taste.',
              ),
              _BadRow(
                ingredient:
                    'Named preservatives (sodium benzoate, nitrites, sulphites, BHA/BHT/TBHQ…)',
                why:
                    'Mark long-shelf-life processing; some have specific risks (nitrites → nitrosamines).',
              ),
              _BadRow(
                ingredient: '"Edible vegetable oil" (unspecified)',
                why:
                    'Almost always the cheapest, most refined oil — usually palm.',
              ),
            ],
          ),
          _Section(
            icon: Icons.eco_rounded,
            title: '3. Ingredient list — good signs',
            subtitle:
                'The higher up these appear, the better.',
            children: const [
              _GoodRow(
                ingredient:
                    'Whole wheat / whole grain / atta / brown rice / millet / oats',
                why:
                    'Keeps the bran + germ — fibre, B-vitamins, minerals.',
              ),
              _GoodRow(
                ingredient: 'Real fruit pulp / vegetable pieces',
                why:
                    'Actual plant content, not just flavour.',
              ),
              _GoodRow(
                ingredient:
                    'Almonds / cashews / walnuts / peanuts / sunflower / pumpkin / flax / chia',
                why:
                    'Fibre, protein, healthy fats.',
              ),
              _GoodRow(
                ingredient:
                    'Chickpea / besan / lentil / moong / masoor / soy',
                why:
                    'Plant protein + fibre.',
              ),
              _GoodRow(
                ingredient:
                    'Olive oil / mustard oil / ghee / cold-pressed oil / cocoa butter',
                why:
                    'Less-refined fats with intact micronutrients.',
              ),
              _GoodRow(
                ingredient:
                    'Live yogurt cultures / lactobacillus / probiotic strains',
                why: 'Beneficial gut bacteria.',
              ),
              SizedBox(height: 6),
              _Note(
                'Rule of thumb: 3–5 short ingredients with names a child can read = usually fine. 15+ ingredients with E-numbers = almost always ultra-processed.',
              ),
            ],
          ),
          _Section(
            icon: Icons.bar_chart_rounded,
            title: '4. Nutrition panel — what numbers matter',
            subtitle:
                'Always use the "per 100 g / 100 ml" column, not "per serving".',
            children: [
              const _Note(
                  'Solid foods — per 100 g (Nutri-Score inspired thresholds):'),
              const SizedBox(height: 8),
              _ThresholdTable(
                  rows: const [
                    ['Sugars',     '< 5 g',       '5–13.5 g',     '13.5–22.5 g',  '> 22.5 g'],
                    ['Saturated fat', '< 1.5 g',  '1.5–3 g',      '3–6 g',         '> 6 g'],
                    ['Salt',       '< 0.3 g',     '0.3–0.9 g',    '0.9–1.5 g',     '> 1.5 g'],
                    ['Energy',     '< 350 kcal', '350–450 kcal', '> 450 kcal',    '—'],
                  ],
                  headers: const ['', 'Low', 'Moderate', 'High', 'Very high']),
              const SizedBox(height: 14),
              const _Note('Drinks — per 100 ml (much stricter, liquid sugar hits the bloodstream fastest):'),
              const SizedBox(height: 8),
              _ThresholdTable(
                  rows: const [
                    ['Sugars', '< 2.5 g', '2.5–5 g', '5–9 g',  '> 9 g'],
                    ['Energy', '< 40',    '40–80',   '80–150', '> 150 kcal'],
                  ],
                  headers: const ['', 'Low', 'Moderate', 'High', 'Very high']),
              const SizedBox(height: 14),
              const _Note('Good numbers to look for:'),
              const SizedBox(height: 4),
              const _GoodRow(
                  ingredient: 'Fibre',
                  why: '≥ 3 g / 100 g is decent, ≥ 6 g is good.'),
              const _GoodRow(
                  ingredient: 'Protein',
                  why:
                      '≥ 8 g / 100 g is meaningful for solids — but ignore it when sugar > 15 g (junk in disguise).'),
              const _GoodRow(
                  ingredient: 'Fruit / veg / nuts content',
                  why: '≥ 40% is a clear positive.'),
              const SizedBox(height: 12),
              const _Note(
                  'Hidden math humans miss: sodium × 2.5 = salt (in grams). If the pack lists "sodium 480 mg" that\'s actually 1.2 g of salt — HIGH for 100 g.'),
            ],
          ),
          _Section(
            icon: Icons.precision_manufacturing_rounded,
            title: '5. Processing level — NOVA 1–4',
            subtitle:
                'The single best predictor of long-term health risk in packed food.',
            children: const [
              _NovaRow(
                num: 1,
                color: AppColors.good,
                title: 'Unprocessed / minimally processed',
                examples:
                    'Whole oats, plain milk, atta, fresh fruit, eggs',
              ),
              _NovaRow(
                num: 2,
                color: AppColors.okay,
                title: 'Processed culinary ingredients',
                examples: 'Sugar, salt, oil, ghee — used to cook with',
              ),
              _NovaRow(
                num: 3,
                color: AppColors.watch,
                title: 'Processed foods',
                examples:
                    'Cheese, fresh bread, canned veg in brine — whole foods + NOVA 2',
              ),
              _NovaRow(
                num: 4,
                color: AppColors.bad,
                title: 'Ultra-processed — industrial formulations',
                examples:
                    'Sodas, packaged biscuits, instant noodles, breakfast cereal, malt drinks, packaged snacks, "diet" / "low-fat" products',
              ),
              SizedBox(height: 6),
              _Note(
                'WHO meta-analyses link NOVA 4 intake to obesity, type-2 diabetes, cardiovascular disease, depression and all-cause mortality — independent of the nutrition profile. The more NOVA 4 in a diet, the worse the outcomes.',
              ),
            ],
          ),
          _Section(
            icon: Icons.science_rounded,
            title: '6. Additives — E / INS numbers',
            subtitle:
                'Most are harmless. Only a handful are flagged by global research.',
            children: const [
              _Note('High risk — avoid where possible:'),
              SizedBox(height: 6),
              _AdditiveRow(
                  codes: 'E102 / E104 / E110 / E122 / E124 / E129',
                  name: 'Synthetic azo dyes (tartrazine, sunset yellow, …)',
                  reason:
                      'Southampton-study hyperactivity warning required in EU.'),
              _AdditiveRow(
                  codes: 'E127',
                  name: 'Erythrosine (Red 3)',
                  reason:
                      'Banned in US food in 2025 — animal-study cancer signal.'),
              _AdditiveRow(
                  codes: 'E171',
                  name: 'Titanium dioxide',
                  reason:
                      'Banned as a food additive in EU (2022) — genotoxicity unresolved.'),
              _AdditiveRow(
                  codes: 'E249 / E250 / E251',
                  name: 'Nitrites & nitrates in cured meat',
                  reason:
                      'Form nitrosamines; processed-meat → IARC group 1 carcinogen.'),
              _AdditiveRow(
                  codes: 'E320 (BHA)',
                  name: 'Butylated Hydroxyanisole',
                  reason:
                      '"Reasonably anticipated to be a human carcinogen" — US NTP.'),
              SizedBox(height: 12),
              _Note('Moderate risk — limit:'),
              SizedBox(height: 6),
              _AdditiveRow(
                  codes: 'E150d',
                  name: 'Caramel colour',
                  reason: 'Can contain 4-MEI at high doses.'),
              _AdditiveRow(
                  codes: 'E211 / E220 / E223',
                  name: 'Benzoates & sulphites',
                  reason:
                      'With vitamin C can form benzene; asthma trigger.'),
              _AdditiveRow(
                  codes: 'E338',
                  name: 'Phosphoric acid',
                  reason:
                      'High intake linked to bone-density concerns.'),
              _AdditiveRow(
                  codes: 'E407 / E433 / E466 / E471',
                  name: 'Emulsifiers (carrageenan, polysorbate, CMC, mono-/diglycerides)',
                  reason:
                      'Gut-microbiome / inflammation studies; mono-/diglycerides can hide trans fats.'),
              _AdditiveRow(
                  codes: 'E621 / E627 / E631',
                  name: 'MSG family (glutamate, guanylate, inosinate)',
                  reason: 'Hidden sodium; gout caution.'),
              _AdditiveRow(
                  codes: 'E950 / E951 / E954 / E955',
                  name: 'Artificial sweeteners (acesulfame, aspartame, saccharin, sucralose)',
                  reason:
                      'WHO 2023: don\'t use for weight control. Aspartame: IARC "possibly carcinogenic".'),
              SizedBox(height: 12),
              _Note(
                  'Cumulative rule: 6+ additives in one product is itself a hallmark of ultra-processing — even if each is "low risk".'),
            ],
          ),
          _Section(
            icon: Icons.visibility_rounded,
            title: '7. Things humans spot that the engine misses',
            subtitle:
                'Eye-ball these on the pack before you buy.',
            children: const [
              _Note(
                  '• "100 g pack" trick — pack designed so a "serving" is the whole pack, hiding total sugar/sodium.\n'
                  '• Health-halo brand names ("ProBites", "Fit & Glow", "Aata Maggi") — brand name ≠ nutrition.\n'
                  '• Long shelf-life (12+ months) usually means heavy preservatives.\n'
                  '• Imported "fancy" foods aren\'t automatically healthier — but EU-made products often have cleaner formulations because EU labelling is stricter.\n'
                  '• Storage instructions saying "keep refrigerated / consume within 2 days" → less preserved → usually better.\n'
                  '• Allergens are declared in BOLD in India (milk, soy, wheat, peanut, tree nuts, eggs, fish, crustaceans, sulphites).\n'
                  '• If the pack shows a "Health Star Rating", cross-check with the actual ingredient list — that rating is calculated only from the nutrition panel.'),
            ],
          ),
          _Section(
            icon: Icons.verified_user_rounded,
            title: '8. What FSSAI requires on every packed food in India',
            subtitle:
                'If any of these is missing, the product is non-compliant — itself a red flag.',
            children: const [
              _Note(
                  '• Product name + brand\n'
                  '• Ingredient list in descending order of weight\n'
                  '• Nutritional information per 100 g / 100 ml AND per serving\n'
                  '• Veg / non-veg symbol (green / brown dot)\n'
                  '• Net weight or volume\n'
                  '• FSSAI licence number (14-digit code)\n'
                  '• Manufacturer / packer name and address\n'
                  '• Manufactured date + best-before / expiry\n'
                  '• Lot / batch number\n'
                  '• Country of origin (for imports)\n'
                  '• Allergens in bold\n'
                  '• Storage conditions\n'
                  '• Customer-care contact'),
            ],
          ),
        ];
}

// ============================================================================
// Quick / Full toggle
// ============================================================================

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<_Mode>(
        segments: const [
          ButtonSegment(
            value: _Mode.quick,
            label: Text('Quick'),
            icon: Icon(Icons.flash_on_rounded),
          ),
          ButtonSegment(
            value: _Mode.full,
            label: Text('Full'),
            icon: Icon(Icons.menu_book_rounded),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.seed.withValues(alpha: 0.18);
            }
            return Colors.white.withValues(alpha: 0.55);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.seed;
            }
            return AppColors.inkSoft;
          }),
        ),
      ),
    );
  }
}

class _DeepDiveHeader extends StatelessWidget {
  const _DeepDiveHeader();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28,
        height: 1.5,
        color: AppColors.inkSoft.withValues(alpha: 0.4),
      ),
      const SizedBox(width: 10),
      const Text('THE DEEP DIVE',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.inkSoft,
              letterSpacing: 1.4)),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 1.5,
          color: AppColors.inkSoft.withValues(alpha: 0.4),
        ),
      ),
    ]);
  }
}

// ============================================================================
// Quick essentials — the 80/20 of food-label literacy
// ============================================================================

class _QuickEssentials extends StatelessWidget {
  const _QuickEssentials();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.seed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.flash_on_rounded,
                    color: AppColors.seed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick essentials',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text(
                          '6 things to check, 60 seconds at the shelf.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                              height: 1.3)),
                    ]),
              ),
            ]),
            const SizedBox(height: 14),
            const _EssentialRow(
              n: 1,
              title: 'First 3 ingredients are the bulk',
              body:
                  'Open the back. If "refined wheat flour / maida", "sugar", or "palm oil" is in slot 1–3, it\'s junk food — no matter what the front says.',
              accent: AppColors.bad,
            ),
            const _EssentialRow(
              n: 2,
              title: 'Sugar per 100 g',
              body:
                  '> 13.5 g = high for solids. > 5 g = high for drinks. Multiply by your pack size for what you\'ll actually eat.',
              accent: AppColors.poor,
            ),
            const _EssentialRow(
              n: 3,
              title: 'Salt per 100 g',
              body:
                  '> 1.5 g = very high. If the pack only lists sodium in mg, multiply by 2.5 ÷ 1000 to get grams of salt.',
              accent: AppColors.watch,
            ),
            const _EssentialRow(
              n: 4,
              title: 'NOVA 4 = ultra-processed = avoid as habit',
              body:
                  'Spot it by: artificial flavour, artificial colour, hydrogenated fat, glucose / HFCS syrup, maltodextrin, or 5+ additives.',
              accent: AppColors.bad,
            ),
            const _EssentialRow(
              n: 5,
              title: 'Ignore these 3 words',
              body:
                  '"Natural" · "No added sugar" · "Multigrain". All unregulated in India — they tell you nothing about what\'s inside.',
              accent: AppColors.watch,
            ),
            const _EssentialRow(
              n: 6,
              title: 'FSSAI licence number must be there',
              body:
                  'Look for a 14-digit code on the pack. No FSSAI number = non-compliant = walk away.',
              accent: AppColors.good,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    size: 18, color: AppColors.seed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Or just scan it — FoodFat runs all six checks (and more) for you in a second.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.seed,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssentialRow extends StatelessWidget {
  const _EssentialRow({
    required this.n,
    required this.title,
    required this.body,
    required this.accent,
  });
  final int n;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$n',
              style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25)),
            const SizedBox(height: 3),
            Text(body,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================================
// Reusable components
// ============================================================================

class _PillarsHero extends StatelessWidget {
  const _PillarsHero();

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String label, String weight, Color color) =>
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(weight,
                    style: TextStyle(
                        color: color.withValues(alpha: 0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The 4-pillar score',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Every product is judged on these four things — combined into the final 0–100 % rating and the 0.5–5 star verdict.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(children: [
              pill(Icons.bar_chart_rounded, 'Nutrition', '35%',
                  AppColors.seed),
              pill(Icons.spa_rounded, 'Ingredients', '25%',
                  const Color(0xFFE67E22)),
              pill(Icons.precision_manufacturing_rounded, 'Processing', '20%',
                  AppColors.watch),
              pill(Icons.science_rounded, 'Additives', '20%', AppColors.poor),
            ]),
            const SizedBox(height: 12),
            const _Note(
                'No brand bias. No paid placements. The score is built from open science (Nutri-Score thresholds, NOVA classification, EFSA & IARC reviews, FSSAI rules).'),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.seed.withValues(alpha: 0.13),
              child: Icon(icon, size: 18, color: AppColors.seed),
            ),
            title: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkSoft, height: 1.3)),
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13, color: AppColors.ink, height: 1.45),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.word, required this.reality});
  final String word;
  final String reality;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded,
            size: 16, color: AppColors.watch),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(word,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            Text(reality,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _BadRow extends StatelessWidget {
  const _BadRow({required this.ingredient, required this.why});
  final String ingredient;
  final String why;
  @override
  Widget build(BuildContext context) {
    return _ColoredRow(
        icon: Icons.cancel_rounded,
        color: AppColors.bad,
        title: ingredient,
        body: why);
  }
}

class _GoodRow extends StatelessWidget {
  const _GoodRow({required this.ingredient, required this.why});
  final String ingredient;
  final String why;
  @override
  Widget build(BuildContext context) {
    return _ColoredRow(
        icon: Icons.check_circle_rounded,
        color: AppColors.good,
        title: ingredient,
        body: why);
  }
}

class _ColoredRow extends StatelessWidget {
  const _ColoredRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(body,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

class _ThresholdTable extends StatelessWidget {
  const _ThresholdTable({required this.rows, required this.headers});
  final List<List<String>> rows;
  final List<String> headers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _TableRow(values: headers, header: true),
          for (var i = 0; i < rows.length; i++)
            _TableRow(values: rows[i], header: false, even: i.isEven),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.values,
    required this.header,
    this.even = false,
  });
  final List<String> values;
  final bool header;
  final bool even;

  Color _cellTint(int i) {
    if (header) return Colors.transparent;
    // Color-grade the cells: lower is "good", higher columns are "bad"
    if (i == 0) return Colors.transparent;
    return switch (i) {
      1 => AppColors.good.withValues(alpha: 0.08),
      2 => AppColors.okay.withValues(alpha: 0.10),
      3 => AppColors.watch.withValues(alpha: 0.12),
      _ => AppColors.bad.withValues(alpha: 0.12),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: header
            ? Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)))
            : null,
        color: header
            ? AppColors.seed.withValues(alpha: 0.05)
            : (even ? null : Colors.black.withValues(alpha: 0.02)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: i == 0 ? 4 : 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding:
                    const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: BoxDecoration(
                  color: _cellTint(i),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  values[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: header || i == 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: header ? AppColors.seed : AppColors.ink,
                  ),
                  textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NovaRow extends StatelessWidget {
  const _NovaRow({
    required this.num,
    required this.color,
    required this.title,
    required this.examples,
  });
  final int num;
  final Color color;
  final String title;
  final String examples;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text('$num',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(examples,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _AdditiveRow extends StatelessWidget {
  const _AdditiveRow({
    required this.codes,
    required this.name,
    required this.reason,
  });
  final String codes;
  final String name;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.bad.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(codes,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bad)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            Text(reason,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is general information, not medical or dietary advice. Always read the actual pack and talk to a professional for anything that matters to you.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  height: 1.45,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ]),
      ),
    );
  }
}
