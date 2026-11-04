import 'models.dart';

/// Demo-only recommendation source. Filters a small catalog of fictional
/// challenges and writes a short "why this fits" explanation from the
/// user's choices. No network calls, no AI model.
class MockRecommendationSource implements RecommendationSource {
  const MockRecommendationSource({
    this.latency = const Duration(milliseconds: 1400),
    this.simulateError = false,
  });

  /// Simulated thinking time so the loading state is visible.
  final Duration latency;

  /// Makes every request fail, to show the error state in the demo.
  final bool simulateError;

  /// Areas shown in the demo. Some combinations intentionally return
  /// nothing (for example Osu + 15 min + Points) to show the empty state.
  static const cities = ['Accra', 'Osu', 'East Legon', 'Cantonments'];

  @override
  Future<List<ChallengeRecommendation>> recommend(
    ConciergeRequest request,
  ) async {
    await Future<void>.delayed(latency);
    if (simulateError) {
      throw StateError('Simulated recommendation failure');
    }

    // The selected duration is a hard maximum: never suggest a longer walk.
    final maxMinutes = request.duration.minutes;

    final matches = _catalog.where((c) {
      if (c.city != request.city) return false;
      if (c.durationMinutes > maxMinutes) return false;
      if (request.rewards.isNotEmpty &&
          !request.rewards.contains(c.rewardType)) {
        return false;
      }
      return true;
    }).toList();

    // Make the most of the user's time: longest walk that still fits first.
    matches.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

    return [
      for (final c in matches.take(4))
        c.copyWith(explanation: _explain(c, request)),
    ];
  }

  String _explain(ChallengeRecommendation c, ConciergeRequest request) {
    final parts = <String>[
      'Takes about ${c.durationMinutes} min, within your '
          '${request.duration.label} limit',
    ];
    if (request.rewards.contains(c.rewardType)) {
      parts.add(
        'matches your ${c.rewardType.label.toLowerCase()} reward preference',
      );
    }
    final note = request.note.toLowerCase();
    final matchedTag = c.tags.where((t) => note.contains(t.toLowerCase()));
    if (matchedTag.isNotEmpty) {
      parts.add('matches your request for "${matchedTag.first}"');
    }
    return '${c.explanation} ${_sentence(parts)}.';
  }

