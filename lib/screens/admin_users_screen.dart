import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

import '../services/auth_service.dart';
import '../theme.dart';

/// Read-only list of every signed-in user, ordered by most recent login.
/// Each row shows the uid, identity (if upgraded), scan count and an
/// "Admin / Make admin" toggle.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('lastLoginAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Couldn\'t load users:\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
              ),
            );
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No users yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _UserRow(doc: docs[i]),
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final uid = (d['uid'] ?? doc.id).toString();
    final isAnon = d['isAnonymous'] as bool? ?? true;
    final email = d['email'] as String?;
    final name = d['displayName'] as String?;
    final scans = (d['scansCount'] as num?)?.toInt() ?? 0;
    final last = d['lastLoginAt'];
    final lastDt = last is Timestamp ? last.toDate() : null;
    final isMe = AuthService.instance.currentUser?.uid == uid;

    final adminRef =
        FirebaseFirestore.instance.collection('admins').doc(uid);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor:
                (isAnon ? AppColors.watch : AppColors.good).withValues(alpha: 0.15),
            child: Icon(
              isAnon ? Icons.person_outline : Icons.person,
              color: isAnon ? AppColors.watch : AppColors.good,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        email ?? name ?? (isAnon ? 'Anonymous' : 'Unknown'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const _Tag('YOU', color: AppColors.seed),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    uid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Tag(isAnon ? 'ANON' : 'REGISTERED',
                        color: isAnon ? AppColors.watch : AppColors.good),
                    _Tag('$scans scans', color: AppColors.seed),
                    if (lastDt != null)
                      _Tag(_relative(lastDt), color: Colors.black45),
                  ]),
                ]),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: adminRef.snapshots(),
            builder: (context, asnap) {
              final isAdmin = asnap.data?.exists ?? false;
              return Switch.adaptive(
                value: isAdmin,
                onChanged: (v) async {
                  try {
                    if (v) {
                      await adminRef.set({
                        'grantedBy': AuthService.instance.currentUser?.uid,
                        'grantedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await adminRef.delete();
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')));
                  }
                },
              );
            },
          ),
        ]),
      ),
    );
  }

  static String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6)),
    );
  }
}
