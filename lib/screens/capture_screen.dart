import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:image_picker/image_picker.dart';

import '../services/scan_service.dart';
import '../theme.dart';
import 'scan_runner.dart';

/// Collect 1–4 photos of a product (front / ingredients / nutrition), then
/// send them to the AI-vision reader.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.barcode});

  /// If set, this is the AI fallback for a barcode that wasn't in the database.
  final String? barcode;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  bool _busy = false;

  Future<void> _takePhoto() async {
    if (_images.length >= 4) return;
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2200,
      );
      if (x != null) setState(() => _images.add(x));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85, limit: 4);
      if (picked.isNotEmpty) {
        setState(() {
          for (final x in picked) {
            if (_images.length < 4) _images.add(x);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _analyze() {
    final files = _images.map((x) => File(x.path)).toList();
    final svc = ScanService();
    runScan(
      context,
      () async {
        try {
          return widget.barcode != null
              ? await svc.scanBarcode(widget.barcode!, images: files)
              : await svc.scanPhotos(files);
        } finally {
          svc.dispose();
        }
      },
      loadingText: 'Reading the label with AI…',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photograph the label')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.tips_and_updates_rounded,
                        color: AppColors.watch),
                    const SizedBox(width: 8),
                    Text('For the best read',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  const _Tip('1. Front of the pack (name & brand)'),
                  const _Tip('2. The INGREDIENTS list — close & sharp'),
                  const _Tip('3. The NUTRITION table (per 100 g / serving)'),
                  const SizedBox(height: 4),
                  Text(
                    'Up to 4 photos. Good light, no glare, fill the frame with the text.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_images.isEmpty)
            Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text('No photos yet',
                  style: TextStyle(color: Colors.black45)),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_images[i].path),
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 13,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || _images.length >= 4 ? null : _takePhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || _images.length >= 4 ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: FilledButton.icon(
          onPressed: _images.isEmpty ? null : _analyze,
          icon: const Icon(Icons.health_and_safety),
          label: Text(_images.isEmpty
              ? 'Add at least one photo'
              : 'Analyse ${_images.length} photo${_images.length > 1 ? 's' : ''}'),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
