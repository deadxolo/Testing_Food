import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight key/value settings (Gemini API key + model choice).
class SettingsService {
  static const _kApiKey = 'gemini_api_key';
  static const _kModel = 'gemini_model';
  static const _kSeeded = 'gemini_default_seeded_v1';

  // ---------------------------------------------------------------------------
  // DEV CONVENIENCE — first-launch default API key.
  //
  // This is only baked in so the app works out of the box during development.
  // For a published / committed build, set this to '' and let the user paste
  // their own key into Settings. Rotate any key that has lived in source.
  // ---------------------------------------------------------------------------
  static const _devSeedKey = 'AIzaSyDp9NsdiXu19uBrUS6qUy6UuPadkuCcBFE';

  static const availableModels = <String>[
    'gemini-2.5-flash-lite', // cheapest / fastest
    'gemini-2.5-flash', // balanced (default)
    'gemini-2.5-pro', // most capable
  ];
  static const defaultModel = 'gemini-2.5-flash';

  /// Call once at app start. If the user has no key and no key has ever been
  /// seeded, plant [_devSeedKey] so the AI label reader works without setup.
  Future<void> seedDefaultsIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kSeeded) == true) return;
    final existing = p.getString(_kApiKey)?.trim();
    if ((existing == null || existing.isEmpty) && _devSeedKey.isNotEmpty) {
      await p.setString(_kApiKey, _devSeedKey);
    }
    await p.setBool(_kSeeded, true);
  }

  Future<String?> getApiKey() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kApiKey)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setApiKey(String? key) async {
    final p = await SharedPreferences.getInstance();
    final v = key?.trim() ?? '';
    if (v.isEmpty) {
      await p.remove(_kApiKey);
    } else {
      await p.setString(_kApiKey, v);
    }
  }

  Future<String> getModel() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kModel);
    return (v != null && availableModels.contains(v)) ? v : defaultModel;
  }

  Future<void> setModel(String model) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kModel, model);
  }

  Future<bool> hasApiKey() async => (await getApiKey()) != null;
}
