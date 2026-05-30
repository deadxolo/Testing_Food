import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/additives_db.dart';
import '../models/health_report.dart';
import '../models/product.dart';
import '../services/scan_service.dart';
import '../services/share_capture.dart';
import '../theme.dart';
import '../widgets/flag_chip.dart';
import '../widgets/glass_panel.dart';
import '../widgets/pillar_panel.dart';
import '../widgets/score_gauge.dart';
import '../widgets/share_card.dart';
import '../widgets/star_rating.dart';
import 'how_we_judge_screen.dart';

enum _ShareChoice { image, text }

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});
  final ScanResult result;

  Product get product => result.product;
  HealthReport get report => result.report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health report'),
        actions: [
          IconButton(
            tooltip: 'How we judge it',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HowWeJudgeScreen())),
          ),
          IconButton(
            tooltip: 'Share report',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProductHeader(product: product),
          const SizedBox(height: 14),
          _VerdictCard(report: report),
          const SizedBox(height: 14),
          PillarPanel(pillars: report.pillars),
          const SizedBox(height: 14),
          _ProcessingRow(report: report),
          if (result.notices.isNotEmpty) ...[
            const SizedBox(height: 14),
            _NoticesCard(notices: result.notices),
          ],
          if (report.marketingClaims.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ClaimsCard(report: report),
          ],
          const SizedBox(height: 14),
          _SummaryCard(text: report.summary, confidence: report.confidence),
          if (report.flags.where((f) => !_positiveFlag(f.flag.id)).isNotEmpty) ...[
            const SizedBox(height: 14),
            _FlagsCard(report: report),
          ],
          if (report.additives.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AdditivesCard(report: report),
          ],
          if (!product.nutriments.isEmpty) ...[
            const SizedBox(height: 14),
            _NutritionCard(n: product.nutriments),
          ],
          const SizedBox(height: 14),
          _BreakdownCard(report: report),
          if ((product.ingredientsText ?? '').trim().isNotEmpty ||
              product.ingredients.isNotEmpty) ...[
            const SizedBox(height: 14),
            _IngredientsCard(product: product),
          ],
          const SizedBox(height: 18),
          const _SourcesFooter(),
        ],
      ),
    );
  }

  static bool _positiveFlag(String id) =>
      id == 'whole_grain' || id == 'real_fruit';

  // ---------------------------------------------------------------- share
  Future<void> _share(BuildContext context) async {
    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share as image'),
              subtitle: const Text('Poster-style PNG with score, stars & reasons'),
              onTap: () => Navigator.pop(ctx, _ShareChoice.image),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share as text'),
              subtitle: const Text('Plain summary for chat apps & SMS'),
              onTap: () => Navigator.pop(ctx, _ShareChoice.text),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _ShareChoice.image) {
      await _shareImage(context);
    } else {
      await _shareText(context);
    }
  }

  Future<void> _shareText(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: _buildShareText(),
        subject: '${product.name} — FoodFat health check',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    // Show a brief spinner while the card renders + encodes.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Uint8List? png;
    Object? error;
    try {
      png = await captureCardToPng(
        context,
        card: ShareCard(product: product, report: report),
      );
    } catch (e) {
      error = e;
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss spinner

    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build share image: $error')),
      );
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    final safeName = product.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final file = XFile.fromData(
      png,
      mimeType: 'image/png',
      name: '${safeName.isEmpty ? 'foodfat' : safeName}-health.png',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text:
            '${report.healthPercent}% • ${report.verdict.short} — ${product.name}',
        subject: '${product.name} — FoodFat health check',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  String _buildShareText() {
    String stars5(double s) {
      final full = s.floor();
      final half = (s - full) >= 0.5 ? 1 : 0;
      final empty = 5 - full - half;
      return ('★' * full) + (half == 1 ? '½' : '') + ('☆' * empty);
    }

    final lines = <String>[];
    lines.add('🥦 FoodFat health check');
    lines.add('');
    final title = product.brand != null && product.brand!.isNotEmpty
        ? '${product.name} — ${product.brand}'
        : product.name;
    lines.add(title);
    lines.add(
        'Health: ${report.healthPercent}% • ${stars5(report.stars)} (${report.stars.toStringAsFixed(1)}/5)');
    lines.add('Verdict: ${report.verdict.short}');
    lines.add(
        'Processing: NOVA ${report.novaGroup}/4 • Nutrition grade ${report.nutriGrade.toUpperCase()}');
    lines.add('');

    // Top reasons (worst penalties + key flags)
    final reasons = <String>[];
    for (final f in report.penalties.take(5)) {
      reasons.add('• ${f.label}');
    }
    if (reasons.isEmpty && report.bonuses.isNotEmpty) {
      reasons.add('• Clean ingredient list, reasonable nutrition');
    }
    if (reasons.isNotEmpty) {
      lines.add('Why:');
      lines.addAll(reasons);
      lines.add('');
    }

    // High-risk additives, if any
    final highRisk = report.additives
        .where((e) => e.value?.risk == AdditiveRisk.high)
        .map((e) => '${e.value!.name} (${e.key.toUpperCase()})')
        .toList();
    if (highRisk.isNotEmpty) {
      lines.add('High-risk additives: ${highRisk.join(', ')}');
      lines.add('');
    }

    if (report.marketingClaims.isNotEmpty &&
        (report.verdict == Verdict.careful ||
            report.verdict == Verdict.poor ||
            report.verdict == Verdict.avoid)) {
      lines.add(
          '⚠️ The pack uses words like "${report.marketingClaims.take(3).join('", "')}" — but the ingredients tell a different story.');
      lines.add('');
    }

    lines.add('— Scanned with FoodFat 🌱');
    return lines.join('\n');
  }
}

// ---------------------------------------------------------------- header
class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final img = _imageWidget();
    final srcLabel = switch (product.source) {
      ProductSource.openFoodFacts => 'Open Food Facts',
      ProductSource.aiVision => 'AI-read label',
      ProductSource.manual => 'Manual',
    };
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 76, height: 76, child: img),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  if ((product.brand ?? '').isNotEmpty)
                    Text(product.brand!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.inkSoft)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if ((product.quantity ?? '').isNotEmpty)
                      _MiniTag(product.quantity!),
                    if ((product.barcode ?? '').isNotEmpty)
                      _MiniTag('#${product.barcode}'),
                    _MiniTag(srcLabel,
                        color: product.source == ProductSource.aiVision
                            ? AppColors.watch
                            : AppColors.okay),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageWidget() {
    if (product.localImagePath != null && File(product.localImagePath!).existsSync()) {
      return Image.file(File(product.localImagePath!), fit: BoxFit.cover);
    }
    if ((product.imageUrl ?? '').isNotEmpty) {
      return Image.network(product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _ImgPlaceholder());
    }
    return const _ImgPlaceholder();
  }
}

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black12,
        child: const Icon(Icons.fastfood_rounded, color: Colors.black38),
      );
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

