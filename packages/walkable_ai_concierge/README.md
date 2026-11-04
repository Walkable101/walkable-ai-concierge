# walkable_ai_concierge

A Flutter package that provides Walkable's AI Concierge screen. Users pick an area, a walking duration and the rewards they like, optionally describe what they want, and get recommended walking challenges they can open and join.

> **Demo build.** Recommendations come from `MockRecommendationSource`, which filters fictional challenges in Accra, Osu, East Legon and Cantonments. There is no AI model, backend, authentication, GPS or reward issuance yet. Joining is stored only on the screen.

## Features

- One screen: welcome, area, duration, reward preferences, optional note, **Find Challenges**
- Recommendation cards with distance, duration, reward and a "Why this fits" explanation
- Built-in challenge details view, or your own through `onOpenChallenge`
- Join confirmation bottom sheet with a local "Joined" state
- Loading, empty and error states
- Walkable design: purple `#8C52FF`, system font, pill buttons, 20px cards, CupertinoIcons, light and dark mode
- Works inside `CupertinoApp` or `MaterialApp`. Only depends on `flutter` and `cupertino_icons`.

## Usage

```dart
import 'package:walkable_ai_concierge/walkable_ai_concierge.dart';

Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (_) => ConciergeScreen(
      // Defaults to MockRecommendationSource().
      source: const MockRecommendationSource(),
      onJoined: (challenge) { /* host join logic */ },
      onOpenChallenge: null, // or open the host's own details screen
    ),
  ),
);
```

To connect real recommendations later, implement `RecommendationSource`:

```dart
class MyRecommendationSource implements RecommendationSource {
  @override
  Future<List<ChallengeRecommendation>> recommend(ConciergeRequest request) async {
    // ...
  }
}
```

Material widgets (text field, bottom sheet) are used inside the screen, so a host `CupertinoApp` needs `GlobalMaterialLocalizations.delegate` (or `DefaultMaterialLocalizations.delegate`).

## Try the demo

```sh
cd example
flutter run            # or: flutter run -d chrome
```

Try **Osu + 15 min + Points** to see the empty state, and type "shady" or "beach" in the note to see it reflected in the explanations.

## Development

```sh
dart format .
flutter analyze
flutter test
```
