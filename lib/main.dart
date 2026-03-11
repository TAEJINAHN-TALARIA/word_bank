import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();
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
      home: const LibraryScreen(),
    );
  }
}