  static String _sentence(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

// Fictional businesses and routes only. Reward labels are sample text:
// descriptions must never say a reward is issued, added or waiting.
const _catalog = <ChallengeRecommendation>[
  ChallengeRecommendation(
    id: 'acc-arch',
    title: 'Independence Arch Loop',
    businessName: 'Starlight Bakery',
    city: 'Accra',
    distanceKm: 2.4,
    durationMinutes: 30,
    rewardLabel: 'Free pastry',
    rewardType: RewardPreference.foodAndDrink,
    explanation: 'A wide, flat loop around famous city landmarks.',
    description:
        'Start at the arch, circle the square and finish near Starlight Bakery. Mostly flat with plenty of space to walk side by side.',
    tags: ['landmarks', 'flat', 'sightseeing', 'history'],
  ),
  ChallengeRecommendation(
    id: 'acc-lighthouse',
    title: 'Lighthouse Heritage Walk',
    businessName: 'Harbourline Outfitters',
    city: 'Accra',
    distanceKm: 3.4,
    durationMinutes: 45,
    rewardLabel: 'GH₵30 store credit',
    rewardType: RewardPreference.retail,
    explanation: 'Old streets and sea views on the way to the lighthouse.',
    description:
        'Wind through historic streets towards the lighthouse, then loop back to finish near Harbourline Outfitters.',
    tags: ['history', 'sea', 'beach', 'culture'],
  ),
  ChallengeRecommendation(
    id: 'osu-oxford',
    title: 'Oxford Street Stroll',
    businessName: 'Osu Bean Co.',
    city: 'Osu',
    distanceKm: 1.6,
    durationMinutes: 20,
    rewardLabel: 'Free iced coffee',
    rewardType: RewardPreference.foodAndDrink,
    explanation: 'A quick, lively walk past the shops and cafés of Osu.',
    description:
        'A short there-and-back along Oxford Street. Busy in the evening, calmer in the morning. Ends at Osu Bean Co.',
    tags: ['coffee', 'shopping', 'busy', 'nightlife'],
  ),
  ChallengeRecommendation(
    id: 'osu-coast',
    title: 'Osu Coastline Walk',
    businessName: 'Sea Breeze Juice Bar',
    city: 'Osu',
    distanceKm: 2.2,
    durationMinutes: 30,
    rewardLabel: '20% off smoothies',
    rewardType: RewardPreference.discounts,
    explanation: 'A breezy seafront route that is best early in the day.',
    description:
        'Follow the coast road with the sea alongside you and finish near Sea Breeze Juice Bar.',
    tags: ['beach', 'sea', 'morning', 'breeze'],
  ),
  ChallengeRecommendation(
    id: 'el-boulevard',
    title: 'Boulevard Power Walk',
    businessName: 'Peak Form Fitness',
    city: 'East Legon',
    distanceKm: 4.8,
    durationMinutes: 60,
    rewardLabel: '400 points',
    rewardType: RewardPreference.points,
    explanation: 'A longer fitness route with steady, even pavements.',
    description:
        'A steady out-and-back along the main boulevard. Good for building distance at an even pace.',
    tags: ['fitness', 'workout', 'long', 'exercise'],
  ),
  ChallengeRecommendation(
    id: 'el-garden',
    title: 'Legon Garden Loop',
    businessName: 'Green Leaf Café',
    city: 'East Legon',
    distanceKm: 1.3,
    durationMinutes: 15,
    rewardLabel: '15% off brunch',
    rewardType: RewardPreference.discounts,
    explanation: 'A short, shady walk through quiet residential streets.',
    description:
        'A gentle loop under the trees, ending at Green Leaf Café. Ideal for a short break or a first challenge.',
    tags: ['shady', 'shade', 'quiet', 'brunch'],
  ),
  ChallengeRecommendation(
    id: 'el-square',
    title: 'Palmview Square Wander',
    businessName: 'Kente Corner Boutique',
    city: 'East Legon',
    distanceKm: 2.5,
    durationMinutes: 30,
    rewardLabel: 'GH₵25 voucher',
    rewardType: RewardPreference.retail,
    explanation: 'Easy walking between local boutiques and food spots.',
    description:
        'Browse the square at your own pace and finish near Kente Corner Boutique.',
    tags: ['shopping', 'market', 'culture'],
  ),
  ChallengeRecommendation(
    id: 'can-embassy',
    title: 'Embassy Row Shade Walk',
    businessName: 'Leafy Lane Books',
    city: 'Cantonments',
    distanceKm: 2.0,
    durationMinutes: 25,
    rewardLabel: '10% off books',
    rewardType: RewardPreference.discounts,
    explanation: 'Quiet, tree-lined avenues with plenty of shade.',
    description:
        'Walk the leafy avenues and finish at Leafy Lane Books. One of the calmest routes in the city.',
    tags: ['shady', 'shade', 'quiet', 'calm'],
  ),
  ChallengeRecommendation(
    id: 'can-ridge',
    title: 'Ridge Sunset Circuit',
    businessName: 'Golden Hour Grill',
    city: 'Cantonments',
    distanceKm: 3.0,
    durationMinutes: 40,
    rewardLabel: 'Free dessert',
    rewardType: RewardPreference.foodAndDrink,
    explanation: 'Timed for golden hour on quiet residential roads.',
    description:
        'A relaxed evening circuit that finishes near Golden Hour Grill as the sun goes down.',
    tags: ['evening', 'sunset', 'dinner'],
  ),
  ChallengeRecommendation(
    id: 'can-mile',
    title: 'Cantonments Morning Mile',
    businessName: 'Mile Club Run Store',
    city: 'Cantonments',
    distanceKm: 1.6,
    durationMinutes: 20,
    rewardLabel: '200 points',
    rewardType: RewardPreference.points,
    explanation: 'A quick morning mile to start the day.',
    description: 'A brisk 1.6 km loop that fits before work.',
    tags: ['morning', 'fitness', 'quick'],
  ),
];
