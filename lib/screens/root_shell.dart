import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/scan_flow.dart';
import '../theme.dart';
import 'about_screen.dart';
import 'admin_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';

/// Top-level shell with the bottom navigation:
///   Home · Store · Scan · About · Settings   (and Admin, for admins only)
///
/// "Scan" is an action (slot 2): tapping it opens the scanner chooser sheet
/// instead of switching tabs. "Admin" only renders when the current user is
/// in the `admins/` Firestore collection — see [AuthService.isAdminStream].
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _idx = 0;
  static const _scanDestinationIndex = 2;

  // Convert page index ↔ destination index (because Scan sits at slot 2 and
  // has no page of its own).
  int _destIndexForPage(int p) => p < _scanDestinationIndex ? p : p + 1;
  int _pageIndexForDest(int d) => d < _scanDestinationIndex ? d : d - 1;

  List<Widget> _pagesFor(bool isAdmin) => [
        const HomeScreen(),
        const StoreScreen(),
        const AboutScreen(),
        const SettingsScreen(),
        if (isAdmin) const AdminScreen(),
      ];

  Future<void> _onTap(int destIndex) async {
    if (destIndex == _scanDestinationIndex) {
      await _showScanChooser();
      return;
    }
    final pageIdx = _pageIndexForDest(destIndex);
    if (pageIdx != _idx) setState(() => _idx = pageIdx);
  }

  Future<void> _showScanChooser() async {
    final choice = await showModalBottomSheet<_ScanChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      builder: (_) => const _ScanChooserSheet(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ScanChoice.barcode:
        await startBarcodeScan(context);
      case _ScanChoice.photo:
        await startPhotoCapture(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: AuthService.instance.isAdminStream,
      initialData: false,
      builder: (context, snap) {
        final isAdmin = snap.data ?? false;
        final pages = _pagesFor(isAdmin);
        // If the user just lost admin status (e.g. revoked while open), clamp.
        final safeIdx = _idx >= pages.length ? 0 : _idx;
        return Scaffold(
          extendBody: true,
          body: IndexedStack(index: safeIdx, children: pages),
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: NavigationBar(
                selectedIndex: _destIndexForPage(safeIdx),
                onDestinationSelected: _onTap,
                destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Store',
              ),
              const NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_rounded),
                label: 'Scan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.info_outline_rounded),
                selectedIcon: Icon(Icons.info_rounded),
                label: 'About',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
                  if (isAdmin)
                    const NavigationDestination(
                      icon: Icon(Icons.shield_outlined),
                      selectedIcon: Icon(Icons.shield_rounded),
                      label: 'Admin',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _ScanChoice { barcode, photo }

class _ScanChooserSheet extends StatelessWidget {
  const _ScanChooserSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How would you like to scan?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pick the method that matches what you have in hand.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            _ScanOptionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Barcode',
              subtitle: 'Fast lookup against the Open Food Facts database.',
              onTap: () => Navigator.of(context).pop(_ScanChoice.barcode),
            ),
            const SizedBox(height: 10),
            _ScanOptionCard(
              icon: Icons.camera_alt_rounded,
              title: 'Photograph label',
              subtitle:
                  'No barcode? AI reads the ingredients & nutrition panel from your photos.',
              onTap: () => Navigator.of(context).pop(_ScanChoice.photo),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ScanOptionCard extends StatelessWidget {
  const _ScanOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.seed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black54)),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}
