import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'db/database_helper.dart';
import 'firebase_options.dart';
import 'screens/library_screen.dart';
import 'screens/login_screen.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();

  final subscriptionService = SubscriptionService();
  await _initializeFirebase();

  // RevenueCat is not supported on web, so keep it behind a guard.
  if (!kIsWeb) {
    try {
      await subscriptionService.initialize();
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
    }
  }

  runApp(
    ChangeNotifierProvider.value(
      value: subscriptionService,
      child: const WordBankApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (_looksLikePlaceholder(options) && defaultTargetPlatform == TargetPlatform.android) {
      // Allow Android to initialize from google-services.json if options are placeholders.
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(options: options);
    }
  } catch (e) {
    debugPrint('Firebase not configured, running without auth: $e');
  }
}

bool _looksLikePlaceholder(FirebaseOptions options) {
  return options.apiKey.startsWith('YOUR_') ||
      options.appId.startsWith('YOUR_') ||
      options.projectId.startsWith('YOUR_') ||
      options.messagingSenderId.startsWith('YOUR_');
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const LibraryScreen();
      },
    );
  }
}
