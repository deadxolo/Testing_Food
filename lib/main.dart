import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';
import 'widgets/glass_backdrop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // First-launch convenience: plant the bundled Gemini key so the AI flow
  // works without the user having to paste anything. They can still override
  // it in the Settings screen.
  await SettingsService().seedDefaultsIfNeeded();

  // Firebase — currently set up for iOS only (GoogleService-Info.plist is
  // bundled). Android requires google-services.json + Gradle plugin; until
  // that's added we skip init on Android so the app still runs.
  if (!kIsWeb && Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      // Anonymous-first auth: every device gets a uid silently.
      await AuthService.instance.bootstrap();
    } catch (e, st) {
      debugPrint('Firebase startup failed: $e\n$st');
    }
  }

  runApp(const FoodFatApp());
}

class FoodFatApp extends StatelessWidget {
  const FoodFatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodFat',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Wrap every page in the colourful gradient backdrop so the glass
      // surfaces (Card / GlassPanel / frosted nav bar) have something to
      // blur. Done once, applies everywhere.
      builder: (context, child) => GlassBackdrop(child: child ?? const SizedBox()),
      home: const RootShell(),
    );
  }
}
