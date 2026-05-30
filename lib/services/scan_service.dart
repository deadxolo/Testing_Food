import 'dart:async';
import 'dart:io';

import '../models/health_report.dart';
import '../models/product.dart';
import 'ai_vision_service.dart';
import 'auth_service.dart';
import 'history_service.dart';
import 'open_food_facts_service.dart';
import 'scoring_engine.dart';
import 'settings_service.dart';

class ScanResult {
  final Product product;
  final HealthReport report;
  final List<String> notices; // user-facing info about how we got the data
  ScanResult(this.product, this.report, {this.notices = const []});
}

class ScanFailure implements Exception {
  final String message;
  final bool needsApiKey;
  ScanFailure(this.message, {this.needsApiKey = false});
  @override
  String toString() => message;
}

/// Orchestrates a scan: barcode → Open Food Facts, with an AI-vision fallback,
/// then runs the scoring engine and saves to history.
class ScanService {
  ScanService({
    OpenFoodFactsService? off,
    HistoryService? history,
    SettingsService? settings,
    ScoringEngine? engine,
  })  : _off = off ?? OpenFoodFactsService(),
        _history = history ?? HistoryService(),
        _settings = settings ?? SettingsService(),
        _engine = engine ?? ScoringEngine();

  final OpenFoodFactsService _off;
  final HistoryService _history;
  final SettingsService _settings;
  final ScoringEngine _engine;

  /// Barcode-first. If [images] are supplied they're used as the AI fallback
  /// when the barcode isn't in the database.
  Future<ScanResult> scanBarcode(String barcode, {List<File> images = const []}) async {
    final notices = <String>[];
    Product product;
    try {
      product = await _off.lookupBarcode(barcode);
      notices.add('Matched in Open Food Facts (community database).');
      if (product.ingredients.isEmpty && product.ingredientsText == null) {
        notices.add('This entry has no ingredient list — score is limited.');
      }
    } on ProductNotFoundException {
      if (images.isNotEmpty) {
        final ai = await _analyzeWithAi(images, localImagePath: images.first.path);
        product = ai.copyWithBarcode(barcode);
        notices
          ..add('Not in the database — read the label with AI vision instead.')
          ..add('AI-read labels can have mistakes; double-check the panel.');
      } else {
        throw ScanFailure(
            "Barcode $barcode isn't in the database yet. Take photos of the ingredients & nutrition panel and we'll read them.");
      }
    }
    return _finish(product, notices);
  }

  /// Pure photo flow (no barcode): always uses AI vision.
  Future<ScanResult> scanPhotos(List<File> images) async {
    if (images.isEmpty) throw ScanFailure('No photo to analyse.');
    final product =
        await _analyzeWithAi(images, localImagePath: images.first.path);
    final notices = <String>[
      'Read directly from your photos with AI vision.',
      'AI-read labels can have mistakes; double-check the panel.',
    ];
    return _finish(product, notices);
  }

  Future<Product> _analyzeWithAi(List<File> images, {String? localImagePath}) async {
    final key = await _settings.getApiKey();
    if (key == null) {
      throw ScanFailure(
        'To read labels from photos, add your Anthropic API key in Settings.',
        needsApiKey: true,
      );
    }
    final model = await _settings.getModel();
    final ai = AiVisionService(apiKey: key, model: model);
    try {
      return await ai.analyseImages(images, localImagePath: localImagePath);
    } on AiVisionException catch (e) {
      throw ScanFailure(e.message);
    } finally {
      ai.dispose();
    }
  }

  Future<ScanResult> _finish(Product product, List<String> notices) async {
    final report = _engine.analyse(product);
    await _history.add(ScanRecord.create(product, report));
    // Best-effort: bump the user's scansCount on the backend. Never let a
    // backend hiccup interrupt the local scan flow.
    unawaited(AuthService.instance.incrementScansCount());
    return ScanResult(product, report, notices: notices);
  }

  void dispose() => _off.dispose();
}

extension on Product {
  Product copyWithBarcode(String barcode) => Product(
        barcode: barcode,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        localImagePath: localImagePath,
        quantity: quantity,
        ingredients: ingredients,
        ingredientsText: ingredientsText,
        additiveCodes: additiveCodes,
        nutriments: nutriments,
        novaGroup: novaGroup,
        nutriScoreGrade: nutriScoreGrade,
        source: source,
        categories: categories,
      );
}
