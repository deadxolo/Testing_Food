/// Product-category detection + per-category nutrition thresholds.
///
/// The 4-pillar scoring system compares products **within their own
/// category** (biscuit vs. biscuit, not biscuit vs. salad). Each category
/// carries its own [NutritionThresholds] so a 5 g/100 ml sugar drink looks
/// "high" while 5 g/100 g biscuit looks merely "moderate".
library;

import '../models/product.dart';

enum ProductCategory {
  beverage, // sodas, juices, energy drinks
  dairy, // milk, yogurt, cheese — also drinkable but different physiology
  biscuit, // biscuits, cookies, wafers, crackers
  chocolate, // chocolate, candy, confectionery
  chips, // namkeen, chips, savoury snacks
  cereal, // muesli, granola, cornflakes
  noodle, // instant noodles, pasta
  bread, // bread, buns, rolls
  spread, // jam, peanut butter, chocolate spread
  generalSolid, // fallback
}

extension ProductCategoryX on ProductCategory {
  String get label => switch (this) {
        ProductCategory.beverage => 'Beverage',
        ProductCategory.dairy => 'Dairy',
        ProductCategory.biscuit => 'Biscuit / cookie',
        ProductCategory.chocolate => 'Chocolate / candy',
        ProductCategory.chips => 'Savoury snack',
        ProductCategory.cereal => 'Cereal',
        ProductCategory.noodle => 'Instant noodle / pasta',
        ProductCategory.bread => 'Bread / bakery',
        ProductCategory.spread => 'Spread / sauce',
        ProductCategory.generalSolid => 'Packaged food',
      };

  /// Beverages and "drinkable" dairy (flavoured milk) use ml as the per-100
  /// basis; everything else uses g.
  bool get isLiquid => this == ProductCategory.beverage;
}

/// A nutrition threshold tier: when the value is >= [atLeast], the engine
/// subtracts [penalty] points.
class Tier {
  final double atLeast;
  final int penalty;
  const Tier(this.atLeast, this.penalty);
}

class NutritionThresholds {
  final List<Tier> sugar;
  final List<Tier> satFat;
  final List<Tier> salt;
  final List<Tier> energyKcal;

  /// Bonus tiers for the "good" nutrients. [atLeast] still means
  /// "value >= atLeast"; here [penalty] is *added* (positive points).
  final List<Tier> fiberBonus;
  final List<Tier> proteinBonus;
  final List<Tier> fruitVegBonus;

  const NutritionThresholds({
    required this.sugar,
    required this.satFat,
    required this.salt,
    required this.energyKcal,
    required this.fiberBonus,
    required this.proteinBonus,
    required this.fruitVegBonus,
  });
}

/// Generic solid-food thresholds — Nutri-Score inspired.
const _generalSolid = NutritionThresholds(
  sugar: [Tier(22.5, 22), Tier(13.5, 14), Tier(5, 5)],
  satFat: [Tier(6, 16), Tier(3, 8), Tier(1.5, 3)],
  salt: [Tier(1.5, 14), Tier(0.9, 8), Tier(0.3, 3)],
  energyKcal: [Tier(450, 8), Tier(350, 4)],
  fiberBonus: [Tier(6, 8), Tier(3, 4)],
  proteinBonus: [Tier(15, 6), Tier(8, 3)],
  fruitVegBonus: [Tier(40, 8), Tier(20, 4)],
);

/// Beverages get stricter sugar tiers — Nutri-Score uses ~2.5 / 5 / 11.25 g
/// per 100 ml. Even small amounts of free sugar in liquid form spike blood
/// glucose without satiety.
const _beverage = NutritionThresholds(
  // Beverages: any free sugar in liquid form is harsh on metabolism, so this
  // bar is set well below the 100g-solid one.
  sugar: [Tier(9, 28), Tier(5, 18), Tier(2.5, 9)],
  satFat: [Tier(3, 12), Tier(1.5, 6), Tier(0.5, 2)],
  salt: [Tier(0.9, 10), Tier(0.3, 5), Tier(0.1, 2)],
  energyKcal: [Tier(150, 12), Tier(80, 6), Tier(40, 2)],
  fiberBonus: [Tier(3, 4)],
  proteinBonus: [Tier(6, 4)],
  fruitVegBonus: [Tier(80, 10), Tier(40, 5)],
);