// ---------------------------------------------------------------- verdict
class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final v = report.verdict;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      blurSigma: 22,
      child: Column(
        children: [
          ScoreGauge(percent: report.healthPercent),
          const SizedBox(height: 12),
          StarRating(value: report.stars, size: 26, showValue: true),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(v.icon, color: v.color, size: 20),
              const SizedBox(width: 8),
              Text(v.short,
                  style: TextStyle(
                      color: v.color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(v.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- processing row
class _ProcessingRow extends StatelessWidget {
  const _ProcessingRow({required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _NovaTile(report.novaGroup, report.novaEstimated)),
      const SizedBox(width: 12),
      Expanded(child: _NutriGradeTile(report.nutriGrade)),
    ]);
  }
}

class _NovaTile extends StatelessWidget {
  const _NovaTile(this.group, this.estimated);
  final int group;
  final bool estimated;
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (group) {
      1 => (AppColors.good, 'Unprocessed'),
      2 => (AppColors.okay, 'Processed culinary'),
      3 => (AppColors.watch, 'Processed'),
      _ => (AppColors.bad, 'Ultra-processed'),
    };
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PROCESSING (NOVA)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text('$group',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$label${estimated ? '\n(estimated)' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _NutriGradeTile extends StatelessWidget {
  const _NutriGradeTile(this.grade);
  final String grade; // a..e
  @override
  Widget build(BuildContext context) {
    final colors = {
      'a': const Color(0xFF1E8E3E),
      'b': const Color(0xFF7CB342),
      'c': const Color(0xFFF6A609),
      'd': const Color(0xFFEF6C00),
      'e': const Color(0xFFD32F2F),
    };
    final c = colors[grade] ?? Colors.grey;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NUTRITION GRADE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.black45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: c, borderRadius: BorderRadius.circular(9)),
              child: Text(grade.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  switch (grade) {
                    'a' => 'Best nutritional quality',
                    'b' => 'Good',
                    'c' => 'Average',
                    'd' => 'Poor',
                    _ => 'Worst nutritional quality',
                  },
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- notices
class _NoticesCard extends StatelessWidget {
  const _NoticesCard({required this.notices});
  final List<String> notices;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: notices
              .map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: Icon(Icons.info_outline,
                            size: 16, color: Colors.black45),
                      ),
                      Expanded(
                          child: Text(t,
                              style: Theme.of(context).textTheme.bodySmall)),
                    ]),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- claims
class _ClaimsCard extends StatelessWidget {
  const _ClaimsCard({required this.report});
  final HealthReport report;
  @override
  Widget build(BuildContext context) {
    final positive =
        report.verdict == Verdict.trust || report.verdict == Verdict.okay;
    return GlassCard(
      color: positive ? const Color(0xFFE7F4EA) : const Color(0xFFFFF3DC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(positive ? Icons.verified : Icons.warning_amber_rounded,
                color: positive ? AppColors.good : AppColors.watch),
            const SizedBox(width: 8),
            Text(positive ? 'Claims check out' : 'Health-washing watch',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: report.marketingClaims
                .map((c) => Chip(
                      label: Text('"$c"'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            positive
                ? 'The pack uses these words and the ingredients & nutrition broadly support them.'
                : 'The pack leans on these words, but the ingredient list / nutrition tell a more processed story. Read the details below.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- summary
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.text, required this.confidence});
  final String text;
  final double confidence;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('In short', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35)),
          if (confidence < 0.7) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.help_outline, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lower confidence — some data (e.g. nutrition table or processing level) was missing or estimated.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- flags
class _FlagsCard extends StatelessWidget {
  const _FlagsCard({required this.report});
  final HealthReport report;
  @override
  Widget build(BuildContext context) {
    final hits = report.flags
        .where((f) => f.flag.id != 'whole_grain' && f.flag.id != 'real_fruit')
        .toList()
      ..sort((a, b) => a.flag.severity.index.compareTo(b.flag.severity.index) * -1);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.flag_rounded, color: AppColors.poor),
            const SizedBox(width: 8),
            Text('Ingredient red flags (${hits.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          for (final h in hits)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FlagChip(label: h.flag.label, severity: h.flag.severity),
                const SizedBox(height: 4),
                Text(h.flag.why,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkSoft)),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- additives
class _AdditivesCard extends StatelessWidget {
  const _AdditivesCard({required this.report});
  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    Color riskColor(AdditiveRisk? r) => switch (r) {
          AdditiveRisk.high => AppColors.bad,
          AdditiveRisk.moderate => AppColors.watch,
          AdditiveRisk.low => AppColors.okay,
          null => Colors.black38,
        };
    String riskLabel(AdditiveRisk? r) => switch (r) {
          AdditiveRisk.high => 'HIGH RISK',
          AdditiveRisk.moderate => 'WATCH',
          AdditiveRisk.low => 'LOW RISK',
          null => 'UNKNOWN',
        };

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.science_rounded, color: Colors.black54),
            const SizedBox(width: 8),
            Text('Additives (${report.additives.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 4),
          Text('E / INS numbers found on the label.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54)),
          const SizedBox(height: 10),
          for (final e in report.additives)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: riskColor(e.value?.risk).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(e.key.toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: riskColor(e.value?.risk))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              e.value?.name ?? 'Additive ${e.key.toUpperCase()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(riskLabel(e.value?.risk),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: riskColor(e.value?.risk))),
                        ]),
                        if (e.value != null)
                          Text('${e.value!.klass} · ${e.value!.note}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkSoft))
                        else
                          Text('Not in our risk list — look it up before deciding.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- nutrition
class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.n});
  final Nutriments n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (n.energyKcal != null)
        _row(context, 'Energy', '${n.energyKcal!.round()} kcal',
            _band(n.energyKcal!, 350, 450)),
      if (n.sugars != null)
        _row(context, 'Sugars', _g(n.sugars!), _band(n.sugars!, 5, 13.5)),
      if (n.saturatedFat != null)
        _row(context, 'Saturated fat', _g(n.saturatedFat!),
            _band(n.saturatedFat!, 1.5, 5)),
      if (n.fat != null) _row(context, 'Total fat', _g(n.fat!), 0),
      if (n.salt != null)
        _row(context, 'Salt', _g(n.salt!), _band(n.salt!, 0.3, 1.5)),
      if (n.fiber != null)
        _row(context, 'Fibre', _g(n.fiber!), n.fiber! >= 3 ? -1 : 0),
      if (n.proteins != null)
        _row(context, 'Protein', _g(n.proteins!), n.proteins! >= 8 ? -1 : 0),
      if (n.fruitsVegNuts != null)
        _row(context, 'Fruit / veg / nuts', '${n.fruitsVegNuts!.round()} %',
            n.fruitsVegNuts! >= 40 ? -1 : 0),
    ];
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: Colors.black54),
            const SizedBox(width: 8),
            Text('Nutrition (per 100 g / ml)',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 10),
          ...rows,
        ]),
      ),
    );
  }

  // -1 = good, 0 = neutral, 1 = med, 2 = high
  int _band(double v, double med, double high) =>
      v >= high ? 2 : (v >= med ? 1 : 0);

  Widget _row(BuildContext context, String label, String value, int band) {
    final color = switch (band) {
      -1 => AppColors.good,
      1 => AppColors.watch,
      2 => AppColors.bad,
      _ => Colors.black54,
    };
    final tag = switch (band) {
      -1 => 'good',
      1 => 'a bit high',
      2 => 'high',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label)),
        if (tag != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(6)),
            child: Text(tag,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right),
      ]),
    );
  }

  static String _g(double v) =>
      (v == v.roundToDouble()) ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';
}

