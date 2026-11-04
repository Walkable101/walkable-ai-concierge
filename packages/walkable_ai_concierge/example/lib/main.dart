import 'package:flutter/material.dart';
import 'package:walkable_ai_concierge/walkable_ai_concierge.dart';

void main() => runApp(const ConciergeDemoApp());

/// Standalone demo of the AI Concierge. All recommendations are mock data.
///
/// On the web, add `?scenario=error` to the URL to see the error state.
class ConciergeDemoApp extends StatelessWidget {
  const ConciergeDemoApp({super.key, this.simulateError});

  /// Overrides the `?scenario=error` URL switch (used by tests).
  final bool? simulateError;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: ConciergePalette.walkablePurple,
    );
    final failing =
        simulateError ?? Uri.base.queryParameters['scenario'] == 'error';

    return MaterialApp(
      title: 'Walkable AI Concierge (Demo)',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: ConciergeScreen(
        source: MockRecommendationSource(simulateError: failing),
      ),
    );
  }
}
