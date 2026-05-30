import 'package:cloud_firestore/cloud_firestore.dart';

/// A "promo card" rendered on the home screen. Authored by admins, read by
/// everyone. Designed to be cheap-to-render: just title + body + optional
/// image + CTA.
class Ad {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final bool enabled;
  final int priority; // higher floats to the top of the home feed
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  const Ad({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.enabled = true,
    this.priority = 0,
    this.startsAt,
    this.endsAt,
    this.updatedBy,
    this.updatedAt,
  });

  Ad copyWith({
    String? title,
    String? body,
    String? imageUrl,
    String? ctaLabel,
    String? ctaUrl,
    bool? enabled,
    int? priority,
    DateTime? startsAt,
    DateTime? endsAt,
  }) =>
      Ad(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        imageUrl: imageUrl ?? this.imageUrl,
        ctaLabel: ctaLabel ?? this.ctaLabel,
        ctaUrl: ctaUrl ?? this.ctaUrl,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        updatedBy: updatedBy,
        updatedAt: updatedAt,
      );

  /// Whether this ad should be shown right now (enabled + within schedule).
  bool isLiveAt(DateTime now) {
    if (!enabled) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  factory Ad.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Ad(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      imageUrl: d['imageUrl'] as String?,
      ctaLabel: d['ctaLabel'] as String?,
      ctaUrl: d['ctaUrl'] as String?,
      enabled: d['enabled'] as bool? ?? true,
      priority: (d['priority'] as num?)?.toInt() ?? 0,
      startsAt: ts(d['startsAt']),
      endsAt: ts(d['endsAt']),
      updatedBy: d['updatedBy'] as String?,
      updatedAt: ts(d['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({required String updatedBy}) => {
        'title': title,
        'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (ctaLabel != null) 'ctaLabel': ctaLabel,
        if (ctaUrl != null) 'ctaUrl': ctaUrl,
        'enabled': enabled,
        'priority': priority,
        if (startsAt != null) 'startsAt': Timestamp.fromDate(startsAt!),
        if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
        'updatedBy': updatedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
