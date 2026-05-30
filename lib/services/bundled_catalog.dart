import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/product.dart';

/// Loads the bundled catalog of ~1,300 packaged-food products that ships with
/// the app (`assets/data/products_seed.json`). Used by the Store screen as
/// an instant default feed and a free offline search index — no network or
/// Firestore reads needed.
class BundledCatalog {
  BundledCatalog._();
  static final BundledCatalog instance = BundledCatalog._();

  List<Product>? _all;
  Future<List<Product>>? _loading;

  /// Ensures the catalog is loaded into memory and returns the full list.
  Future<List<Product>> all() {
    if (_all != null) return Future.value(_all);
    return _loading ??= _load();
  }

  Future<List<Product>> _load() async {
    final raw = await rootBundle.loadString('assets/data/products_seed.json');
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final list = (doc['products'] as List? ?? const [])
        .whereType<Map>()
        .map((m) {
      final j = Map<String, dynamic>.from(m);
      // The Product.fromOff loader expects OFF-style fields with `_100g`
      // suffixes for nutriments. Our bundled JSON uses already-normalised
      // names that match Product.fromJson, so reuse that.
      return Product.fromJson({
        'barcode': j['barcode'],
        'name': j['name'],
        'brand': j['brand'],
        'quantity': j['quantity'],
        'ingredients': j['ingredients'],
        'ingredientsText': j['ingredientsText'],
        'additiveCodes': j['additiveCodes'],
        'nutriments': j['nutriments'],
        'novaGroup': j['novaGroup'],
        'categories': j['categories'],
        'source': 'openFoodFacts',
      });
    }).toList(growable: false);
    _all = list;
    return list;
  }

  /// Substring search across name + brand. Returns at most [limit] results,
  /// scored by where the query matches (name-start > brand-start > anywhere).
  Future<List<Product>> search(String query, {int limit = 50}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    final list = await all();
    final hits = <(int, Product)>[];
    for (final p in list) {
      final name = p.name.toLowerCase();
      final brand = (p.brand ?? '').toLowerCase();
      int score;
      if (name.startsWith(q)) {
        score = 0;
      } else if (brand.startsWith(q)) {
        score = 1;
      } else if (name.contains(q) || brand.contains(q)) {
        score = 2;
      } else {
        continue;
      }
      hits.add((score, p));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return hits.take(limit).map((e) => e.$2).toList(growable: false);
  }

  /// All products in a given OFF-style category tag (e.g. `en:biscuits`).
  Future<List<Product>> byCategory(String tag, {int limit = 100}) async {
    final list = await all();
    final t = tag.toLowerCase();
    return list
        .where((p) => p.categories.any((c) => c.toLowerCase().contains(t)))
        .take(limit)
        .toList(growable: false);
  }

  /// A small shuffled "popular" feed for the Store default state.
  Future<List<Product>> popular({int count = 60}) async {
    final list = [...await all()]..shuffle();
    return list.take(count).toList(growable: false);
  }
}
