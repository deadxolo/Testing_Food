// Scoring-engine tests for the 4-pillar refactor.
//
// We don't render the UI here (it would need camera / network / Firebase) —
// these verify that the scoring engine produces sensible, category-aware
// pillar scores for representative products.

import 'package:flutter_test/flutter_test.dart';

import 'package:foodfat/data/product_categories.dart';
import 'package:foodfat/models/product.dart';
import 'package:foodfat/services/scoring_engine.dart';

void main() {
  final engine = ScoringEngine();

  group('beverages — stricter sugar/energy thresholds apply', () {
    test('a sugary cola lands in "be careful" / "poor" territory', () {
      final p = Product(
        name: 'Cola',
        brand: 'BigCo',
        categories: const ['en:beverages', 'en:carbonated-drinks'],
        ingredientsText:
            'Carbonated water, sugar, caramel colour (E150d), phosphoric acid '
            '(INS 338), natural and artificial flavours, caffeine.',
        ingredients: const [
          'carbonated water',
          'sugar',
          'caramel colour',
          'phosphoric acid',
          'natural and artificial flavours',
          'caffeine',
        ],
        additiveCodes: const ['e150d', 'e338'],
        nutriments: const Nutriments(
          energyKcal: 180,
          sugars: 10.6,
          saturatedFat: 0,
          salt: 0.03,
        ),
      );
      final r = engine.analyse(p);
      expect(r.category, ProductCategory.beverage);
      expect(r.healthPercent, lessThan(55));
      // Processing pillar reflects NOVA 4 (artificial flavour ⇒ ultra-processed)
      expect(r.pillars.processing, lessThan(30));
      // Nutrition pillar takes a meaningful sugar + energy hit
      expect(r.pillars.nutrition, lessThan(70));
    });
  });

  group('whole foods — should score very well', () {
    test('plain rolled oats score in the trustworthy band', () {
      final p = Product(
        name: 'Rolled Oats',
        ingredientsText: 'Whole grain oats.',
        ingredients: const ['whole grain oats'],
        nutriments: const Nutriments(
          energyKcal: 379,
          sugars: 1.0,
          saturatedFat: 1.2,
          salt: 0.01,
          fiber: 10,
          proteins: 13,
        ),
        novaGroup: 1,
      );
      final r = engine.analyse(p);
      expect(r.healthPercent, greaterThan(80));
      expect(r.pillars.ingredient, greaterThan(70));
      expect(r.pillars.processing, equals(100));
      expect(r.flags.any((f) => f.flag.id == 'whole_grain'), isTrue);
    });
  });

  group('health-washing — pack lies, ingredients tell the truth', () {
    test('"healthy" palm-oil biscuit scores poorly and flags it', () {
      final p = Product(
        name: 'Healthy Multigrain Choco Cookies',
        brand: 'YumBrand',
        categories: const ['en:biscuits'],
        ingredientsText:
            'Refined wheat flour (maida), sugar, palm oil, cocoa solids, '
            'invert syrup, emulsifier (INS 322), artificial flavour, salt.',
        ingredients: const [
          'refined wheat flour (maida)',
          'sugar',
          'palm oil',
          'cocoa solids',
          'invert syrup',
          'emulsifier (INS 322)',
          'artificial flavour',
          'salt',
        ],
        nutriments: const Nutriments(
          energyKcal: 480,
          sugars: 28,
          saturatedFat: 8,
          salt: 0.8,
        ),
      );
      final r = engine.analyse(p);
      expect(r.category, ProductCategory.biscuit);
      expect(r.healthPercent, lessThan(60));
      expect(r.marketingClaims, isNotEmpty);
      expect(r.flags.any((f) => f.flag.id == 'palm_oil'), isTrue);
      expect(r.flags.any((f) => f.flag.id == 'maida'), isTrue);
      // Ingredient pillar should see palm oil + maida + invert syrup
      expect(r.pillars.ingredient, lessThan(50));
    });
  });

  group('category-aware comparison', () {
    test('same sugar content scores worse in a beverage than in a biscuit', () {
      final beverage = Product(
        name: 'Fruity Drink',
        categories: const ['en:beverages'],
        ingredientsText: 'Water, sugar.',
        ingredients: const ['water', 'sugar'],
        nutriments:
            const Nutriments(energyKcal: 50, sugars: 8, saturatedFat: 0, salt: 0),
        novaGroup: 4,
      );
      final biscuit = Product(
        name: 'Whole-Wheat Biscuit',
        categories: const ['en:biscuits'],
        ingredientsText: 'Whole wheat flour, sugar.',
        ingredients: const ['whole wheat flour', 'sugar'],
        nutriments: const Nutriments(
            energyKcal: 380, sugars: 8, saturatedFat: 1.2, salt: 0.3, fiber: 6),
        novaGroup: 3,
      );
      final r1 = engine.analyse(beverage);
      final r2 = engine.analyse(biscuit);
      expect(r1.pillars.nutrition, lessThan(r2.pillars.nutrition),
          reason: '8g sugar in a drink should hurt more than in a biscuit');
    });
  });
}