// ---------------------------------------------------------------- breakdown
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.report});
  final HealthReport report;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Why this score', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Starts at 100, then…',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54)),
          const SizedBox(height: 10),
          for (final f in report.factors) _factorRow(context, f),
          const Divider(height: 24),
          Row(children: [
            Text('= ${report.healthPercent}% health',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.forPercent(report.healthPercent))),
            const Spacer(),
            StarRating(value: report.stars, size: 18),
          ]),
        ]),
      ),
    );
  }

  Widget _factorRow(BuildContext context, ScoreFactor f) {
    final positive = f.points > 0;
    final neutral = f.points == 0;
    final color = neutral
        ? Colors.black54
        : positive
            ? AppColors.good
            : (f.points <= -12 ? AppColors.bad : AppColors.poor);
    final pts = neutral
        ? '·'
        : (positive ? '+${f.points}' : '${f.points}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 36,
          child: Text(pts,
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(f.detail,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkSoft)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- ingredients
class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final text = (product.ingredientsText ?? '').trim().isNotEmpty
        ? product.ingredientsText!.trim()
        : product.ingredients.join(', ');
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          title: Text('Full ingredient list',
              style: Theme.of(context).textTheme.titleMedium),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- footer
class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter();
  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where this comes from', style: style?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _link('Open Food Facts (ODbL)', 'https://world.openfoodfacts.org'),
          _link('Nutri-Score', 'https://www.santepubliquefrance.fr/en/nutri-score'),
          _link('NOVA classification', 'https://world.openfoodfacts.org/nova'),
          _link('FSSAI', 'https://fssai.gov.in'),
        ]),
        const SizedBox(height: 10),
        Text(
          'Product data comes from the Open Food Facts community database and, when read from your photos, from an AI model — both can be incomplete or wrong. '
          'Scores are computed on-device from Nutri-Score-style nutrition thresholds, the NOVA processing scale, and a curated additive-risk list (EFSA re-evaluations, IARC notes, FSSAI/EU rules). '
          'This is general information, not medical or dietary advice — check the actual pack and talk to a professional for anything that matters.',
          style: style,
        ),
      ],
    );
  }

  Widget _link(String label, String url) => InkWell(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.seed,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                fontSize: 12)),
      );
}
