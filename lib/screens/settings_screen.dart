import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _keyCtrl = TextEditingController();
  String _model = SettingsService.defaultModel;
  bool _obscure = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final k = await _settings.getApiKey();
    final m = await _settings.getModel();
    setState(() {
      _keyCtrl.text = k ?? '';
      _model = m;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _settings.setApiKey(_keyCtrl.text);
    await _settings.setModel(_model);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _AccountCard(),
          const SizedBox(height: 14),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.key_rounded, color: AppColors.seed),
                  const SizedBox(width: 8),
                  Text('AI label reader',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Barcode lookups (Open Food Facts) are free and need no setup. '
                  'To read products that aren\'t in the database — by photographing the label — '
                  'the app uses Google Gemini\'s vision API, which needs a Gemini API key.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Gemini API key',
                    hintText: 'AIzaSy…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse('https://aistudio.google.com/apikey'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Get a Gemini API key'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vision model',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'gemini-2.5-flash-lite',
                      child: Text('Gemini 2.5 Flash-Lite — fastest',
                          overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'gemini-2.5-flash',
                      child: Text('Gemini 2.5 Flash — balanced',
                          overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'gemini-2.5-pro',
                      child: Text('Gemini 2.5 Pro — most accurate',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) => setState(() => _model = v ?? _model),
                ),
                const SizedBox(height: 6),
                Text(
                  'Note: in this MVP the key is stored on your device and sent directly to Google. '
                  'For a published app you would route this through your own server.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black45),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Tiny account/auth panel: shows the anonymous Firebase uid so you can see
/// auth is working end-to-end. Will grow into a "Sign in with Google / email"
/// upgrade flow in the next phase.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<User?>(
          stream: AuthService.instance.userChanges,
          initialData: AuthService.instance.currentUser,
          builder: (context, snap) {
            final u = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.account_circle_rounded,
                      color: AppColors.seed),
                  const SizedBox(width: 8),
                  Text('Account',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (u != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (u.isAnonymous
                                ? AppColors.watch
                                : AppColors.good)
                            .withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        u.isAnonymous ? 'ANONYMOUS' : 'SIGNED IN',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: u.isAnonymous
                              ? AppColors.watch
                              : AppColors.good,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                if (u == null)
                  Text(
                    "Firebase isn't reachable on this device — the app still works locally.",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  )
                else ...[
                  Text(
                    u.isAnonymous
                        ? 'Every device gets a temporary identity so scans, history and ads can stick to you. You can upgrade to a real account later — your data carries over.'
                        : 'Signed in as ${u.email ?? u.displayName ?? "user"}.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tag, size: 14, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          u.uid,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black87),
                          maxLines: 1,
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
