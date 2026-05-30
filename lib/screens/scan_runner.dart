import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/history_service.dart';
import '../services/scan_service.dart';
import 'login_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

/// An extra action offered on the failure dialog (e.g. "Photograph the label").
typedef RecoveryAction = ({String label, VoidCallback onTap});

/// Shows a blocking "analysing…" dialog while [run] executes, then either
/// pushes the [ResultScreen] or surfaces a friendly error.
Future<void> runScan(
  BuildContext context,
  Future<ScanResult> Function() run, {
  String loadingText = 'Checking the product…',
  RecoveryAction? recovery,
}) async {
  // Login gate: the first scan is free + anonymous. From the second scan on,
  // require an account so we can attach history server-side and the admin
  // panel can see who's actively using the app.
  if (AuthService.instance.isAnonymous) {
    final priorScans = (await HistoryService().getAll()).length;
    if (priorScans >= 1) {
      final ok = await showLoginGate(
        context,
        headline: "Sign in to keep scanning",
      );
      if (!context.mounted) return;
      if (!ok) return; // user backed out of the login wall
    }
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LoadingDialog(text: loadingText),
  );

  ScanResult? result;
  Object? error;
  try {
    result = await run();
  } catch (e) {
    error = e;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop(); // dismiss loading

  if (result != null) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(result: result!)),
    );
    return;
  }

  // ---- error handling
  final isApiKey = error is ScanFailure && error.needsApiKey;
  final msg = error is ScanFailure
      ? error.message
      : 'Something went wrong: $error';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isApiKey ? 'API key needed' : "Couldn't analyse this"),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        if (isApiKey)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            child: const Text('Open Settings'),
          )
        else if (recovery != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              recovery.onTap();
            },
            child: Text(recovery.label),
          ),
      ],
    ),
  );
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 40, height: 40, child: CircularProgressIndicator()),
            const SizedBox(height: 18),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Reading the label, ingredients & nutrition…',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
