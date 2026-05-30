import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

import '../models/ad.dart';
import '../services/ads_service.dart';
import '../services/demo_seeder.dart';
import '../theme.dart';
import 'admin_ad_edit_screen.dart';
import 'admin_users_screen.dart';

/// Admin landing — visible only when the signed-in user is in the `admins/`
/// collection. Provides quick navigation to each admin feature plus a small
/// live dashboard at the top.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _DashboardCard(),
          const SizedBox(height: 14),
          _SectionTitle('Content'),
          const SizedBox(height: 8),
          _AdsCard(),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.bookmark_added_rounded,
            title: 'Featured products',
            subtitle: 'Pin products in the Store (coming next).',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Featured products UI is the next phase.')),
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle('People'),
          const SizedBox(height: 8),
          _NavCard(
            icon: Icons.people_alt_rounded,
            title: 'Users',
            subtitle: 'Browse signed-in users, last login & scan count.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminUsersScreen())),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Demo content'),
          const SizedBox(height: 8),
          const _SeederCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Seeder card
class _SeederCard extends StatefulWidget {
  const _SeederCard();
  @override
  State<_SeederCard> createState() => _SeederCardState();
}

class _SeederCardState extends State<_SeederCard> {
  bool _busy = false;

  Future<void> _run(
      String label, Future<int> Function() task, String unit) async {
    setState(() => _busy = true);
    try {
      final n = await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label: $n $unit')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_fix_high_rounded, color: AppColors.seed),
              const SizedBox(width: 8),
              Text('Seed sample data',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 4),
            Text(
              'One-tap fill so the app screens have real content while you '
              'demo it. Re-runnable — uses stable IDs so nothing duplicates.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run('Sample ads written',
                          DemoSeeder.instance.seedAds, 'ads'),
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Sample ads'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run('Sample scans added',
                          DemoSeeder.instance.seedSampleScans, 'scans'),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Sample scans'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _confirmClear(context),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Clear all ads'),
                style: TextButton.styleFrom(foregroundColor: AppColors.bad),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Wipe all ads?'),
        content: const Text(
            'This deletes every ad from Firestore. Useful for starting over.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run('Ads cleared', DemoSeeder.instance.clearAds, 'docs');
  }
}

// ---------------------------------------------------------------- Dashboard
class _DashboardCard extends StatelessWidget {
  const _DashboardCard();

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');
    final scans = FirebaseFirestore.instance.collection('scans');

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.dashboard_rounded, color: AppColors.seed),
            const SizedBox(width: 8),
            Text('Overview',
                style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _CountTile(query: users, label: 'Users')),
            const SizedBox(width: 10),
            Expanded(child: _CountTile(query: scans, label: 'Scans')),
            const SizedBox(width: 10),
            Expanded(
                child: _CountTile(
                    query: FirebaseFirestore.instance
                        .collection('ads')
                        .where('enabled', isEqualTo: true),
                    label: 'Live ads')),
          ]),
        ]),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.query, required this.label});
  final Query<Map<String, dynamic>> query;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.seed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StreamBuilder<AggregateQuerySnapshot>(
          // Aggregate query — cheap, server-side count, doesn't pull docs.
          stream: Stream.fromFuture(query.count().get()),
          builder: (context, snap) {
            final n = snap.data?.count ?? 0;
            return Text(
              snap.connectionState == ConnectionState.done ? '$n' : '…',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.seed),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
                letterSpacing: 0.8)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Ads tile
class _AdsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.campaign_rounded, color: AppColors.seed),
            title: const Text('Promo ads',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                const Text('Manage the cards shown on the home screen.'),
            trailing: IconButton(
              tooltip: 'New ad',
              icon: const Icon(Icons.add_circle_rounded),
              color: AppColors.seed,
              onPressed: () => _openEdit(context, null),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const _AdsListScreen())),
          ),
          StreamBuilder<List<Ad>>(
            stream: AdsService.instance.allAds(),
            builder: (context, snap) {
              final list = snap.data ?? const <Ad>[];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No ads yet. Tap + to add the first one.',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.good,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${list.where((a) => a.isLiveAt(DateTime.now())).length} live / ${list.length} total',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12.5),
                  ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }

  static Future<void> _openEdit(BuildContext context, Ad? ad) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => AdminAdEditScreen(ad: ad)));
}

// ---------------------------------------------------------------- Ads list
class _AdsListScreen extends StatelessWidget {
  const _AdsListScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo ads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            color: AppColors.seed,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminAdEditScreen(ad: null))),
          ),
        ],
      ),
      body: StreamBuilder<List<Ad>>(
        stream: AdsService.instance.allAds(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active &&
              snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? const <Ad>[];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_outlined,
                        size: 56, color: Colors.black26),
                    const SizedBox(height: 10),
                    Text('No ads yet',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('Tap + to create your first promo card.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _AdRow(ad: list[i]),
          );
        },
      ),
    );
  }
}

class _AdRow extends StatelessWidget {
  const _AdRow({required this.ad});
  final Ad ad;

  @override
  Widget build(BuildContext context) {
    final isLive = ad.isLiveAt(DateTime.now());
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AdminAdEditScreen(ad: ad))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLive ? AppColors.good : Colors.black26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(ad.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: Colors.black54)),
                const SizedBox(height: 6),
                Row(children: [
                  _MetaPill(
                      label: isLive ? 'LIVE' : (ad.enabled ? 'SCHEDULED' : 'OFF'),
                      color: isLive
                          ? AppColors.good
                          : (ad.enabled ? AppColors.watch : Colors.black38)),
                  const SizedBox(width: 6),
                  _MetaPill(
                      label: 'P ${ad.priority}', color: AppColors.seed),
                ]),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.bad,
              onPressed: () => _confirmDelete(context),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this ad?'),
        content: Text('“${ad.title}” will be removed for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await AdsService.instance.delete(ad.id);
    }
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7)),
    );
  }
}

// ---------------------------------------------------------------- helpers
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            letterSpacing: 1.2));
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: ListTile(
        leading: Icon(icon, color: AppColors.seed),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: onTap,
      ),
    );
  }
}
