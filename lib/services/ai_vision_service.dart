import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class AiVisionException implements Exception {
  final String message;
  AiVisionException(this.message);
  @override
  String toString() => message;
}

/// Reads a packaged-food label from one or more photos using **Google Gemini's**
/// vision API and returns a structured [Product]. Used when a barcode lookup
/// fails (or there's no barcode). Requires a Gemini API key (see Settings).
///
/// Note: in a shipping app you'd proxy this through your own server so the key
/// never lives on the device — this direct call is for the MVP.
class AiVisionService {
  AiVisionService({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  static const _baseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _systemPrompt = '''
You are a food-label reading assistant for a "is this packaged food healthy?" app.
You will be shown one or more photos of a packaged food or drink — typically the front of pack, the ingredients list, and the nutrition information panel.

Extract the facts as accurately as you can. Do NOT invent numbers. If something is not visible, use null.
Read ALL ingredients in the order printed. Capture every additive / INS / E number you can see.
Convert nutrition values to "per 100 g" (or per 100 ml for drinks). If the panel is only "per serving", convert using the serving size; if you cannot, return the per-serving values and set "nutritionBasis" to "per_serving".

Respond with ONLY a JSON object, no markdown, no commentary, in exactly this shape:
{
  "name": string|null,
  "brand": string|null,
  "quantity": string|null,
  "categories": string[],
  "ingredientsText": string|null,
  "ingredients": string[],
  "additiveCodes": string[],
  "nutritionBasis": "per_100g"|"per_serving"|"unknown",
  "nutriments": {
    "energyKcal": number|null,
    "sugars": number|null,
    "saturatedFat": number|null,
    "fat": number|null,
    "salt": number|null,
    "sodium": number|null,
    "fiber": number|null,
    "proteins": number|null,
    "fruitsVegNuts": number|null
  },
  "novaGroup": 1|2|3|4|null,
  "isFoodLabel": boolean,
  "confidenceNote": string
}
''';

  Future<Product> analyseImages(List<File> images,
      {String? localImagePath}) async {
    if (images.isEmpty) throw AiVisionException('No image provided.');

    final parts = <Map<String, dynamic>>[];
    for (final f in images.take(4)) {
      final bytes = await f.readAsBytes();
      parts.add({
        'inline_data': {
          'mime_type': _mediaType(f.path),
          'data': base64Encode(bytes),
        }
      });
    }
    parts.add({
      'text':
          'Read this packaged food/drink. Return the JSON object exactly as specified.'
    });

    final uri =
        Uri.parse('$_baseEndpoint/$model:generateContent?key=$apiKey');
    late http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': _systemPrompt}
                ]
              },
              'contents': [
                {'parts': parts}
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
                'maxOutputTokens': 2048,
              }
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw AiVisionException('No internet connection.');
    }

    if (res.statusCode == 400) {
      // Gemini returns 400 for malformed requests / bad keys with a message.
      final msg = _extractError(res.body) ??
          'The Gemini API rejected the request. Check your API key in Settings.';
      throw AiVisionException(msg);
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AiVisionException(
          'Gemini API key was rejected. Check it in Settings.');
    }
    if (res.statusCode == 429) {
      throw AiVisionException(
          'Rate limited by the Gemini API. Try again in a moment.');
    }
    if (res.statusCode != 200) {
      throw AiVisionException('AI vision failed (HTTP ${res.statusCode}).');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty) {
      // Could be a safety block — surface a useful message.
      final pf = body['promptFeedback'];
      throw AiVisionException(pf != null
          ? 'Gemini returned no result (prompt feedback: ${jsonEncode(pf)}).'
          : 'Gemini returned no candidates.');
    }
    final content = (candidates.first as Map)['content'] as Map?;
    final partsOut = (content?['parts'] as List?) ?? const [];
    final text = partsOut
        .whereType<Map>()
        .where((p) => p['text'] != null)
        .map((p) => p['text'].toString())
        .join('\n')
        .trim();
    final jsonStr = _extractJson(text);
    if (jsonStr == null) {
      throw AiVisionException('Could not understand the Gemini response.');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw AiVisionException(
          'Gemini returned malformed data. Try clearer photos.');
    }

    if (j['isFoodLabel'] == false) {
      throw AiVisionException(
          "That doesn't look like a packaged food label. Try photographing the ingredients/nutrition panel.");
    }

    return _toProduct(j, localImagePath: localImagePath);
  }

  Product _toProduct(Map<String, dynamic> j, {String? localImagePath}) {
    List<String> strs(dynamic v) => (v is List)
        ? v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : [];
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final nm = (j['nutriments'] is Map)
        ? Map<String, dynamic>.from(j['nutriments'] as Map)
        : <String, dynamic>{};
    final salt = d(nm['salt']);
    final sodium = d(nm['sodium']);
    final nut = Nutriments(
      energyKcal: d(nm['energyKcal']),
      sugars: d(nm['sugars']),
      saturatedFat: d(nm['saturatedFat']),
      fat: d(nm['fat']),
      salt: salt ?? (sodium != null ? sodium * 2.5 : null),
      sodium: sodium ?? (salt != null ? salt / 2.5 : null),
      fiber: d(nm['fiber']),
      proteins: d(nm['proteins']),
      fruitsVegNuts: d(nm['fruitsVegNuts']),
    );

    final nova = j['novaGroup'];
    return Product(
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? (j['name'] as String).trim()
          : 'Scanned product',
      brand: (j['brand'] as String?)?.trim(),
      quantity: (j['quantity'] as String?)?.trim(),
      localImagePath: localImagePath,
      ingredients: strs(j['ingredients']),
      ingredientsText: (j['ingredientsText'] as String?)?.trim(),
      additiveCodes: strs(j['additiveCodes']),
      nutriments: nut,
      novaGroup: (nova is num) ? nova.toInt() : null,
      source: ProductSource.aiVision,
      categories: strs(j['categories']),
    );
  }

  static String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static String? _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  static String? _extractError(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] is Map) {
        return (j['error']['message'] as String?)?.trim();
      }
    } catch (_) {}
    return null;
  }

  void dispose() => _client.close();
}
