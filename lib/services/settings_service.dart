import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight key/value settings (Gemini API key + model choice).
class SettingsService {
  static const _kApiKey = 'gemini_api_key';
  static const _kModel = 'gemini_model';
  static const _kSeeded = 'gemini_default_seeded_v1';

  // ---------------------------------------------------------------------------
  // First-launch default API key — injected at BUILD TIME, never committed.
  //
  // Provide it via --dart-define so the key stays out of source control:
  //   flutter run   --dart-define=GEMINI_API_KEY=your_key_here
  //   flutter build --dart-define=GEMINI_API_KEY=your_key_here
  // If no value is supplied this is '' and the user pastes their own key in
  // Settings. NEVER hardcode a real key here — anything in source ends up on
  // GitHub. Rotate any key that has ever lived in source.
  // ---------------------------------------------------------------------------
  static const _devSeedKey = String.fromEnvironment('GEMINI_API_KEY');

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
