import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkable_ai_concierge/walkable_ai_concierge.dart';

const _latency = Duration(milliseconds: 500);

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: ConciergeScreen(
        source: MockRecommendationSource(latency: _latency),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the form and demo badge', (tester) async {
    await _pumpScreen(tester);
    expect(find.text('Your AI walking concierge'), findsOneWidget);
    expect(find.text('Demo · mock data'), findsOneWidget);
    expect(find.text('Accra'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('Food & Drink'), findsOneWidget);
    expect(find.byKey(const Key('concierge-note')), findsOneWidget);
    expect(find.text('Find Challenges'), findsOneWidget);
  });

  testWidgets('loading, results, join confirmation and joined state', (
    tester,
  ) async {
    final joined = <String>[];
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ConciergeScreen(
          source: const MockRecommendationSource(latency: _latency),
          onJoined: (c) => joined.add(c.id),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump();
    expect(find.byKey(const Key('concierge-loading')), findsOneWidget);
    expect(find.text('Finding challenges…'), findsOneWidget);

    await tester.pump(_latency);
    await tester.pumpAndSettle();
    expect(find.textContaining('for you in Accra'), findsOneWidget);
    expect(find.text('Independence Arch Loop'), findsOneWidget);
    expect(find.textContaining('Why this fits'), findsWidgets);

    await tester.tap(find.byKey(const Key('concierge-join-acc-arch')));
    await tester.pumpAndSettle();
    expect(find.text('Join this challenge?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('concierge-confirm-join')));
    await tester.pumpAndSettle();
    expect(find.text('Join this challenge?'), findsNothing);
    expect(find.text('Joined'), findsNWidgets(2)); // pill + button
    expect(find.text('You joined Independence Arch Loop'), findsOneWidget);
    expect(joined, ['acc-arch']);
  });

  testWidgets('shows the empty state when nothing matches', (tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('Osu'));
    await tester.tap(find.text('15 min'));
    await tester.tap(find.text('Points'));
    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump(_latency);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('concierge-empty')), findsOneWidget);
    expect(find.text('No challenges match yet'), findsOneWidget);
  });

  test('mock source filters by city, duration and reward', () async {
    const source = MockRecommendationSource(latency: Duration.zero);
    final results = await source.recommend(
      const ConciergeRequest(
        city: 'East Legon',
        duration: WalkDuration.short,
        rewards: {RewardPreference.discounts},
        note: 'somewhere shady',
      ),
    );
    expect(results.map((r) => r.id), ['el-garden']);
    expect(results.single.explanation, contains('"shady"'));
  });

  testWidgets('details view opens by default and can join', (tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump(_latency);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('concierge-card-acc-arch')));
    await tester.pumpAndSettle();
    expect(find.text('About this route'), findsOneWidget);

    await tester.tap(find.byKey(const Key('concierge-detail-join')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('concierge-confirm-join')));
    await tester.pumpAndSettle();
    expect(find.text('Joined'), findsNWidgets(2)); // pill + button

    await tester.tap(find.text('Recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('About this route'), findsNothing);
    expect(find.text('Joined'), findsNWidgets(2)); // card pill + button
  });

  testWidgets('host callback replaces the built-in details view', (
    tester,
  ) async {
    ChallengeRecommendation? opened;
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ConciergeScreen(
          source: const MockRecommendationSource(latency: _latency),
          onOpenChallenge: (c) => opened = c,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump(_latency);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('concierge-card-acc-arch')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'acc-arch');
    expect(find.text('About this route'), findsNothing);
  });

  testWidgets('works inside a CupertinoApp in dark mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.dark),
        localizationsDelegates: [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        home: ConciergeScreen(
          source: MockRecommendationSource(latency: _latency),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump(_latency);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('concierge-join-acc-arch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('concierge-confirm-join')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Joined'), findsNWidgets(2));
  });

  testWidgets('shows the error state and can retry', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ConciergeScreen(
          source: MockRecommendationSource(
            latency: _latency,
            simulateError: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('concierge-find')));
    await tester.pump(_latency);
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
