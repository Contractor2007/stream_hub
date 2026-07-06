import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/main.dart';

void main() {
  testWidgets('Stream Hub app launches and shows app bar', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the app launches without crashing
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify the app bar title is rendered
    expect(find.text('STREAM HUB'), findsOneWidget);

    // Verify the LIVE badge is present
    expect(find.text('LIVE'), findsOneWidget);

    // Verify settings and refresh icons are present in the app bar
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
