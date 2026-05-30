import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

import '../models/health_report.dart';
import '../models/product.dart';
import '../services/bundled_catalog.dart';
import '../services/open_food_facts_service.dart';
import '../services/scan_service.dart';
import '../services/scoring_engine.dart';
import '../theme.dart';
import '../widgets/star_rating.dart';
import 'result_screen.dart';

/// "Store" / browse tab — search the Open Food Facts community database by
/// product name or brand, or browse a feed of popular packed foods. A filter
/// button inside the search bar narrows results by health verdict.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.initialQuery});

  /// If supplied, the search field is pre-filled with this and a search is
  /// run automatically on first build.
  final String? initialQuery;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

enum _HealthBand { all, trust, okay, careful, poor, avoid }

extension on _HealthBand {
  String get label => switch (this) {
        _HealthBand.all => 'All types',
        _HealthBand.trust => 'Trustworthy',
        _HealthBand.okay => 'Okay',
        _HealthBand.careful => 'Be careful',
        _HealthBand.poor => 'Poor',
        _HealthBand.avoid => 'Avoid',
      };

  String get blurb => switch (this) {
        _HealthBand.all => 'All health bands',
        _HealthBand.trust => '80%+ — clean ingredients, solid nutrition',
        _HealthBand.okay => '62–79% — generally fine, watch portions',
        _HealthBand.careful => '45–61% — has real downsides',
        _HealthBand.poor => '25–44% — junk food territory',
        _HealthBand.avoid => '<25% — avoid where you can',
      };

  bool accepts(int pct) => switch (this) {
        _HealthBand.all => true,
        _HealthBand.trust => pct >= 80,
        _HealthBand.okay => pct >= 62 && pct < 80,
        _HealthBand.careful => pct >= 45 && pct < 62,
        _HealthBand.poor => pct >= 25 && pct < 45,
        _HealthBand.avoid => pct < 25,
      };

  Color get color => switch (this) {
        _HealthBand.trust => AppColors.good,
        _HealthBand.okay => AppColors.okay,
        _HealthBand.careful => AppColors.watch,
        _HealthBand.poor => AppColors.poor,
        _HealthBand.avoid => AppColors.bad,
        _HealthBand.all => AppColors.seed,
      };
}

class _StoreScreenState extends State<StoreScreen> {
  final _ctrl = TextEditingController();
  final _off = OpenFoodFactsService();
  final _engine = ScoringEngine();

