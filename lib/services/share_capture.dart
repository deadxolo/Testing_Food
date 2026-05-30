import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [card] off-screen via an [OverlayEntry], waits for it to paint, and
/// captures the resulting [RepaintBoundary] to PNG bytes.
///
/// The widget is placed far off the visible area so the user never sees it.
/// The entry is removed in [whenComplete], even on error.
Future<Uint8List> captureCardToPng(
  BuildContext context, {
  required Widget card,
  double pixelRatio = 3.0,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final repaintKey = GlobalKey();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -20000, // far off-screen — painted but invisible
      top: -20000,
      child: RepaintBoundary(
        key: repaintKey,
        child: Material(
          type: MaterialType.transparency,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: card,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);

  try {
    // Let layout + paint settle before reading pixels.
    await _waitForFrames(2);

    // The GlobalKey gives us our own context — not the caller's — so this is
    // not the "async gap on a passed-in context" footgun.
    final ctx = repaintKey.currentContext;
    if (ctx == null) {
      throw StateError('Share card never attached to the tree.');
    }
    // ignore: use_build_context_synchronously
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode share card to PNG.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}

Future<void> _waitForFrames(int count) async {
  for (var i = 0; i < count; i++) {
    await WidgetsBinding.instance.endOfFrame;
  }
}
