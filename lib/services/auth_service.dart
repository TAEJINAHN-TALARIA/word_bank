import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  /// 앱 화면에서 확인할 수 있는 디버그 로그 (APK 디버깅용, 임시)
  static final List<String> debugLogs = [];

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final entry = '[$timestamp] $message';
    debugLogs.add(entry);
    debugPrint(entry);
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Firebase ID 토큰 반환 (API 요청 시 Authorization 헤더에 사용)
  static Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  static Future<UserCredential?> signInWithGoogle() async {
    debugLogs.clear();
    try {
      // 기존 로그인 세션을 초기화하여 계정 선택 팝업이 항상 표시되도록 함
      _log('[Step1] signOut previous session...');
      await _googleSignIn.signOut();

      // [1단계] Google 계정 선택
      _log('[Step1 Input] scopes: ${_googleSignIn.scopes}');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _log('[Step1 Output] user cancelled (null)');
        return null;
      }
      _log('[Step1 Output] email=${googleUser.email}, id=${googleUser.id}');

      // [2단계] 토큰 획득
      _log('[Step2 Input] googleUser.email=${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      _log('[Step2 Output] accessToken=${googleAuth.accessToken != null}, '
          'idToken=${googleAuth.idToken != null}');

      if (googleAuth.idToken == null) {
        _log('[Step2 ERROR] idToken is null! '
            'google-services.json에 web OAuth client (client_type:3) 확인 필요');
        throw Exception(
          'Google Sign-In succeeded but idToken is null. '
          'Verify google-services.json has a web OAuth client (client_type: 3) '
          'and the APK SHA-1 is registered in Firebase Console.',
        );
      }

      // [3단계] Firebase 인증 정보 생성
      _log('[Step3 Input] accessToken=${googleAuth.accessToken != null}, '
          'idToken=${googleAuth.idToken != null}');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      _log('[Step3 Output] credential.providerId=${credential.providerId}');

      // [4단계] Firebase 로그인
      _log('[Step4 Input] credential.providerId=${credential.providerId}');
      final userCredential = await _auth.signInWithCredential(credential);
      _log('[Step4 Output] uid=${userCredential.user?.uid}, '
          'email=${userCredential.user?.email}');
      _log('[SUCCESS] Google sign-in complete');
      return userCredential;
    } catch (e, st) {
      _log('[FAILED] $e');
      _log('[STACK] ${st.toString().split('\n').take(5).join(' | ')}');
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
