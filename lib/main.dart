import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'firebase_options.dart';
import 'screens/library_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/subscription_service.dart';

bool _firebaseEnabled = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseEnabled = true;
    await SubscriptionService.initialize();
  } catch (e) {
    // Firebase 미설정 시 인증 없이 실행 (개발 모드)
    debugPrint('Firebase not configured, running without auth: $e');
  }

  runApp(const WordBankApp());
}

class WordBankApp extends StatelessWidget {
  const WordBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Bank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          surface: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
      ),
      home: _firebaseEnabled ? const _AuthGate() : const LibraryScreen(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const LibraryScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
