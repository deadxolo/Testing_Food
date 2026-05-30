import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

import '../services/history_service.dart';
import '../services/scan_service.dart';
import '../theme.dart';
import '../widgets/star_rating.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _history = HistoryService();
  late Future<List<ScanRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _history.getAll();
  }

  void _reload() {
    setState(() {
      _future = _history.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan history'),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text('This removes all saved scans on this device.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) {
                await _history.clear();
                _reload();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ScanRecord>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data!;
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No scans yet.\nScan a barcode or photograph a label to get started.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black45)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _HistoryTile(
              record: records[i],
              onTap: () async {
                final r = records[i];
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    result: ScanResult(r.product, r.report(),
                        notices: const ['From your scan history.']),
                  ),
                ));
              },
              onDelete: () async {
                await _history.remove(records[i].id);
                _reload();
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onTap, required this.onDelete});
  final ScanRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPercent(record.healthPercent);
    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 52, height: 52, child: _img()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((record.product.brand ?? '').isNotEmpty)
                  Text(record.product.brand!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                StarRating(value: record.stars, size: 14),
              ]),
            ),
            const SizedBox(width: 8),
            Column(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${record.healthPercent}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ),
            ]),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.black38),
              onPressed: onDelete,
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
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Container(
      color: Colors.black12,
      child: const Icon(Icons.fastfood_rounded, color: Colors.black38, size: 20));
}
