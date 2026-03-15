import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../app_strings.dart';
import '../services/auth_service.dart';
import '../services/language_prefs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;
  String _uiLanguage = 'English';

  AppStrings get _s => AppStrings.of(_uiLanguage);

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
      if (mounted) setState(() => _isLoading = false);
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    else if (Platform.isIOS)
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
                      )
                    else
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
                    const SizedBox(height: 24),
                    Text(
                      _s.terms,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ),
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
