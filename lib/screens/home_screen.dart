import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ad.dart';
import '../models/health_report.dart';
import '../services/ads_service.dart';
import '../services/history_service.dart';
import '../services/scan_flow.dart';
import '../services/scan_service.dart';
import '../theme.dart';
import '../widgets/star_rating.dart';
import 'history_screen.dart';
import 'result_screen.dart';
import 'store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _history = HistoryService();
  late Future<List<ScanRecord>> _recent;

  @override
  void initState() {
    super.initState();
    _recent = _history.getAll();
    HistoryService.updates.addListener(_refresh);
  }

  @override
  void dispose() {
    HistoryService.updates.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _recent = _history.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.eco_rounded, color: AppColors.seed),
          const SizedBox(width: 8),
          Text('FoodFat',
              style: Theme.of(context).appBarTheme.titleTextStyle),
        ]),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const _HeroBanner(),
            const SizedBox(height: 16),

            // ---- Action cards: Scan barcode + Photograph label
            Row(children: [
              Expanded(
                child: _ActionCard(
                  title: 'Scan Barcode',
                  subtitle: 'Fastest. Free via Open Food Facts.',
                  icon: Icons.qr_code_scanner_rounded,
                  primary: true,
                  onTap: () => startBarcodeScan(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Photograph\nLabel',
                  subtitle: 'No barcode? AI reads the pack.',
                  icon: Icons.photo_camera_rounded,
                  primary: false,
                  onTap: () => startPhotoCapture(context),
                ),
              ),
            ]),

            const SizedBox(height: 20),
            FutureBuilder<List<ScanRecord>>(
              future: _recent,
              builder: (context, snap) {
                final records = snap.data ?? const <ScanRecord>[];
                if (records.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Last scan',
                      action: 'See all',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const HistoryScreen())),
                    ),
                    const SizedBox(height: 8),
                    _SpotlightCard(record: records.first),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),

            // ---- Browse categories
            _SectionHeader(
              title: 'Browse',
              action: 'Open Store',
              onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreScreen())),
            ),
            const SizedBox(height: 10),
            const _Categories(),
            const SizedBox(height: 20),

            // ---- Promo / ad card (live from Firestore, falls back to a tip)
            _LiveAdsSlot(
              fallbackOnLearn: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreScreen())),
            ),
            const SizedBox(height: 20),

            // ---- More recent scans
            FutureBuilder<List<ScanRecord>>(
              future: _recent,
              builder: (context, snap) {
                final records = snap.data ?? const <ScanRecord>[];
                if (records.length <= 1) return const SizedBox.shrink();
                final rest = records.skip(1).take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('More from history',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...rest.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecentTile(record: r),
                        )),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),

            // ---- How it works (collapsible)
            _HowItWorks(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Hero
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.seed,
                  AppColors.seed.withValues(alpha: 0.78),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('REAL HEALTH SCANNER',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.2)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Is it really healthy?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan a pack and get the truth — health %, stars, and a line-by-line "why".',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: 13.5,
                      height: 1.35),
                ),
              ],
            ),
          ),
          // Decorative icon in corner
          Positioned(
            right: -14,
            top: -10,
            child: Icon(Icons.eco_rounded,
                color: Colors.white.withValues(alpha: 0.18), size: 130),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Action cards
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.seed : Colors.white;
    final fg = primary ? Colors.white : AppColors.ink;
    final subFg = primary
        ? Colors.white.withValues(alpha: 0.88)
        : AppColors.inkSoft;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: primary
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.seed.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon,
                    color: primary ? Colors.white : AppColors.seed, size: 22),
              ),
              const Spacer(),
              Text(title,
                  style: TextStyle(
                      color: fg,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: subFg, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Section header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const Spacer(),
      if (action != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(action!)),
    ]);
  }
}

