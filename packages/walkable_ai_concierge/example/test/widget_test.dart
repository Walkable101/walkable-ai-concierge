import 'package:flutter_test/flutter_test.dart';
import 'package:walkable_ai_concierge_example/main.dart';

void main() {
  testWidgets('demo app launches the concierge screen', (tester) async {
    await tester.pumpWidget(const ConciergeDemoApp());
    expect(find.text('Your AI walking concierge'), findsOneWidget);
    expect(find.text('Demo · mock data'), findsOneWidget);
  });
}
