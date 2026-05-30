/// One-shot generator: builds `assets/data/products_seed.json` — a bundled
/// catalog of ~500+ packaged-food products used as the default Store feed.
///
/// Each product is composed from a brand × product-type cross with realistic
/// per-category nutrition + ingredient profiles. Re-runnable: deterministic
/// random seed → identical output, so JSON diffs are reviewable.
///
/// Usage:
///   dart run tool/gen_products.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

final rng = Random(42);

class Category {
  final String key; // matches our ProductCategory enum keys roughly
  final List<String> offTags; // OFF category tags (drives detector)
  final List<String> brands;
  final List<String> products;
  final List<String> sizes;
  final List<String> ingredients;
  final List<String> additives;
  final int nova;
  // Nutrition jitter ranges: [min, max] per100g/ml
  final List<double> sugar;
  final List<double> satFat;
  final List<double> salt;
  final List<double> energy;
  final List<double> protein;
  final List<double> fiber;

  Category({
    required this.key,
    required this.offTags,
    required this.brands,
    required this.products,
    required this.sizes,
    required this.ingredients,
    required this.additives,
    required this.nova,
    required this.sugar,
    required this.satFat,
    required this.salt,
    required this.energy,
    required this.protein,
    required this.fiber,
  });
}

final categories = <Category>[
  // ---------- BISCUITS / COOKIES (~60 products) ----------------------------
  Category(
    key: 'biscuit',
    offTags: ['en:biscuits', 'en:cookies'],
    brands: [
      'Parle', 'Britannia', 'Sunfeast', 'Anmol', 'Priya Gold',
      'McVitie\'s', 'Unibic', 'Cadbury', 'Bisk Farm'
    ],
    products: [
      'Glucose Biscuits', 'Marie Gold', 'Bourbon', 'Cream', 'Coconut Crunch',
      'Choco Chip', 'Digestive', 'Hide & Seek', 'Cashew Cookies', 'Butter Bake'
    ],
    sizes: ['50 g', '75 g', '110 g', '150 g', '200 g', '300 g'],
    ingredients: [
      'refined wheat flour (maida)', 'sugar', 'edible vegetable oil (palm)',
      'invert syrup', 'milk solids', 'raising agents', 'salt',
      'emulsifier (E322)', 'artificial flavour'
    ],
    additives: ['e322', 'e500'],
    nova: 4,
    sugar: [16, 32],
    satFat: [4, 9],
    salt: [0.4, 0.9],
    energy: [430, 500],
    protein: [5, 8],
    fiber: [1, 3],
  ),

  // ---------- CHOCOLATES / CONFECTIONERY (~50) -----------------------------
  Category(
    key: 'chocolate',
    offTags: ['en:chocolates', 'en:confectionery'],
    brands: [
      'Cadbury', 'Nestlé', 'Amul', 'Hershey\'s', 'Ferrero',
      'Mars', 'Lindt', 'Lotte'
    ],
    products: [
      'Dairy Milk', 'Silk Bubbly', 'Crackle', '5 Star', 'Munch',
      'KitKat', 'Milky Bar', 'Choco Bar', 'Truffle', 'Hazelnut'
    ],
    sizes: ['12 g', '25 g', '42 g', '65 g', '110 g'],
    ingredients: [
      'sugar', 'milk solids', 'cocoa butter', 'cocoa solids',
      'edible vegetable oil', 'emulsifier (soya lecithin)',
      'artificial flavour'
    ],
    additives: ['e322', 'e476'],
    nova: 4,
    sugar: [40, 58],
    satFat: [9, 18],
    salt: [0.1, 0.5],
    energy: [500, 580],
    protein: [4, 8],
    fiber: [1, 4],
  ),

  // ---------- BEVERAGES — sodas + juices + RTD (~80) ------------------------
  Category(
    key: 'beverage',
    offTags: ['en:beverages', 'en:soft-drinks'],
    brands: [
      'Coca-Cola', 'Pepsi', 'Thums Up', 'Sprite', 'Limca', 'Maaza',
      'Slice', 'Real', 'Tropicana', 'Frooti', 'Appy Fizz', 'Mountain Dew'
    ],
    products: [
      'Original', 'Diet', 'Zero', 'Mango', 'Orange', 'Mixed Fruit',
      'Cola', 'Lemon', 'Litchi'
    ],
    sizes: ['200 ml', '250 ml', '330 ml', '500 ml', '1.25 L', '2 L'],
    ingredients: [
      'carbonated water', 'sugar', 'acidity regulator (E338)',
      'caramel colour (E150d)', 'natural and artificial flavours', 'caffeine'
    ],
    additives: ['e150d', 'e338'],
    nova: 4,
    sugar: [4, 13],
    satFat: [0, 0.2],
    salt: [0, 0.05],
    energy: [25, 60],
    protein: [0, 0.5],
    fiber: [0, 0.5],
  ),

  // ---------- CHIPS / SAVOURY SNACKS (~60) ----------------------------------
  Category(
    key: 'chips',
    offTags: ['en:chips-and-fries', 'en:salty-snacks'],
    brands: [
      'Lay\'s', 'Bingo', 'Kurkure', 'Haldiram\'s', 'Pringles', 'Too Yumm',
      'Uncle Chipps', 'Balaji', 'Doritos'
    ],
    products: [
      'Salted', 'Magic Masala', 'Cream & Onion', 'Tomato Tango', 'Spicy Treat',
      'Chilli Lemon', 'Aloo Bhujia', 'Nachos', 'Mast Masala'
    ],
    sizes: ['25 g', '40 g', '60 g', '90 g', '150 g'],
    ingredients: [
      'potatoes', 'edible vegetable oil (palm)', 'salt', 'spices',
      'flavour enhancer (E621)', 'acidity regulator (E330)',
      'artificial colour', 'maltodextrin'
    ],
    additives: ['e621', 'e330', 'e627', 'e631'],
    nova: 4,
    sugar: [1, 5],
    satFat: [5, 14],
    salt: [1.2, 2.4],
    energy: [500, 580],
    protein: [5, 8],
    fiber: [2, 5],
  ),

  // ---------- CEREALS / BREAKFAST (~30) -------------------------------------
  Category(
    key: 'cereal',
    offTags: ['en:breakfast-cereals'],
    brands: ['Kellogg\'s', 'Bagrry\'s', 'MTR', 'Nestlé', 'Quaker', 'Saffola'],
    products: [
      'Cornflakes', 'Muesli', 'Choco Pops', 'Oats', 'Granola',
      'Multigrain Flakes', 'Honey Crunch'
    ],
    sizes: ['200 g', '375 g', '500 g', '1 kg'],
    ingredients: [
      'whole grain oats', 'sugar', 'wheat', 'maize',
      'salt', 'barley malt extract', 'iron', 'vitamins'
    ],
    additives: [],
    nova: 3,
    sugar: [4, 22],
    satFat: [0.5, 4],
    salt: [0.2, 0.9],
    energy: [350, 420],
    protein: [7, 14],
    fiber: [4, 11],
  ),

  // ---------- NOODLES / INSTANT (~40) ---------------------------------------
  Category(
    key: 'noodle',
    offTags: ['en:instant-noodles', 'en:pasta'],
    brands: [
      'Maggi', 'Yippee', 'Top Ramen', 'Wai-Wai', 'Knorr', 'Ching\'s',
      'Patanjali'
    ],
    products: [
      'Masala', 'Chicken', 'Veg Atta', 'Curry', 'Schezwan', 'Manchurian',
      'Hot & Spicy'
    ],
    sizes: ['70 g', '140 g', '280 g', '560 g'],
    ingredients: [
      'wheat flour (maida)', 'palm oil', 'salt', 'wheat gluten',
      'acidity regulators (E501, E500)', 'thickener (E412)', 'spices',
      'flavour enhancer (E621)', 'sugar'
    ],
    additives: ['e501', 'e500', 'e412', 'e621'],
    nova: 4,
    sugar: [3, 8],
    satFat: [6, 12],
    salt: [3.5, 6.5],
    energy: [430, 510],
    protein: [8, 11],
    fiber: [2, 4],
  ),

  // ---------- BREAD / BAKERY (~30) -----------------------------------------
  Category(
    key: 'bread',
    offTags: ['en:breads', 'en:bakery'],
    brands: ['Modern', 'Britannia', 'Harvest Gold', 'Bonn', 'English Oven'],
    products: [
      'White Bread', 'Brown Bread', 'Multigrain', 'Whole Wheat', 'Pav',
      'Sandwich Loaf', 'Atta Bread'
    ],
    sizes: ['200 g', '400 g', '700 g'],
    ingredients: [
      'refined wheat flour', 'water', 'sugar', 'edible vegetable oil',
      'yeast', 'salt', 'preservative (E282)', 'emulsifier (E471)'
    ],
    additives: ['e282', 'e471'],
    nova: 3,
    sugar: [3, 8],
    satFat: [0.4, 1.4],
    salt: [0.9, 1.4],
    energy: [240, 290],
    protein: [7, 11],
    fiber: [2, 7],
  ),

  // ---------- SPREADS / SAUCES (~30) ---------------------------------------
  Category(
    key: 'spread',
    offTags: ['en:spreads', 'en:sauces'],
    brands: [
      'Kissan', 'Maggi', 'Heinz', 'Veeba', 'Nutella', 'Sundrop',
      'Funfoods', 'Pintola'
    ],
    products: [
      'Tomato Ketchup', 'Mixed Fruit Jam', 'Mayonnaise', 'Mustard Sauce',
      'Peanut Butter', 'Hazelnut Spread', 'Chilli Sauce', 'Cheese Spread'
    ],
    sizes: ['100 g', '200 g', '340 g', '500 g', '1 kg'],
    ingredients: [
      'sugar', 'fruit pulp', 'edible vegetable oil',
      'acidity regulators (E260, E330)', 'salt', 'thickener (E415)',
      'preservative (E211)', 'colour (E150c)'
    ],
    additives: ['e260', 'e330', 'e415', 'e211', 'e150c'],
    nova: 4,
    sugar: [20, 55],
    satFat: [0.5, 12],
    salt: [0.5, 2.5],
    energy: [200, 540],
    protein: [1, 22],
    fiber: [0.5, 5],
  ),

  // ---------- DAIRY (~50) ----------------------------------------------------
  Category(
    key: 'dairy',
    offTags: ['en:dairies', 'en:yogurts'],
    brands: [
      'Amul', 'Mother Dairy', 'Nestlé', 'Epigamia', 'Britannia', 'Yoga Bar'
    ],
    products: [
      'Greek Yogurt', 'Curd Cup', 'Flavoured Milk', 'Buttermilk', 'Lassi',
      'Cheese Slice', 'Paneer', 'Probiotic Drink'
    ],
    sizes: ['90 g', '180 g', '200 ml', '500 ml', '1 L', '200 g'],
    ingredients: [
      'pasteurised toned milk', 'milk solids', 'sugar', 'starter cultures',
      'fruit pulp', 'acidity regulator (E330)', 'stabilisers (E440, E412)'
    ],
    additives: ['e330', 'e440', 'e412'],
    nova: 3,
    sugar: [3, 16],
    satFat: [1.5, 6],
    salt: [0.1, 1.2],
    energy: [70, 200],
    protein: [3, 12],
    fiber: [0, 1],
  ),

  // ---------- "Health" food / drinks (~40) ---------------------------------
  Category(
    key: 'beverage',
    offTags: ['en:nutritional-drinks', 'en:beverages'],
    brands: [
      'Bourn Vita', 'Horlicks', 'Boost', 'Complan', 'PediaSure',
      'Protinex', 'Ensure'
    ],
    products: [
      'Original', 'Chocolate', '5 Star Magic', 'Pro Health',
      'Classic Malt', 'Junior', 'Mom & Me'
    ],
    sizes: ['200 g', '500 g', '750 g', '1 kg'],
    ingredients: [
      'malt extract', 'sugar', 'cocoa solids', 'milk solids',
      'minerals', 'vitamins', 'emulsifier (E322)', 'flavour'
    ],
    additives: ['e322'],
    nova: 4,
    sugar: [25, 45],
    satFat: [1, 5],
    salt: [0.4, 1.2],
    energy: [380, 440],
    protein: [6, 14],
    fiber: [1, 4],
  ),

  // ---------- Mithai / Indian sweets (~30) ----------------------------------
  Category(
    key: 'chocolate',
    offTags: ['en:indian-sweets', 'en:confectionery'],
    brands: [
      'Haldiram\'s', 'Bikanervala', 'Surati', 'MTR', 'Anand'
    ],
    products: [
      'Soan Papdi', 'Kaju Katli', 'Gulab Jamun', 'Rasgulla', 'Mysore Pak',
      'Motichoor Ladoo', 'Besan Ladoo'
    ],
    sizes: ['200 g', '500 g', '1 kg'],
    ingredients: [
      'sugar', 'gram flour (besan)', 'edible vegetable oil',
      'milk solids', 'cashew', 'cardamom', 'glucose syrup'
    ],
    additives: [],
    nova: 3,
    sugar: [30, 55],
    satFat: [8, 16],
    salt: [0.05, 0.4],
    energy: [430, 520],
    protein: [5, 10],
    fiber: [1, 4],
  ),
];