  Future<List<Product>>? _future;
  String _lastQuery = '';
  _HealthBand _band = _HealthBand.all;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _ctrl.text = q;
      _lastQuery = q;
      _future = _fetchSearch(q);
    } else {
      _future = _fetchPopular();
    }
  }

  /// Online-first feed. Hits Open Food Facts (real product photos + barcodes),
  /// falls back to the bundled catalog if the network is unreachable.
  Future<List<Product>> _fetchPopular() async {
    try {
      final off = await _off.popularProducts(pageSize: 60);
      if (off.isNotEmpty) return off;
    } catch (_) {}
    return BundledCatalog.instance.popular();
  }

  Future<List<Product>> _fetchSearch(String q) async {
    try {
      final off = await _off.searchByName(q, pageSize: 40);
      if (off.isNotEmpty) return off;
    } catch (_) {}
    return BundledCatalog.instance.search(q);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _off.dispose();
    super.dispose();
  }

  void _runSearch([String? q]) {
    final query = (q ?? _ctrl.text).trim();
    if (query.isEmpty) {
      setState(() {
        _lastQuery = '';
        _future = _fetchPopular();
      });
      return;
    }
    if (query.length < 2) return;
    _ctrl.text = query;
    _ctrl.selection = TextSelection.collapsed(offset: query.length);
    setState(() {
      _lastQuery = query;
      _future = _fetchSearch(query);
    });
  }

  Future<void> _open(Product p, HealthReport r) async {
    final result = ScanResult(p, r,
        notices: const ['Opened from Store search.']);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
    );
  }

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<_HealthBand>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      builder: (_) => _FilterSheet(current: _band),
    );
    if (picked != null && picked != _band) {
      setState(() => _band = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: Column(
        children: [
          _SearchBar(
            controller: _ctrl,
            band: _band,
            onSubmit: _runSearch,
            onFilter: _pickFilter,
            onClearText: () {
              _ctrl.clear();
              _runSearch();
            },
          ),
          if (_band != _HealthBand.all)
            _ActiveFilterStrip(
              band: _band,
              onClear: () => setState(() => _band = _HealthBand.all),
            ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: 'Search failed — check your connection.',
                    onRetry: () => _lastQuery.isEmpty
                        ? _runSearch()
                        : _runSearch(_lastQuery),
                  );
                }
                final all = snap.data ?? const [];
                if (all.isEmpty) {
                  return _EmptyView(query: _lastQuery);
                }
                final scored = <(Product, HealthReport)>[
                  for (final p in all) (p, _engine.analyse(p)),
                ];
                final filtered = scored
                    .where((e) => _band.accepts(e.$2.healthPercent))
                    .toList();
                if (filtered.isEmpty) {
                  return _EmptyFilterView(
                    band: _band,
                    onReset: () => setState(() => _band = _HealthBand.all),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _future = _lastQuery.isEmpty
                          ? _fetchPopular()
                          : _fetchSearch(_lastQuery);
                    });
                    await _future;
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: _lastQuery.isEmpty
                                ? 'Popular packed foods'
                                : 'Results for "$_lastQuery"',
                            count: filtered.length,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.74,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final (p, r) = filtered[i];
                              return _ResultCard(
                                product: p,
                                percent: r.healthPercent,
                                stars: r.stars,
                                onTap: () => _open(p, r),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.band,
    required this.onSubmit,
    required this.onFilter,
    required this.onClearText,
  });

  final TextEditingController controller;
  final _HealthBand band;
  final void Function([String?]) onSubmit;
  final VoidCallback onFilter;
  final VoidCallback onClearText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          final active = band != _HealthBand.all;
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => onSubmit(v),
            decoration: InputDecoration(
              hintText: 'Search a product or brand…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: onClearText,
                    ),
                  _FilterPill(
                    active: active,
                    onTap: onFilter,
                    band: band,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.seed.withValues(alpha: 0.4)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.active,
    required this.onTap,
    required this.band,
  });

  final bool active;
  final VoidCallback onTap;
  final _HealthBand band;

  @override
  Widget build(BuildContext context) {
    final color = active ? band.color : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: active
            ? band.color.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  active ? band.label : 'Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterStrip extends StatelessWidget {
  const _ActiveFilterStrip({required this.band, required this.onClear});
  final _HealthBand band;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: band.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: band.color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_rounded, size: 14, color: band.color),
            const SizedBox(width: 6),
            Text(band.label,
                style: TextStyle(
                    color: band.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const SizedBox(width: 6),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: Icon(Icons.close, size: 14, color: band.color),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current});
  final _HealthBand current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _HealthBand _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by health',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Show products that score in this health band.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ..._HealthBand.values.map((b) {
              final selected = _selected == b;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selected = b),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? b.color
                            : Colors.black.withValues(alpha: 0.08),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: b.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              b.blurb,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? b.color : Colors.black26,
                      ),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_HealthBand.all),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Apply'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count',
            style: const TextStyle(
                color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.product,
    required this.percent,
    required this.stars,
    required this.onTap,
  });

  final Product product;
  final int percent;
  final double stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(percent);
    final emoji = _emojiFor(product);
    final bg = _bgFor(product);

    return GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----- Image / emoji canvas with score badge
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (product.imageUrl ?? '').isNotEmpty
                          ? Image.network(product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _EmojiBg(emoji: emoji, color: bg))
                          : _EmojiBg(emoji: emoji, color: bg),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.32),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text('$percent',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ----- Text area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.2)),
                        if ((product.brand ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(product.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StarRating(value: stars, size: 11),
                        if ((product.quantity ?? '').isNotEmpty)
                          Text(product.quantity!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colourful pastel background with a big category emoji in the centre —
/// the "image" for products that don't carry a remote imageUrl (i.e. our
/// bundled catalog).
class _EmojiBg extends StatelessWidget {
  const _EmojiBg({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
    );
  }
}

String _emojiFor(Product p) {
  final hay = [
    ...p.categories.map((c) => c.toLowerCase()),
    p.name.toLowerCase(),
    (p.brand ?? '').toLowerCase(),
  ].join(' ');
  bool any(List<String> needles) => needles.any(hay.contains);
  if (any(['biscuit', 'cookie', 'wafer', 'cracker'])) {
    return '🍪';
  }
  if (any(
      ['chocolate', 'candy', 'truffle', 'kitkat', 'munch', 'dairy milk'])) {
    return '🍫';
  }
  if (any([
    'mithai',
    'ladoo',
    'rasgulla',
    'soan papdi',
    'kaju katli',
    'gulab jamun'
  ])) {
    return '🍮';
  }
  if (any([
    'cola',
    'soda',
    'pepsi',
    'sprite',
    'limca',
    'mountain dew',
    'soft-drink',
    'soft drink'
  ])) {
    return '🥤';
  }
  if (any(['juice', 'maaza', 'frooti', 'real', 'tropicana', 'slice', 'appy'])) {
    return '🧃';
  }
  if (any([
    'nutritional',
    'bourn vita',
    'horlicks',
    'boost',
    'complan',
    'pediasure',
    'protinex',
    'ensure',
    'malt'
  ])) {
    return '🥄';
  }
  if (any([
    'chip',
    'crisps',
    'kurkure',
    'bhujia',
    'namkeen',
    'snack',
    'lay',
    'bingo',
    'pringles',
    'nachos'
  ])) {
    return '🍟';
  }
  if (any(['cereal', 'cornflake', 'muesli', 'granola', 'oats'])) {
    return '🥣';
  }
  if (any(['noodle', 'maggi', 'pasta', 'macaroni', 'ramen', 'instant'])) {
    return '🍜';
  }
  if (any(['bread', 'bun', 'roll', 'loaf', 'bakery', 'pav', 'sandwich'])) {
    return '🍞';
  }
  if (any([
    'jam',
    'spread',
    'nutella',
    'peanut butter',
    'mayonnaise',
    'sauce',
    'ketchup',
    'mustard'
  ])) {
    return '🥫';
  }
  if (any([
    'milk',
    'yogurt',
    'curd',
    'cheese',
    'paneer',
    'dahi',
    'lassi',
    'buttermilk'
  ])) {
    return '🥛';
  }
  return '🛒';
}

Color _bgFor(Product p) {
  const palette = [
    Color(0xFFFFE7C2),
    Color(0xFFE6CFB6),
    Color(0xFFCDE6F8),
    Color(0xFFFFD7C7),
    Color(0xFFE6D9F0),
    Color(0xFFFCE2A8),
    Color(0xFFD7F0CD),
    Color(0xFFE8F1FD),
    Color(0xFFFFE3F1),
  ];
  return palette[(p.name.hashCode.abs()) % palette.length];
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
              hasQuery
                  ? 'Nothing found for "$query"'
                  : 'No products to show',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            hasQuery
                ? "Try a different spelling, the brand instead of the product, or scan the pack's barcode directly."
                : 'Check your connection and pull to refresh.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView({required this.band, required this.onReset});
  final _HealthBand band;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off_rounded, size: 56, color: band.color),
          const SizedBox(height: 12),
          Text('No products in the "${band.label}" band',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try widening the filter or searching for something specific.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
              onPressed: onReset, child: const Text('Show all types')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48, color: Colors.black26),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}
