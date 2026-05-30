import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ad.dart';
import 'auth_service.dart';

/// CRUD + live streaming for the `ads/` Firestore collection.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('ads');

  /// Live stream of every ad — used by the admin list.
  Stream<List<Ad>> allAds() {
    if (!AuthService.instance.isReady) return const Stream.empty();
    return _col
        .orderBy('priority', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Ad.fromDoc).toList());
  }

  /// Currently-live ads (enabled + within schedule), highest priority first.
  /// Used by the home screen promo slot.
  Stream<List<Ad>> liveAds() {
    if (!AuthService.instance.isReady) return Stream.value(const <Ad>[]);
    return _col
        .where('enabled', isEqualTo: true)
        .orderBy('priority', descending: true)
        .limit(20)
        .snapshots()
        .map((qs) {
      final now = DateTime.now();
      return qs.docs.map(Ad.fromDoc).where((a) => a.isLiveAt(now)).toList();
    }).handleError((Object _) => const <Ad>[]);
  }

  Future<void> save(Ad ad) async {
    final uid = AuthService.instance.currentUser?.uid ?? 'unknown';
    final data = ad.toFirestore(updatedBy: uid);
    if (ad.id.isEmpty) {
      await _col.add(data);
    } else {
      await _col.doc(ad.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
