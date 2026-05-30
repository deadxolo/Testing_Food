import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import 'auth_service.dart';
import 'history_service.dart';
import 'scoring_engine.dart';

/// One-tap demo content seeder used from the admin panel. Lets you populate
/// `ads/` in Firestore and the local scan-history with a curated set of
/// items so the app screens look "lived in" out of the box. Re-runnable —
/// uses stable doc IDs so a second tap updates the same docs instead of
/// duplicating them.
class DemoSeeder {
  DemoSeeder._();
  static final DemoSeeder instance = DemoSeeder._();

  // ----------------------------------------------------------------- ads
  Future<int> seedAds() async {
    if (!AuthService.instance.isReady) {
      throw StateError('Firebase not ready — sign in first.');
    }
    final uid = AuthService.instance.currentUser?.uid ?? 'demo-seeder';
    final col = FirebaseFirestore.instance.collection('ads');
    final batch = FirebaseFirestore.instance.batch();
    for (final a in _kDemoAds) {
      batch.set(
        col.doc(a['id'] as String),
        {
          ...a,
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }..remove('id'),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return _kDemoAds.length;
  }

  // ---------------------------------------------------------------- scans
  /// Adds a handful of representative scans to the *local* history. They
  /// each show a different verdict band so the home / history screens are
  /// visually interesting.
  Future<int> seedSampleScans() async {
    final engine = ScoringEngine();
    final history = HistoryService();
    int n = 0;
    for (final p in _kDemoProducts) {
      final r = engine.analyse(p);
      await history.add(ScanRecord.create(p, r));
      n++;
    }
    return n;
  }

  /// Wipes every doc in `ads/` (admin only). For starting over fresh.
  Future<int> clearAds() async {
    final col = FirebaseFirestore.instance.collection('ads');
    final snap = await col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }
}

// ---------------------------------------------------------------------------
// Demo content. Tweak freely — re-running the seeder syncs by doc id.
// ---------------------------------------------------------------------------
final List<Map<String, dynamic>> _kDemoAds = [
  {
    'id': 'welcome-card',
    'title': '🥦 Welcome to FoodFat',
    'body':
        'Scan any packed food and get an instant health verdict — backed by '
        'Nutri-Score, NOVA & a curated additive risk list.',
    'enabled': true,
    'priority': 10,
    'ctaLabel': null,
    'ctaUrl': null,
  },
  {
    'id': 'health-washing-watch',
    'title': 'Spot "healthy" marketing tricks',
    'body':
        'Words like "natural", "wholesome", "no added sugar" don\'t protect '
        'you from palm oil, maida or glucose syrup. Search a few in the Store.',
    'enabled': true,
    'priority': 8,
    'ctaLabel': 'See examples',
    'ctaUrl': 'https://world.openfoodfacts.org/category/biscuits',
  },
  {
    'id': 'nova-explainer',
    'title': 'What is NOVA 4?',
    'body':
        'NOVA 4 = ultra-processed: industrial formulations of refined extracts '
        'and additives. The more NOVA 4 you eat, the harder your body works.',
    'enabled': true,
    'priority': 6,
    'ctaLabel': 'Learn the NOVA scale',
    'ctaUrl': 'https://world.openfoodfacts.org/nova',
  },
  {
    'id': 'scan-maggi',
    'title': 'Try scanning a popular product',
    'body': 'Pick a packet of Maggi, Lay\'s or Bourn Vita and see how the four pillars stack up.',
    'enabled': true,
    'priority': 4,
    'ctaLabel': null,
    'ctaUrl': null,
  },
  {
    'id': 'sample-promo-disabled',
    'title': '(Demo) Coming soon — Premium tips',
    'body':
        'This card is intentionally disabled so you can see what an off-air ad looks like in the Admin list.',
    'enabled': false,
    'priority': 1,
    'ctaLabel': null,
    'ctaUrl': null,
  },
];

final List<Product> _kDemoProducts = [
  // Trustworthy
  const Product(
    name: 'Rolled Oats',
    brand: 'Quaker',
    quantity: '500 g',
    categories: ['en:cereals', 'en:oats'],
    ingredientsText: 'Whole grain oats.',
    ingredients: ['whole grain oats'],
    nutriments: Nutriments(
      energyKcal: 379,
      sugars: 1.0,
      saturatedFat: 1.2,
      salt: 0.01,
      fiber: 10,
      proteins: 13,
    ),
    novaGroup: 1,
  ),
  // Be careful
  const Product(
    name: 'Cola',
    brand: 'BigCo',
    quantity: '330 ml',
    categories: ['en:beverages', 'en:carbonated-drinks'],
    ingredientsText:
        'Carbonated water, sugar, caramel colour (E150d), phosphoric acid (INS 338), '
        'natural and artificial flavours, caffeine.',
    ingredients: [
      'carbonated water',
      'sugar',
      'caramel colour',
      'phosphoric acid',
      'natural and artificial flavours',
      'caffeine'
    ],
    additiveCodes: ['e150d', 'e338'],
    nutriments: Nutriments(
      energyKcal: 42,
      sugars: 10.6,
      saturatedFat: 0,
      salt: 0.03,
    ),
  ),
  // Avoid
  const Product(
    name: 'Healthy Multigrain Choco Cookies',
    brand: 'YumBrand',
    quantity: '200 g',
    categories: ['en:biscuits'],
    ingredientsText:
        'Refined wheat flour (maida), sugar, palm oil, cocoa solids, '
        'invert syrup, emulsifier (INS 322), artificial flavour, salt.',
    ingredients: [
      'refined wheat flour (maida)',
      'sugar',
      'palm oil',
      'cocoa solids',
      'invert syrup',
      'emulsifier (INS 322)',
      'artificial flavour',
      'salt',
    ],
    additiveCodes: ['e322'],
    nutriments: Nutriments(
      energyKcal: 480,
      sugars: 28,
      saturatedFat: 8,
      salt: 0.8,
    ),
  ),
  // Okay — yogurt
  const Product(
    name: 'Greek Yogurt',
    brand: 'Epigamia',
    quantity: '90 g',
    categories: ['en:dairies', 'en:yogurt'],
    ingredientsText: 'Pasteurised toned milk, live yogurt cultures.',
    ingredients: ['pasteurised toned milk', 'live yogurt cultures'],
    nutriments: Nutriments(
      energyKcal: 96,
      sugars: 4.5,
      saturatedFat: 3.5,
      salt: 0.1,
      proteins: 9,
    ),
    novaGroup: 2,
  ),
];
