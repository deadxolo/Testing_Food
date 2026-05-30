import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductNotFoundException implements Exception {
  final String barcode;
  ProductNotFoundException(this.barcode);
  @override
  String toString() => 'Product $barcode not found in Open Food Facts';
}

/// Looks up barcodes against the free Open Food Facts database.
/// https://world.openfoodfacts.org/data
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _ua = {
    'User-Agent': 'FoodFat/1.0 (Flutter app; food trust scanner)'
  };

  // Only ask for the fields we actually use — keeps responses small & fast.
  static const _fields =
      'code,product_name,generic_name,brands,quantity,image_front_url,image_url,'
      'ingredients_text,ingredients_text_en,ingredients,additives_tags,'
      'nutriments,nova_group,nutriscore_grade,categories_tags';

  Future<Product> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=$_fields');
    final res = await _client.get(uri, headers: _ua).timeout(
          const Duration(seconds: 12),
        );
    if (res.statusCode == 404) throw ProductNotFoundException(code);
    if (res.statusCode != 200) {
      throw Exception('Open Food Facts error ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['product'] == null) {
      throw ProductNotFoundException(code);
    }
    return Product.fromOff(
      Map<String, dynamic>.from(body['product'] as Map),
      barcode: code,
    );
  }

  /// Best-effort text search (used as a fallback when the user typed a name).
  Future<List<Product>> searchByName(String query, {int pageSize = 20}) async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeQueryComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=$pageSize&fields=$_fields');
    final res = await _client.get(uri, headers: _ua).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['products'] as List?) ?? [];
    return list
        .whereType<Map>()
        .map((m) => Product.fromOff(Map<String, dynamic>.from(m),
            barcode: (m['code'] ?? '').toString()))
        .where((p) => p.name.trim().isNotEmpty && p.name != 'Unknown product')
        .toList();
  }

  /// Popular packaged products to seed the Store browse feed. Sorted by how
  /// often they're scanned, biased toward Indian shelves.
  Future<List<Product>> popularProducts({int pageSize = 30}) async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?action=process'
        '&tagtype_0=countries&tag_contains_0=contains&tag_0=india'
        '&sort_by=unique_scans_n'
        '&page_size=$pageSize&json=1&fields=$_fields');
    final res = await _client.get(uri, headers: _ua).timeout(
          const Duration(seconds: 15),
        );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['products'] as List?) ?? [];
    return list
        .whereType<Map>()
        .map((m) => Product.fromOff(Map<String, dynamic>.from(m),
            barcode: (m['code'] ?? '').toString()))
        .where((p) => p.name.trim().isNotEmpty && p.name != 'Unknown product')
        .toList();
  }

  void dispose() => _client.close();
}
