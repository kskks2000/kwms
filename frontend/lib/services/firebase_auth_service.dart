import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

class FirebaseAuthService {
  FirebaseAuthService._({
    required this._auth,
    required this.isConfigured,
    required this.configurationMessage,
    required this._googleSignInInitialized,
  });

  factory FirebaseAuthService.unconfigured([String? message]) {
    return FirebaseAuthService._(
      auth: null,
      isConfigured: false,
      configurationMessage:
          message ?? 'Firebase 프로젝트 설정값을 연결하면 로그인을 사용할 수 있습니다.',
      googleSignInInitialized: false,
    );
  }

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_CLIENT_ID',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
  );
  static const googleHostedDomain = String.fromEnvironment(
    'GOOGLE_SIGN_IN_HOSTED_DOMAIN',
  );

  final FirebaseAuth? _auth;
  final bool _googleSignInInitialized;
  final bool isConfigured;
  final String? configurationMessage;

  static Future<FirebaseAuthService> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      return FirebaseAuthService.unconfigured();
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }

    var googleSignInInitialized = false;
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: _emptyToNull(googleClientId),
        serverClientId: _emptyToNull(googleServerClientId),
        hostedDomain: _emptyToNull(googleHostedDomain),
      );
      googleSignInInitialized = true;
    }

    return FirebaseAuthService._(
      auth: FirebaseAuth.instance,
      isConfigured: true,
      configurationMessage: null,
      googleSignInInitialized: googleSignInInitialized,
    );
  }

  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream<User?>.value(null);
    }
    return auth.authStateChanges();
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    final auth = _requireAuth();
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    final trimmedName = displayName.trim();
    if (user != null && trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
      await user.sendEmailVerification();
    }

    return credential;
  }

  Future<void> setRememberLogin(bool rememberLogin) async {
    final auth = _auth;
    if (auth == null || !kIsWeb) {
      return;
    }

    await auth.setPersistence(
      rememberLogin ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final auth = _requireAuth();

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return auth.signInWithPopup(provider);
    }

    if (!_googleSignInInitialized) {
      throw const AuthUnavailableException('Google 로그인 설정이 준비되지 않았습니다.');
    }

    final googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return auth.signInWithCredential(credential);
  }

  Future<String?> currentIdToken({bool forceRefresh = false}) {
    return _auth?.currentUser?.getIdToken(forceRefresh) ?? Future.value();
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      return;
    }

    await auth.signOut();
    if (!kIsWeb && _googleSignInInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw AuthUnavailableException(
        configurationMessage ?? 'Firebase 로그인이 아직 설정되지 않았습니다.',
      );
    }
    return auth;
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
