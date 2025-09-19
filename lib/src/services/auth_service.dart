// lib/src/services/auth_service.dart

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../providers/notifications_provider.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isGoogleInitialized = false;

  Future<void> initializeGoogleSignIn() async {
    if (_isGoogleInitialized) return;

    try {
      await _googleSignIn.initialize(
        serverClientId: '998972257036-llbcet7uc4l7ilclp6uqp9r73o4eo1aa.apps.googleusercontent.com',
      );
      _isGoogleInitialized = true;
    } catch (e) {
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await initializeGoogleSignIn();

      if (!_googleSignIn.supportsAuthenticate()) {
        return null;
      }

      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final result = await _auth.signInWithCredential(credential);


      await NotificationsProvider.instance.addNotification(
        title: '🤗 ¡Ya estás dentro!',
        message: 'Bienvenido ${result.user?.displayName ?? result.user?.email}',
        type: 'login_success',
      );

      return result;


    } catch (e) {
      if (!e.toString().contains('cancel')) {
        await NotificationsProvider.instance.addNotification(
          title: '🚩 No se pudo conectar',
          message: 'Verificá tu conexión e intentá de nuevo',
          type: 'login_error',
        );
      }
      return null;
    }
  }
  Future<UserCredential?> signInWithApple() async {
    try {
      if (!Platform.isIOS) {
        return null;
      }

      if (!await SignInWithApple.isAvailable()) {
        return null;
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);

      if (result.user?.displayName == null && appleCredential.givenName != null) {
        await result.user?.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim(),
        );
      }

      await NotificationsProvider.instance.addNotification(
        title: '🤗 ¡Ya estás dentro!',
        message: 'Bienvenido ${result.user?.displayName ?? result.user?.email}',
        type: 'login_success',
      );
      return result;

    } catch (e) {

      if (!e.toString().contains('cancel')) {
        await NotificationsProvider.instance.addNotification(
          title: '🚩 No se pudo conectar',
          message: 'Verificá tu conexión e intentá de nuevo',
          type: 'login_error',
        );
      }

      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      await signInAnonymously();
    } catch (e) {
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLoggedIn => currentUser != null && !currentUser!.isAnonymous;

  bool get isAnonymous => currentUser?.isAnonymous ?? true;


  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

}