// ---------------------------------------------------------------- Spotlight (last scan, big)
class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.record});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(record.healthPercent);
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: ScanResult(record.product, record.report(),
                notices: const ['From your scan history.']),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 96, height: 96, child: _img()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if ((record.product.brand ?? '').isNotEmpty)
                      Text(record.product.brand!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${record.healthPercent}',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    height: 1)),
                            Text('%',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StarRating(value: record.stars, size: 16),
                            const SizedBox(height: 4),
                            Text(record.verdict.short,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: record.verdict.color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _img() {
    final p = record.product;
    if (p.localImagePath != null && File(p.localImagePath!).existsSync()) {
      return Image.file(File(p.localImagePath!), fit: BoxFit.cover);
    }
    if ((p.imageUrl ?? '').isNotEmpty) {
      return Image.network(p.imageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Container(
      color: Colors.black12,
      child: const Icon(Icons.fastfood_rounded,
          color: Colors.black38, size: 26));
}

// ---------------------------------------------------------------- Categories
class _Categories extends StatelessWidget {
  const _Categories();

  static const _items = <_Cat>[
    _Cat('Biscuits', '🍪', 'biscuits', Color(0xFFFFE7C2)),
    _Cat('Chocolates', '🍫', 'chocolate', Color(0xFFE6CFB6)),
    _Cat('Drinks', '🥤', 'soda drink', Color(0xFFCDE6F8)),
    _Cat('Chips', '🍟', 'chips snacks', Color(0xFFFFD7C7)),
    _Cat('Cereal', '🥣', 'breakfast cereal', Color(0xFFE6D9F0)),
    _Cat('Noodles', '🍜', 'instant noodles', Color(0xFFFCE2A8)),
    _Cat('Juice', '🧃', 'fruit juice', Color(0xFFD7F0CD)),
    _Cat('Dairy', '🥛', 'milk yogurt', Color(0xFFE8F1FD)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = _items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StoreScreen(initialQuery: c.query),
            )),
            child: Container(
              width: 88,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cat {
  final String label;
  final String emoji;
  final String query;
  final Color bg;
  const _Cat(this.label, this.emoji, this.query, this.bg);
}

// ---------------------------------------------------------------- Live ads slot
class _LiveAdsSlot extends StatelessWidget {
  const _LiveAdsSlot({required this.fallbackOnLearn});
  final VoidCallback fallbackOnLearn;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ad>>(
      stream: AdsService.instance.liveAds(),
      builder: (context, snap) {
        final ads = snap.data ?? const <Ad>[];
        if (ads.isEmpty) {
          // No admin-published ad live right now — show the built-in tip.
          return _PromoCard(onLearn: fallbackOnLearn);
        }
        return Column(
          children: [
            for (final a in ads.take(2)) ...[
              _AdCard(ad: a),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad});
  final Ad ad;

  Future<void> _open() async {
    final url = ad.ctaUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: ad.ctaUrl == null ? null : _open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((ad.imageUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ad.imageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.seed.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: AppColors.seed),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(ad.body,
                        style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                            height: 1.35)),
                    if ((ad.ctaLabel ?? '').isNotEmpty &&
                        (ad.ctaUrl ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${ad.ctaLabel} →',
                          style: const TextStyle(
                              color: AppColors.seed,
                              fontWeight: FontWeight.w800)),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.onLearn});
  final VoidCallback onLearn;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFF3DC),
                  const Color(0xFFFFE7C2).withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6A609).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded,
                      color: Color(0xFF8A5A00), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Did you know?',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A5A00),
                              letterSpacing: 1.1)),
                      const SizedBox(height: 4),
                      const Text(
                        'Packs that say "natural", "healthy" or "no added sugar" still hide palm oil, refined flour, glucose syrup and artificial flavours every day.',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 13.5,
                            height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          onPressed: onLearn,
                          child: const Text('Try a few in Store →',
                              style: TextStyle(
                                  color: Color(0xFF8A5A00),
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Recent tile (compact)
class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.record});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(record.healthPercent);
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: ScanResult(record.product, record.report(),
                notices: const ['From your scan history.']),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(width: 44, height: 44, child: _img()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(children: [
                      StarRating(value: record.stars, size: 12),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(record.verdict.short,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: record.verdict.color)),
                      ),
                    ]),
                  ]),
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${record.healthPercent}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _img() {
    final p = record.product;
    if (p.localImagePath != null && File(p.localImagePath!).existsSync()) {
      return Image.file(File(p.localImagePath!), fit: BoxFit.cover);
    }
    if ((p.imageUrl ?? '').isNotEmpty) {
      return Image.network(p.imageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Container(
      color: Colors.black12,
      child: const Icon(Icons.fastfood_rounded,
          color: Colors.black38, size: 18));
}

// ---------------------------------------------------------------- How it works (collapsible)
class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.seed.withValues(alpha: 0.12),
              child: Icon(icon, size: 16, color: AppColors.seed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkSoft)),
              ]),
            ),
          ]),
        );

    return GlassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text('How it judges a product',
              style: Theme.of(context).textTheme.titleMedium),
          children: [
            step(Icons.inventory_2_outlined, 'Identifies it',
                'Barcode → Open Food Facts; otherwise reads your label photos with AI.'),
            step(Icons.list_alt_rounded, 'Reads the ingredients',
                'Flags palm oil, vanaspati/trans fat, maida, glucose-fructose syrup, artificial colour/flavour, MSG…'),
            step(Icons.science_outlined, 'Checks the additives',
                'Every E / INS number against a curated risk list (EFSA, IARC, FSSAI/EU rules).'),
            step(Icons.bar_chart_rounded, 'Weighs the nutrition',
                'Sugar, saturated fat, salt, calories vs. fibre, protein, fruit/veg — Nutri-Score style.'),
            step(Icons.precision_manufacturing_outlined,
                'Rates the processing',
                'NOVA scale 1–4: is it real food, or an industrial formulation?'),
            step(Icons.verified_outlined, 'Gives a verdict',
                'A 0–100% health score, 1–5 stars, a trust verdict, and a line-by-line "why".'),
          ],
        ),
      ),
    );
  }
}
