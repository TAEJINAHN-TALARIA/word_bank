import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Firebase ID 토큰 반환 (API 요청 시 Authorization 헤더에 사용)
  static Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // 기존 로그인 세션을 초기화하여 계정 선택 팝업이 항상 표시되도록 함
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google sign-in: user cancelled');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      debugPrint('Google sign-in: accessToken=${googleAuth.accessToken != null}, '
          'idToken=${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        debugPrint('Google sign-in: idToken is null. '
            'Check that google-services.json contains a web OAuth client '
            '(client_type: 3) and the SHA-1 fingerprint matches.');
        throw Exception(
          'Google Sign-In succeeded but idToken is null. '
          'Verify google-services.json has a web OAuth client (client_type: 3) '
          'and the APK SHA-1 is registered in Firebase Console.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  static Future<UserCredential?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return await _auth.signInWithCredential(oauthCredential);
  }

  static Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
