import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'concierge_palette.dart';
import 'mock_recommendation_source.dart';
import 'models.dart';

enum _Status { idle, loading, results, error }

/// The AI Concierge: collects walking preferences, shows recommended
/// challenges and lets the user join one.
class ConciergeScreen extends StatefulWidget {
  const ConciergeScreen({
    super.key,
    this.source = const MockRecommendationSource(),
    this.cities = MockRecommendationSource.cities,
    this.isDemo = true,
    this.onJoined,
    this.onOpenChallenge,
  });

  final RecommendationSource source;
  final List<String> cities;

  /// Shows the "Demo · mock data" badge.
  final bool isDemo;

  /// Called after the user confirms joining. Joining is local-only for now.
  final ValueChanged<ChallengeRecommendation>? onJoined;

  /// Opens a challenge in the host app's own details screen. When null,
  /// the built-in [ConciergeChallengeDetailScreen] is pushed instead.
  final ValueChanged<ChallengeRecommendation>? onOpenChallenge;

  @override
  State<ConciergeScreen> createState() => _ConciergeScreenState();
}

class _ConciergeScreenState extends State<ConciergeScreen> {
  late String _city = widget.cities.first;
  WalkDuration _duration = WalkDuration.medium;
  final Set<RewardPreference> _rewards = {};
  final _noteController = TextEditingController();
  final _resultsKey = GlobalKey();

  _Status _status = _Status.idle;
  List<ChallengeRecommendation> _results = const [];
  final Set<String> _joinedIds = {};
  int _requestId = 0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final requestId = ++_requestId;
    setState(() => _status = _Status.loading);
    _scrollToResults();

