import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Auth + user-doc service.
///
/// **Anonymous-first**: every device gets a Firebase uid silently on launch.
/// Later, the user can upgrade to a Google / email account; the same uid is
/// preserved through `linkWith…` calls, so all their scans, history and ad
/// impressions stay attached to the same record.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// True once [bootstrap] has successfully signed a user in. When false, all
  /// other methods are no-ops — important on Android where Firebase isn't
  /// initialised yet (no `google-services.json`).
  bool _ready = false;
  bool get isReady => _ready;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Current user (or null if Firebase isn't initialised / sign-in failed).
  User? get currentUser => _ready ? _auth.currentUser : null;

  /// Reactive auth state — pushes a new value on sign-in, sign-out and
  /// account-linking events. Use in `StreamBuilder` from the UI.
  Stream<User?> get userChanges =>
      _ready ? _auth.userChanges() : const Stream.empty();

  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// Live "is this user an admin?" stream.
  ///
  /// Admin status is granted by the presence of a doc at `admins/{uid}` —
  /// no Cloud Functions / custom claims required. Bootstrap: a project owner
  /// creates the first admins doc in the Firestore Console.
  Stream<bool> get isAdminStream {
    if (!_ready) return Stream.value(false);
    return userChanges.asyncExpand((u) {
      if (u == null) return Stream.value(false);
      return _db
          .collection('admins')
          .doc(u.uid)
          .snapshots()
          .map((s) => s.exists)
          .handleError((Object _) => false);
    });
  }

  /// Synchronous one-shot check — useful for navigator guards. Falls back to
  /// false if the rules deny the read.
  Future<bool> checkAdmin() async {
    if (!_ready) return false;
    final u = _auth.currentUser;
    if (u == null) return false;
    try {
      final s = await _db.collection('admins').doc(u.uid).get();
      return s.exists;
    } catch (_) {
      return false;
    }
  }

  /// Called once at app startup. Idempotent — safe to call multiple times.
  ///
  /// • If no user is signed in yet, signs in anonymously so the device has
  ///   a uid to attach scans / ads / stats to.
  /// • Touches the `users/{uid}` doc so the admin panel can see this user
  ///   exists and when they last opened the app.
  Future<void> bootstrap() async {
    // ---- Auth phase: must succeed for the rest of the app to use a uid.
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      _ready = true;
    } catch (e, st) {
      _ready = false;
      debugPrint('AuthService anonymous sign-in failed: $e\n$st');
      return;
    }
    // ---- Firestore phase: best-effort. If rules deny it, the app still
    // works — admin features will just be unavailable for this user.
    try {
      await _touchUserDoc();
    } catch (e, st) {
      debugPrint(
          'AuthService._touchUserDoc failed (likely Firestore rules): $e\n$st');
    }
  }

  /// Writes `users/{uid}`: creates it on first run (with `createdAt`),
  /// otherwise just bumps `lastLoginAt` and refreshes the identity fields.
  Future<void> _touchUserDoc() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final ref = _db.collection('users').doc(u.uid);

    final identity = {
      'uid': u.uid,
      'isAnonymous': u.isAnonymous,
      'email': u.email,
      'displayName': u.displayName,
      'photoURL': u.photoURL,
      'providers':
          u.providerData.map((p) => p.providerId).toList(growable: false),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    final snap = await ref.get();
    if (snap.exists) {
      await ref.update(identity);
    } else {
      await ref.set({
        ...identity,
        'createdAt': FieldValue.serverTimestamp(),
        'scansCount': 0,
      });
    }
  }

  /// Bump `users/{uid}.scansCount` after a successful scan. Best-effort —
  /// we never want a Firestore hiccup to break the local scan flow.
  Future<void> incrementScansCount() async {
    if (!_ready) return;
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await _db.collection('users').doc(u.uid).set(
            {'scansCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('incrementScansCount failed: $e');
    }
  }

  Future<void> signOut() async {
    if (!_ready) return;
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  // -------------------------------------------------------- Sign-in methods

  /// Email + password sign-in. After success, [bootstrap] should be re-run
  /// (or the user-doc touch happens automatically via the auth state stream).
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    await _touchUserDoc();
    return cred;
  }

  /// Create a new email account. If the user is currently signed in anonymously,
  /// the anonymous account is *linked* to the new credential so the existing
  /// uid (and all attached scans / history) is preserved.
  Future<UserCredential> signUpWithEmail(
      String email, String password, {String? displayName}) async {
    UserCredential cred;
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      final credential =
          EmailAuthProvider.credential(email: email.trim(), password: password);
      cred = await current.linkWithCredential(credential);
    } else {
      cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    }
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    await _touchUserDoc();
    return cred;
  }

  /// Google sign-in via google_sign_in plugin → Firebase credential.
  /// Anonymous user upgrade path: links the Google credential to the
  /// existing anonymous uid.
  Future<UserCredential> signInWithGoogle() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) {
      throw FirebaseAuthException(
          code: 'cancelled', message: 'Google sign-in was cancelled.');
    }
    final gAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
        idToken: gAuth.idToken, accessToken: gAuth.accessToken);
    UserCredential cred;
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        cred = await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          // The Google account already has a uid; sign in there and let the
          // local history orphan (caller can warn the user).
          cred = await _auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
      }
    } else {
      cred = await _auth.signInWithCredential(credential);
    }
    await _touchUserDoc();
    return cred;
  }

  /// Apple sign-in (iOS / macOS). Uses a nonce per Apple's CSRF protection.
  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final oauth = OAuthProvider("apple.com").credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
    );
    UserCredential cred;
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        cred = await current.linkWithCredential(oauth);
      } on FirebaseAuthException {
        cred = await _auth.signInWithCredential(oauth);
      }
    } else {
      cred = await _auth.signInWithCredential(oauth);
    }
    // Apple only sends name on first sign-in; merge it if present.
    final fullName = [
      appleCred.givenName,
      appleCred.familyName,
    ].whereType<String>().join(' ').trim();
    if (fullName.isNotEmpty && (cred.user?.displayName ?? '').isEmpty) {
      await cred.user?.updateDisplayName(fullName);
    }
    await _touchUserDoc();
    return cred;
  }

  /// Phone OTP — step 1. Returns a [PhoneAuthCredential] / verificationId via
  /// the [onCodeSent] callback. Wire the UI to call [verifySms] with the
  /// 6-digit code the user types.
  Future<void> startPhoneSignIn(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Phone OTP — step 2.
  Future<UserCredential> verifySms(String verificationId, String code) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: code);
    UserCredential cred;
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        cred = await current.linkWithCredential(credential);
      } on FirebaseAuthException {
        cred = await _auth.signInWithCredential(credential);
      }
    } else {
      cred = await _auth.signInWithCredential(credential);
    }
    await _touchUserDoc();
    return cred;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