/// Confectionery — chocolate, candy. Everything is sweet and fatty here, so
/// the bar is set higher; only truly indulgent products get the heaviest
/// penalties. (Doesn't mean they're "healthy" overall — the ingredient &
/// processing pillars carry that.)
const _confectionery = NutritionThresholds(
  sugar: [Tier(45, 22), Tier(30, 14), Tier(15, 6)],
  satFat: [Tier(15, 16), Tier(8, 8), Tier(4, 3)],
  salt: [Tier(1.0, 12), Tier(0.6, 6), Tier(0.2, 2)],
  energyKcal: [Tier(520, 8), Tier(420, 4)],
  fiberBonus: [Tier(6, 6), Tier(3, 3)],
  proteinBonus: [Tier(8, 4)],
  fruitVegBonus: [Tier(30, 6), Tier(15, 3)],
);

/// Savoury snacks (chips, namkeen) — salt is the big concern.
const _savoury = NutritionThresholds(
  sugar: [Tier(15, 14), Tier(8, 8), Tier(3, 3)],
  satFat: [Tier(10, 16), Tier(5, 10), Tier(2, 4)],
  salt: [Tier(2.0, 18), Tier(1.2, 12), Tier(0.5, 6)],
  energyKcal: [Tier(520, 10), Tier(420, 5)],
  fiberBonus: [Tier(6, 6), Tier(3, 3)],
  proteinBonus: [Tier(10, 4)],
  fruitVegBonus: [Tier(30, 6), Tier(15, 3)],
);

/// Dairy — protein bonus matters more, sat-fat bar is a little gentler
/// (whole-milk yogurts naturally have some).
const _dairy = NutritionThresholds(
  sugar: [Tier(15, 18), Tier(10, 12), Tier(5, 5)],
  satFat: [Tier(8, 14), Tier(4, 8), Tier(2, 3)],
  salt: [Tier(1.2, 12), Tier(0.6, 6), Tier(0.2, 2)],
  energyKcal: [Tier(300, 6), Tier(200, 3)],
  fiberBonus: [Tier(3, 4)],
  proteinBonus: [Tier(8, 6), Tier(4, 3)],
  fruitVegBonus: [Tier(20, 4)],
);

const Map<ProductCategory, NutritionThresholds> kThresholds = {
  ProductCategory.beverage: _beverage,
  ProductCategory.dairy: _dairy,
  ProductCategory.biscuit: _generalSolid,
  ProductCategory.chocolate: _confectionery,
  ProductCategory.chips: _savoury,
  ProductCategory.cereal: _generalSolid,
  ProductCategory.noodle: _savoury,
  ProductCategory.bread: _generalSolid,
  ProductCategory.spread: _generalSolid,
  ProductCategory.generalSolid: _generalSolid,
};

/// Detect the category for a [Product]. Looks at:
///  • the product's `categories_tags` from Open Food Facts, and
///  • keywords in name/brand as a fallback.
ProductCategory detectCategory(Product p) {
  final hay = [
    ...p.categories,
    p.name,
    p.brand ?? '',
  ].join(' ').toLowerCase();

  bool any(List<String> needles) => needles.any(hay.contains);

  if (any([
    'beverage', 'drink', 'soda', 'cola', 'juice', 'soft drink', 'energy drink',
    'iced tea', 'sports drink', 'water'
  ])) {
    return ProductCategory.beverage;
  }
  if (any(['milk', 'yogurt', 'curd', 'cheese', 'paneer', 'dahi', 'lassi'])) {
    return ProductCategory.dairy;
  }
  if (any([
    'biscuit', 'cookie', 'cookies', 'wafer', 'cracker', 'rusk', 'parle-g',
    'oreo', 'marie'
  ])) {
    return ProductCategory.biscuit;
  }
  if (any([
    'chocolate', 'confectionery', 'candy', 'toffee', 'bar', 'truffle', 'mithai'
  ])) {
    return ProductCategory.chocolate;
  }
  if (any([
    'chips', 'crisps', 'kurkure', 'bhujia', 'namkeen', 'snack', 'savoury',
    'savory', "lay's", 'bingo'
  ])) {
    return ProductCategory.chips;
  }
  if (any([
    'cereal', 'cornflakes', 'muesli', 'granola', 'oats',
    'breakfast'
  ])) {
    return ProductCategory.cereal;
  }
  if (any(['noodle', 'pasta', 'macaroni', 'maggi', 'ramen', 'instant'])) {
    return ProductCategory.noodle;
  }
  if (any(['bread', 'bun', 'roll', 'loaf', 'bakery'])) {
    return ProductCategory.bread;
  }
  if (any(['jam', 'spread', 'butter', 'nutella', 'ketchup', 'sauce'])) {
    return ProductCategory.spread;
  }
  return ProductCategory.generalSolid;
}

NutritionThresholds thresholdsFor(ProductCategory c) =>
    kThresholds[c] ?? _generalSolid;