String genBarcode() {
  final rest = List.generate(10, (_) => rng.nextInt(10)).join();
  return '890$rest';
}

double jitter(List<double> range, [double widening = 0]) {
  final lo = range[0] - widening;
  final hi = range[1] + widening;
  return double.parse((lo + rng.nextDouble() * (hi - lo)).toStringAsFixed(2));
}

void main() {
  final out = <Map<String, dynamic>>[];

  for (final c in categories) {
    for (final brand in c.brands) {
      for (final p in c.products) {
        // Two size variants per brand × product → keeps total above 500.
        final pickedSizes =
            [...c.sizes]..shuffle(rng);
        final variantsToMake = min(2, pickedSizes.length);
        for (var i = 0; i < variantsToMake; i++) {
          final size = pickedSizes[i];
          final name = '$brand $p';
          out.add({
            'barcode': genBarcode(),
            'name': name,
            'brand': brand,
            'quantity': size,
            'categories': c.offTags,
            'ingredientsText': '${c.ingredients.join(', ')}.',
            'ingredients': c.ingredients,
            'additiveCodes': c.additives,
            'nutriments': {
              'energyKcal': jitter(c.energy),
              'sugars': jitter(c.sugar),
              'saturatedFat': jitter(c.satFat),
              'salt': jitter(c.salt),
              'proteins': jitter(c.protein),
              'fiber': jitter(c.fiber),
            },
            'novaGroup': c.nova,
          });
        }
      }
    }
  }

  final file = File('assets/data/products_seed.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode({
    'version': 1,
    'generatedAt': DateTime.now().toIso8601String(),
    'count': out.length,
    'products': out,
  }));
  stdout.writeln('✅ wrote ${file.path} — ${out.length} products');
}
