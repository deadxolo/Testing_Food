import 'package:flutter/material.dart';

import '../screens/capture_screen.dart';
import '../screens/scan_runner.dart';
import '../screens/scanner_screen.dart';
import 'scan_service.dart';

/// Entry points used from anywhere in the UI (home screen, bottom nav scan
/// tab, store screen "scan this" button, …). Centralised so the camera/photo
/// flow is identical everywhere.

/// Launches the barcode scanner, then runs the Open Food Facts lookup with an
/// AI-vision recovery option. If the user taps "photograph the label instead"
/// inside the scanner screen, falls through to [startPhotoCapture].
Future<void> startBarcodeScan(BuildContext context) async {
  final barcode = await Navigator.of(context).push<String?>(
    MaterialPageRoute(builder: (_) => const ScannerScreen()),
  );
  if (!context.mounted) return;
  if (barcode == null) {
    await startPhotoCapture(context);
    return;
  }
  final svc = ScanService();
  await runScan(
    context,
    () async {
      try {
        return await svc.scanBarcode(barcode);
      } finally {
        svc.dispose();
      }
    },
    recovery: (
      label: 'Photograph label',
      onTap: () => startPhotoCapture(context, barcode: barcode),
    ),
  );
}

/// Pushes the capture screen for the AI-vision photo flow.
Future<void> startPhotoCapture(BuildContext context, {String? barcode}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CaptureScreen(barcode: barcode)),
  );
}