    try {
      final results = await widget.source.recommend(
        ConciergeRequest(
          city: _city,
          duration: _duration,
          rewards: Set.of(_rewards),
          note: _noteController.text.trim(),
        ),
      );
      // Ignore an older request that finished after a newer one started.
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _status = _Status.results;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _status = _Status.error);
    }
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultsKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openDetails(ChallengeRecommendation challenge) {
    final open = widget.onOpenChallenge;
    if (open != null) {
      open(challenge);
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ConciergeChallengeDetailScreen(
          challenge: challenge,
          isDemo: widget.isDemo,
          initiallyJoined: _joinedIds.contains(challenge.id),
          // The details button already shows "Joined", so skip the snackbar.
          onJoin: () => _confirmJoin(challenge, showSnackBar: false),
        ),
      ),
    );
  }

  /// Shows the confirmation sheet. Returns true if the user joined.
  Future<bool> _confirmJoin(
    ChallengeRecommendation challenge, {
    bool showSnackBar = true,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: ConciergePalette.of(context).surface,
      builder: (_) => _JoinSheet(challenge: challenge, isDemo: widget.isDemo),
    );
    if (confirmed != true || !mounted) return false;
    HapticFeedback.mediumImpact();
    setState(() => _joinedIds.add(challenge.id));
    widget.onJoined?.call(challenge);
    if (!showSnackBar) return true;
    // A host CupertinoApp may not provide a ScaffoldMessenger.
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You joined ${challenge.title}'),
        ),
      );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(isDemo: widget.isDemo),
                  const SizedBox(height: 24),
                  _Panel(
                    children: [
                      _Section(
                        title: 'Area',
                        child: _ChipWrap(
                          children: [
                            for (final city in widget.cities)
                              _SelectChip(
                                label: city,
                                icon: CupertinoIcons.location,
                                selected: city == _city,
                                onTap: () => setState(() => _city = city),
                              ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Walking duration',
                        child: _ChipWrap(
                          children: [
                            for (final d in WalkDuration.values)
                              _SelectChip(
                                label: d.label,
                                icon: CupertinoIcons.clock,
                                selected: d == _duration,
                                onTap: () => setState(() => _duration = d),
                              ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Rewards you like',
                        subtitle: 'Pick any, or leave blank for all.',
                        child: _ChipWrap(
                          children: [
                            for (final r in RewardPreference.values)
                              _SelectChip(
                                label: r.label,
                                icon: r.icon,
                                selected: _rewards.contains(r),
                                onTap: () => setState(() {
                                  _rewards.contains(r)
                                      ? _rewards.remove(r)
                                      : _rewards.add(r);
                                }),
                              ),
                          ],
                        ),
                      ),
                      _Section(
                        title: 'Anything else?',
                        subtitle: 'Optional',
                        child: _NoteField(controller: _noteController),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _FindButton(
                    loading: _status == _Status.loading,
                    onPressed: _find,
                  ),
                  const SizedBox(height: 28),
                  KeyedSubtree(key: _resultsKey, child: _buildResults()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    switch (_status) {
      case _Status.idle:
        return const SizedBox.shrink();
      case _Status.loading:
        return const _LoadingResults();
      case _Status.error:
        return _MessageState(
          icon: CupertinoIcons.wifi_exclamationmark,
          title: 'Something went wrong',
          message: 'We couldn’t load recommendations. Please try again.',
          actionLabel: 'Try again',
          onAction: _find,
        );
      case _Status.results:
        if (_results.isEmpty) {
          return _MessageState(
            key: const Key('concierge-empty'),
            icon: CupertinoIcons.compass,
            title: 'No challenges match yet',
            message: 'Try a longer walk, fewer reward filters or another area.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultsHeading(count: _results.length, city: _city),
            const SizedBox(height: 14),
            for (final r in _results) ...[
              _RecommendationCard(
                challenge: r,
                joined: _joinedIds.contains(r.id),
                onJoin: () => _confirmJoin(r),
                onOpen: () => _openDetails(r),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Header & form
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.isDemo});

  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(CupertinoIcons.sparkles, color: p.brand, size: 22),
            ),
            const Spacer(),
            if (isDemo) const _DemoBadge(),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Your AI walking concierge',
          style: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us where and how you’d like to walk. We’ll suggest challenges '
          'that fit your time and the rewards you care about.',
          style: TextStyle(fontSize: 15, height: 1.45, color: p.textSecondary),
        ),
      ],
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Semantics(
      label: 'Demo. Recommendations use mock data.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.lab_flask, size: 14, color: p.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Demo · mock data',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13, color: p.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    final fg = selected ? p.onBrand : p.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? p.brand : p.field,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: selected ? p.brand : p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    selected ? CupertinoIcons.checkmark : icon,
                    size: 16,
                    color: selected ? fg : p.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      key: const Key('concierge-note'),
      controller: controller,
      minLines: 2,
      maxLines: 4,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 15, color: p.textPrimary),
      cursorColor: p.brand,
      decoration: InputDecoration(
        hintText: 'e.g. somewhere shady, near the beach, good for mornings',
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        filled: true,
        fillColor: p.field,
        counterStyle: TextStyle(color: p.textSecondary, fontSize: 12),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: border(p.border),
        focusedBorder: border(p.brand),
      ),
    );
  }
}

class _FindButton extends StatelessWidget {
  const _FindButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return SizedBox(
      height: 54,
      child: FilledButton(
        key: const Key('concierge-find'),
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.brand.withValues(alpha: 0.6),
          disabledForegroundColor: p.onBrand,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              CupertinoActivityIndicator(color: p.onBrand, radius: 9)
            else
              const Icon(CupertinoIcons.sparkles, size: 18),
            const SizedBox(width: 10),
            Text(loading ? 'Finding challenges…' : 'Find Challenges'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading({required this.count, required this.city});

  final int count;
  final String city;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'pick' : 'picks'} for you in $city',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Suggested by the concierge from your preferences.',
          style: TextStyle(fontSize: 13, color: p.textSecondary),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.challenge,
    required this.joined,
    required this.onJoin,
    required this.onOpen,
  });

  final ChallengeRecommendation challenge;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return GestureDetector(
      key: Key('concierge-card-${challenge.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: _card(context, p),
    );
  }

  Widget _card(BuildContext context, ConciergePalette p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: joined ? p.brand : p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.brandSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.location_north_fill,
                  color: p.brand,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.businessName,
                      style: TextStyle(fontSize: 13, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              if (joined) ...[
                const SizedBox(width: 8),
                const _JoinedPill(),
              ] else
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: p.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                icon: CupertinoIcons.map,
                label: 'Distance',
                value: '${challenge.distanceKm.toStringAsFixed(1)} km',
              ),
              _Stat(
                icon: CupertinoIcons.clock,
                label: 'Duration',
                value: '${challenge.durationMinutes} min',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RewardRow(challenge: challenge),
          const SizedBox(height: 12),
          _WhyBox(text: challenge.explanation),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: joined
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 18,
                    ),
                    label: const Text('Joined'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      disabledForegroundColor: p.brand,
                      side: BorderSide(color: p.brand.withValues(alpha: 0.4)),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : FilledButton(
                    key: Key('concierge-join-${challenge.id}'),
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.brandSoft,
                      foregroundColor: p.brand,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Join Challenge'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textSecondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.challenge});

  final ChallengeRecommendation challenge;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.gift, size: 18, color: p.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              challenge.rewardLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
          Text(
            challenge.rewardType.label,
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WhyBox extends StatelessWidget {
  const _WhyBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(CupertinoIcons.sparkles, size: 16, color: p.brand),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Why this fits: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.brand,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinedPill extends StatelessWidget {
  const _JoinedPill();

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.brand,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Joined',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.onBrand,
        ),
      ),
    );
  }
}

class _LoadingResults extends StatelessWidget {
  const _LoadingResults();

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Semantics(
      liveRegion: true,
      label: 'Finding challenges',
      child: Column(
        key: const Key('concierge-loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 18, color: p.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Matching challenges to your preferences…',
                  style: TextStyle(fontSize: 14, color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 2; i++) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      bar(46, 46),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(160, 14),
                          const SizedBox(height: 8),
                          bar(100, 12),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  bar(double.infinity, 40),
                  const SizedBox(height: 12),
                  bar(double.infinity, 56),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
            child: Icon(icon, color: p.textSecondary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: p.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: p.brand),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join confirmation
// ---------------------------------------------------------------------------

class _JoinSheet extends StatelessWidget {
  const _JoinSheet({required this.challenge, required this.isDemo});

  final ChallengeRecommendation challenge;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join this challenge?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${challenge.title} · ${challenge.businessName}',
              style: TextStyle(fontSize: 15, color: p.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Stat(
                  icon: CupertinoIcons.map,
                  label: 'Distance',
                  value: '${challenge.distanceKm.toStringAsFixed(1)} km',
                ),
                _Stat(
                  icon: CupertinoIcons.clock,
                  label: 'Duration',
                  value: '${challenge.durationMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RewardRow(challenge: challenge),
            if (isDemo) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(CupertinoIcons.info, size: 16, color: p.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Demo only: joining is saved on this screen and no '
                      'reward is issued.',
                      style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('concierge-confirm-join'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: p.brand,
                  foregroundColor: p.onBrand,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Confirm & Join'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: p.textSecondary),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenge details
// ---------------------------------------------------------------------------

/// Default details view for a recommended challenge. Host apps can show
/// their own screen instead via [ConciergeScreen.onOpenChallenge].
class ConciergeChallengeDetailScreen extends StatefulWidget {
  const ConciergeChallengeDetailScreen({
    super.key,
    required this.challenge,
    required this.onJoin,
    this.initiallyJoined = false,
    this.isDemo = true,
  });

  final ChallengeRecommendation challenge;

  /// Shows the join confirmation. Resolves to true if the user joined.
  final Future<bool> Function() onJoin;
  final bool initiallyJoined;
  final bool isDemo;

  @override
  State<ConciergeChallengeDetailScreen> createState() =>
      _ConciergeChallengeDetailScreenState();
}

class _ConciergeChallengeDetailScreenState
    extends State<ConciergeChallengeDetailScreen> {
  late bool _joined = widget.initiallyJoined;

  Future<void> _join() async {
    final joined = await widget.onJoin();
    if (joined && mounted) setState(() => _joined = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ConciergePalette.of(context);
    final c = widget.challenge;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.chevron_back, color: p.brand),
                        Text(
                          'Recommendations',
                          style: TextStyle(fontSize: 16, color: p.brand),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.isDemo) const _DemoBadge(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: p.brandSoft,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                CupertinoIcons.location_north_fill,
                                color: p.brand,
                                size: 28,
                              ),
                            ),
                            const Spacer(),
                            if (_joined) const _JoinedPill(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          c.title,
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${c.businessName} · ${c.city}',
                          style: TextStyle(
                            fontSize: 15,
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _Stat(
                                    icon: CupertinoIcons.map,
                                    label: 'Distance',
                                    value:
                                        '${c.distanceKm.toStringAsFixed(1)} km',
                                  ),
                                  _Stat(
                                    icon: CupertinoIcons.clock,
                                    label: 'Duration',
                                    value: '${c.durationMinutes} min',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _RewardRow(challenge: c),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _WhyBox(text: c.explanation),
                        if (c.description.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Text(
                            'About this route',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            c.description,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                        if (c.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in c.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.field,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: p.border),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    key: const Key('concierge-detail-join'),
                    onPressed: _joined ? null : _join,
                    icon: Icon(
                      _joined
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.person_add,
                      size: 20,
                    ),
                    label: Text(_joined ? 'Joined' : 'Join Challenge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.brand,
                      foregroundColor: p.onBrand,
                      disabledBackgroundColor: p.brandSoft,
                      disabledForegroundColor: p.brand,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
