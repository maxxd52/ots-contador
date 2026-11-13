import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper utility for pumping widgets within standard MaterialApp/Scaffold harnesses
/// ensuring directional context, theme styling, and overlay navigators are available.
class WidgetTestHarness {
  /// Wraps [child] in a testable [MaterialApp] with a [Scaffold] and [Navigator].
  static Widget createTestApp({
    required Widget child,
    ThemeData? theme,
    NavigatorObserver? navigatorObserver,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : const [],
      home: Scaffold(
        body: child,
      ),
    );
  }

  /// Pumps [child] within the test app and settles frames.
  static Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(createTestApp(child: child, theme: theme));
    await tester.pumpAndSettle();
  }
}
