import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/language_prefs.dart';

class _S {
  final bool _ko;
  const _S._(this._ko);
  static _S of(String lang) => _S._(lang == '한국어');

  String get appTitle => 'Word Bank';
  String get intro => _ko
      ? 'AI로 단어를 부담 없이 학습해보세요.'
      : 'Learn words with AI without the pressure.';
  String get startFree => _ko ? '무료로 시작하기' : 'Start for free';
  String get feature1 => _ko ? 'AI 단어 조회 월 50회' : '50 AI lookups per month';
  String get feature2 => _ko ? '단어 저장' : 'Save your words';
  String get feature3 => _ko ? '7개 언어 지원' : 'Supports 7 languages';
  String get premiumLabel => _ko
      ? 'Premium: 더 많은 단어 저장'
      : 'Premium: More word storage';
  String get continueGoogle => _ko ? 'Google로 계속하기' : 'Continue with Google';
  String get continueApple => _ko ? 'Apple로 계속하기' : 'Continue with Apple';
  String get loginSuccess => _ko ? '로그인에 성공했어요.' : 'Signed in successfully.';
  String get googleFail => _ko
      ? 'Google 로그인에 실패했습니다. 다시 시도해 주세요.'
      : 'Google sign-in failed. Please try again.';
  String get appleFail => _ko
      ? 'Apple 로그인에 실패했습니다. 다시 시도해 주세요.'
      : 'Apple sign-in failed. Please try again.';
  String get terms => _ko
      ? '로그인하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.'
      : 'By signing in, you agree to the Terms and Privacy Policy.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;
  String _uiLanguage = 'English';
  bool _showDebugLog = false;

  _S get _s => _S.of(_uiLanguage);

  @override
  void initState() {
    super.initState();
    _loadUiLanguage();
  }

  Future<void> _loadUiLanguage() async {
    final lang = await LanguagePrefs.getUiLanguage();
    if (mounted) setState(() => _uiLanguage = lang);
  }

  void _showCenterMessage(String message) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1400), () {
      entry.remove();
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _showDebugLog = false;
    });
    try {
      final credential = await AuthService.signInWithGoogle();
      if (credential != null && mounted) {
        _showCenterMessage(_s.loginSuccess);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Login screen Google sign-in error: $e');
      if (mounted) setState(() => _error = _s.googleFail);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showDebugLog = AuthService.debugLogs.isNotEmpty;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final credential = await AuthService.signInWithApple();
      if (credential != null && mounted) {
        _showCenterMessage(_s.loginSuccess);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _s.appleFail);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 72,
                color: Color(0xFF2C3E50),
              ),
              const SizedBox(height: 20),
              Text(
                _s.appTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _s.intro,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s.startFree,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.check_circle_outline,
                      text: _s.feature1,
                      color: const Color(0xFF2C3E50),
                    ),
                    const SizedBox(height: 8),
                    _FeatureRow(
                      icon: Icons.check_circle_outline,
                      text: _s.feature2,
                      color: const Color(0xFF2C3E50),
                    ),
                    const SizedBox(height: 8),
                    _FeatureRow(
                      icon: Icons.check_circle_outline,
                      text: _s.feature3,
                      color: const Color(0xFF2C3E50),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium,
                            size: 16, color: Color(0xFFFFB300)),
                        const SizedBox(width: 8),
                        Text(
                          _s.premiumLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFFB300),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 26),
                  label: Text(_s.continueGoogle),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _signInWithApple,
                  icon: const Icon(Icons.apple, size: 24),
                  label: Text(_s.continueApple),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                _s.terms,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
              // ── 임시 디버그 로그 패널 (APK 디버깅용) ──
              if (_showDebugLog && AuthService.debugLogs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      AuthService.debugLogs.join('\n'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF00FF00),
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
