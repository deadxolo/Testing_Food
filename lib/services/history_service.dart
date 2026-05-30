import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_report.dart';
import '../models/product.dart';
import 'scoring_engine.dart';

/// A saved scan: the product plus enough of the report to re-display a card
/// without recomputing (we still recompute the full report on open).
class ScanRecord {
  final String id;
  final DateTime scannedAt;
  final Product product;
  final int healthPercent;
  final double stars;
  final Verdict verdict;

  ScanRecord({
    required this.id,
    required this.scannedAt,
    required this.product,
    required this.healthPercent,
    required this.stars,
    required this.verdict,
  });

  factory ScanRecord.create(Product product, HealthReport report) => ScanRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        scannedAt: DateTime.now(),
        product: product,
        healthPercent: report.healthPercent,
        stars: report.stars,
        verdict: report.verdict,
      );

  /// Recompute the full report from the stored product.
  HealthReport report() => ScoringEngine().analyse(product);

  Map<String, dynamic> toJson() => {
        'id': id,
        'scannedAt': scannedAt.toIso8601String(),
        'product': product.toJson(),
        'healthPercent': healthPercent,
        'stars': stars,
        'verdict': verdict.name,
      };

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
        id: j['id'] as String,
        scannedAt:
            DateTime.tryParse(j['scannedAt'] as String? ?? '') ?? DateTime.now(),
        product: Product.fromJson(Map<String, dynamic>.from(j['product'] as Map)),
        healthPercent: (j['healthPercent'] as num?)?.toInt() ?? 0,
        stars: (j['stars'] as num?)?.toDouble() ?? 0,
        verdict: Verdict.values.firstWhere((v) => v.name == j['verdict'],
            orElse: () => Verdict.careful),
      );
}

class HistoryService {
  static const _key = 'scan_history_v1';
  static const _max = 200;

  /// Bumped on every add/remove/clear so other widgets can listen for changes
  /// without polling. Useful for the home screen's "recent scans" list when a
  /// scan happens via the bottom-nav Scan tab (no callback to wire up).
  static final ValueNotifier<int> updates = ValueNotifier<int>(0);

  Future<List<ScanRecord>> getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => ScanRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ScanRecord record) async {
    final all = await getAll();
    // de-dupe by barcode (keep newest)
    all.removeWhere((r) =>
        record.product.barcode != null &&
        r.product.barcode == record.product.barcode);
    all.insert(0, record);
    final trimmed = all.take(_max).toList();
    await _save(trimmed);
    updates.value++;
  }

  Future<void> remove(String id) async {
    final all = await getAll()..removeWhere((r) => r.id == id);
    await _save(all);
    updates.value++;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    updates.value++;
  }

  Future<void> _save(List<ScanRecord> records) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}
