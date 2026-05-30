import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/glass_card.dart';
import 'how_we_judge_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeroCard(),
          const SizedBox(height: 14),
          _HowWeJudgeCta(),
          const SizedBox(height: 14),
          _Section(
            title: 'What it does',
            body:
                'FoodFat scans packed food & drinks and tells you how healthy / trustworthy they really are. '
                'Instead of waiting for a "foodfat" creator to make a video on the chocolate you just bought, '
                'you get an instant, transparent verdict — a health %, a star rating, and a line-by-line "why".',
          ),
          _Section(
            title: 'How the score is built',
            body:
                'The score starts at 100 and is adjusted by:\n\n'
                '• NOVA processing level (1 = whole food … 4 = ultra-processed)\n'
                '• Nutrition (sugar, saturated fat, salt, energy density vs. fibre, protein, fruit/veg/nuts) using Nutri-Score thresholds\n'
                '• A curated additive-risk list (E / INS numbers) covering colours, preservatives, sweeteners, emulsifiers and more\n'
                '• Ingredient red-flags — palm oil, vanaspati/trans fat, maida, glucose-fructose syrup, artificial flavour & colour, MSG, named preservatives, artificial sweeteners\n'
                '• A "health-washing" check — if the pack uses words like "healthy / natural / no added sugar" but the ingredients say otherwise, that gets called out',
          ),
          _Section(
            title: 'Where the data comes from',
            body:
                'Two paths:\n\n'
                '1. Barcode → Open Food Facts (the open, community-built food database, ODbL).\n'
                '2. No barcode / not in the database → photograph the label and Google Gemini\'s vision model reads it.\n\n'
                'The additive risk list blends EU re-evaluations (EFSA), IARC monographs, FSSAI rules and well-known concerns from food-safety groups.',
          ),
          const SizedBox(height: 4),
          _LinksCard(),
          const SizedBox(height: 14),
          _Section(
            title: 'Disclaimer',
            body:
                'This is general information, not medical or dietary advice. '
                'Open Food Facts entries are crowd-sourced and can be incomplete or out of date. '
                'AI-read labels can be wrong. Always read the actual pack, and consult a professional for anything that matters.',
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'FoodFat · MVP v1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black38, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.seed.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.seed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FoodFat', style: Theme.of(context).textTheme.titleLarge),
              Text('Cut through the packaging.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkSoft)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Big tappable card that takes the user to the full "How we judge it"
/// explainer. Sits high on About so newcomers see it before the rest.
class _HowWeJudgeCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const HowWeJudgeScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.seed, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How we judge a product',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'The 4 pillars, ingredient red flags, additive risk, FSSAI rules — everything the engine checks, in plain English.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft, height: 1.4),
                    ),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget link(String label, String url, IconData icon) => InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(children: [
              Icon(icon, color: AppColors.seed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.open_in_new, size: 16, color: Colors.black38),
            ]),
          ),
        );

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sources & references',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          link('Open Food Facts (ODbL database)',
              'https://world.openfoodfacts.org', Icons.public_rounded),
          link('Nutri-Score (Santé Publique France)',
              'https://www.santepubliquefrance.fr/en/nutri-score',
              Icons.grading_rounded),
          link('NOVA food classification',
              'https://world.openfoodfacts.org/nova',
              Icons.precision_manufacturing_outlined),
          link('FSSAI (India)', 'https://fssai.gov.in', Icons.verified_outlined),
          link('Google Gemini API', 'https://ai.google.dev/',
              Icons.auto_awesome_rounded),
        ]),
      ),
    );
  }
}
