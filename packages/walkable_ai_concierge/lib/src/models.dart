import 'package:flutter/cupertino.dart';

/// How long the user wants to walk.
enum WalkDuration {
  short(15, '15 min'),
  medium(30, '30 min'),
  long(45, '45 min'),
  extended(60, '60+ min');

  const WalkDuration(this.minutes, this.label);

  final int minutes;
  final String label;
}

/// The kind of reward the user would like to earn.
enum RewardPreference {
  foodAndDrink('Food & Drink', CupertinoIcons.flame),
  retail('Shopping', CupertinoIcons.bag),
  discounts('Discounts', CupertinoIcons.tag),
  points('Points', CupertinoIcons.star);

  const RewardPreference(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Everything the user chose on the concierge screen.
@immutable
class ConciergeRequest {
  const ConciergeRequest({
    required this.city,
    required this.duration,
    this.rewards = const {},
    this.note = '',
  });

  final String city;
  final WalkDuration duration;

  /// Empty means "no preference".
  final Set<RewardPreference> rewards;

  /// Optional free-text request, e.g. "somewhere shady near the beach".
  final String note;
}

/// One recommended walking challenge.
@immutable
class ChallengeRecommendation {
  const ChallengeRecommendation({
    required this.id,
    required this.title,
    required this.businessName,
    required this.city,
    required this.distanceKm,
    required this.durationMinutes,
    required this.rewardLabel,
    required this.rewardType,
    required this.explanation,
    this.description = '',
    this.tags = const [],
  });

  final String id;
  final String title;
  final String businessName;
  final String city;
  final double distanceKm;
  final int durationMinutes;
  final String rewardLabel;
  final RewardPreference rewardType;

  /// Why the concierge picked this challenge for the user.
  final String explanation;

  /// Longer route description for the details view.
  final String description;
  final List<String> tags;

  ChallengeRecommendation copyWith({String? explanation}) {
    return ChallengeRecommendation(
      id: id,
      title: title,
      businessName: businessName,
      city: city,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      rewardLabel: rewardLabel,
      rewardType: rewardType,
      explanation: explanation ?? this.explanation,
      description: description,
      tags: tags,
    );
  }
}

/// Produces recommendations for a request. The demo uses
/// [MockRecommendationSource]; the real app will plug in an AI-backed source.
abstract interface class RecommendationSource {
  Future<List<ChallengeRecommendation>> recommend(ConciergeRequest request);
}
