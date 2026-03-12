import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_bank/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WordBankApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
