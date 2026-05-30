/// Nutrition facts, normalised to "per 100 g / 100 ml".
class Nutriments {
  final double? energyKcal; // kcal per 100g
  final double? sugars; // g
  final double? saturatedFat; // g
  final double? fat; // g
  final double? salt; // g  (salt = sodium * 2.5)
  final double? sodium; // g
  final double? fiber; // g
  final double? proteins; // g
  final double? fruitsVegNuts; // % estimate, 0-100

  const Nutriments({
    this.energyKcal,
    this.sugars,
    this.saturatedFat,
    this.fat,
    this.salt,
    this.sodium,
    this.fiber,
    this.proteins,
    this.fruitsVegNuts,
  });

  bool get isEmpty =>
      energyKcal == null &&
      sugars == null &&
      saturatedFat == null &&
      salt == null &&
      fiber == null &&
      proteins == null;

  factory Nutriments.fromOff(Map<String, dynamic> n) {
    double? read(String key) {
      final v = n[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final salt = read('salt_100g');
    final sodium = read('sodium_100g');
    return Nutriments(
      energyKcal: read('energy-kcal_100g') ?? read('energy_100g'),
      sugars: read('sugars_100g'),
      saturatedFat: read('saturated-fat_100g'),
      fat: read('fat_100g'),
      salt: salt ?? (sodium != null ? sodium * 2.5 : null),
      sodium: sodium ?? (salt != null ? salt / 2.5 : null),
      fiber: read('fiber_100g'),
      proteins: read('proteins_100g'),
      fruitsVegNuts:
          read('fruits-vegetables-nuts-estimate-from-ingredients_100g') ??
              read('fruits-vegetables-nuts_100g'),
    );
  }

  factory Nutriments.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return Nutriments(
      energyKcal: d('energyKcal'),
      sugars: d('sugars'),
      saturatedFat: d('saturatedFat'),
      fat: d('fat'),
      salt: d('salt'),
      sodium: d('sodium'),
      fiber: d('fiber'),
      proteins: d('proteins'),
      fruitsVegNuts: d('fruitsVegNuts'),
    );
  }

  Map<String, dynamic> toJson() => {
        'energyKcal': energyKcal,
        'sugars': sugars,
        'saturatedFat': saturatedFat,
        'fat': fat,
        'salt': salt,
        'sodium': sodium,
        'fiber': fiber,
        'proteins': proteins,
        'fruitsVegNuts': fruitsVegNuts,
      };
}

enum ProductSource { openFoodFacts, aiVision, manual }

/// A scanned packed-food product.
class Product {
  final String? barcode;
  final String name;
  final String? brand;
  final String? imageUrl; // remote (OFF) image
  final String? localImagePath; // photo the user took
  final String? quantity; // e.g. "200 g"
  final List<String> ingredients; // cleaned ingredient tokens, in order
  final String? ingredientsText; // raw text as printed
  final List<String> additiveCodes; // e.g. ["e150d", "e322"]
  final Nutriments nutriments;
  final int? novaGroup; // 1..4 if known
  final String? nutriScoreGrade; // a..e if known
  final ProductSource source;
  final List<String> categories;

  const Product({
    this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.localImagePath,
    this.quantity,
    this.ingredients = const [],
    this.ingredientsText,
    this.additiveCodes = const [],
    this.nutriments = const Nutriments(),
    this.novaGroup,
    this.nutriScoreGrade,
    this.source = ProductSource.manual,
    this.categories = const [],
  });

  factory Product.fromOff(Map<String, dynamic> p, {required String barcode}) {
    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

    final ingredientsList = (p['ingredients'] is List)
        ? (p['ingredients'] as List)
            .map((e) => (e is Map ? (e['text'] ?? e['id'] ?? '') : '').toString())
            .where((s) => s.trim().isNotEmpty)
            .toList()
        : <String>[];

    return Product(
      barcode: barcode,
      name: (p['product_name'] ?? p['generic_name'] ?? 'Unknown product')
          .toString()
          .trim(),
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      imageUrl: p['image_front_url'] as String? ?? p['image_url'] as String?,
      quantity: p['quantity'] as String?,
      ingredients: ingredientsList,
      ingredientsText:
          p['ingredients_text_en'] as String? ?? p['ingredients_text'] as String?,
      additiveCodes: strList(p['additives_tags'])
          .map((t) => t.replaceAll('en:', '').toLowerCase())
          .toList(),
      nutriments: p['nutriments'] is Map
          ? Nutriments.fromOff(Map<String, dynamic>.from(p['nutriments']))
          : const Nutriments(),
      novaGroup: (p['nova_group'] is num)
          ? (p['nova_group'] as num).toInt()
          : int.tryParse('${p['nova_group']}'),
      nutriScoreGrade: (p['nutriscore_grade'] as String?)?.toLowerCase(),
      source: ProductSource.openFoodFacts,
      categories: strList(p['categories_tags'])
          .map((t) => t.replaceAll('en:', '').replaceAll('-', ' '))
          .toList(),
    );
  }

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        barcode: j['barcode'] as String?,
        name: j['name'] as String? ?? 'Unknown product',
        brand: j['brand'] as String?,
        imageUrl: j['imageUrl'] as String?,
        localImagePath: j['localImagePath'] as String?,
        quantity: j['quantity'] as String?,
        ingredients:
            (j['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? [],
        ingredientsText: j['ingredientsText'] as String?,
        additiveCodes:
            (j['additiveCodes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        nutriments: j['nutriments'] is Map
            ? Nutriments.fromJson(Map<String, dynamic>.from(j['nutriments']))
            : const Nutriments(),
        novaGroup: j['novaGroup'] as int?,
        nutriScoreGrade: j['nutriScoreGrade'] as String?,
        source: ProductSource.values.firstWhere(
          (s) => s.name == j['source'],
          orElse: () => ProductSource.manual,
        ),
        categories:
            (j['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'imageUrl': imageUrl,
        'localImagePath': localImagePath,
        'quantity': quantity,
        'ingredients': ingredients,
        'ingredientsText': ingredientsText,
        'additiveCodes': additiveCodes,
        'nutriments': nutriments.toJson(),
        'novaGroup': novaGroup,
        'nutriScoreGrade': nutriScoreGrade,
        'source': source.name,
        'categories': categories,
      };

  /// One big lower-cased blob of all ingredient text, for keyword matching.
  String get ingredientsBlob {
    final parts = <String>[
      ?ingredientsText,
      ...ingredients,
    ];
    return parts.join(' , ').toLowerCase();
  }
}
