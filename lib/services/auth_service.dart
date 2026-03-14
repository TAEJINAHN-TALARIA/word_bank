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

      // [1단계] Google 계정 선택
      debugPrint('[Step1 Input] scopes: ${_googleSignIn.scopes}');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[Step1 Output] user cancelled (null)');
        return null;
      }
      debugPrint('[Step1 Output] email=${googleUser.email}, id=${googleUser.id}');

      // [2단계] 토큰 획득
      debugPrint('[Step2 Input] googleUser.email=${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      debugPrint('[Step2 Output] accessToken=${googleAuth.accessToken != null}, '
          'idToken=${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        debugPrint('[Step2 Output] idToken is null! '
            'Check that google-services.json contains a web OAuth client '
            '(client_type: 3) and the SHA-1 fingerprint matches.');
        throw Exception(
          'Google Sign-In succeeded but idToken is null. '
          'Verify google-services.json has a web OAuth client (client_type: 3) '
          'and the APK SHA-1 is registered in Firebase Console.',
        );
      }

      // [3단계] Firebase 인증 정보 생성
      debugPrint('[Step3 Input] accessToken=${googleAuth.accessToken != null}, '
          'idToken=${googleAuth.idToken != null}');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      debugPrint('[Step3 Output] credential.providerId=${credential.providerId}');

      // [4단계] Firebase 로그인
      debugPrint('[Step4 Input] credential.providerId=${credential.providerId}');
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[Step4 Output] uid=${userCredential.user?.uid}, '
          'email=${userCredential.user?.email}');
      return userCredential;
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
