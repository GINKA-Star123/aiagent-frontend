import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_client/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AIAgent app builds the mobile shell', (tester) async {
    SharedPreferences.setMockInitialValues({'app.onboarding_completed': false});

    await tester.pumpWidget(const AiAgentApp());

    expect(find.byType(AiAgentApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
