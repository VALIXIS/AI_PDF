import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf_ai_toolkit/services/analytics_service.dart';

/// Features that can be unlocked via high-eCPM rewarded video ads.
enum UnlockFeature {
  vectorExport,
  aiSummaries,
}

extension UnlockFeatureExtension on UnlockFeature {
  String get title {
    switch (this) {
      case UnlockFeature.vectorExport:
        return 'High-Resolution Vector Export';
      case UnlockFeature.aiSummaries:
        return 'Multi-Page AI Summaries';
    }
  }

  String get shortName {
    switch (this) {
      case UnlockFeature.vectorExport:
        return 'Vector Export';
      case UnlockFeature.aiSummaries:
        return 'AI Summaries';
    }
  }

  String get description {
    switch (this) {
      case UnlockFeature.vectorExport:
        return 'Export 300+ DPI ultra-crisp vector PDFs without raster compression.';
      case UnlockFeature.aiSummaries:
        return 'Generate unlimited executive briefs & action items from large multi-page PDFs.';
    }
  }

  IconData get icon {
    switch (this) {
      case UnlockFeature.vectorExport:
        return Icons.high_quality_rounded;
      case UnlockFeature.aiSummaries:
        return Icons.auto_awesome_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UnlockFeature.vectorExport:
        return const Color(0xFF0EA5E9);
      case UnlockFeature.aiSummaries:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// High-eCPM Rewarded Video Ad & Feature Unlock Engine for AI PDF Maker.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  final Map<UnlockFeature, DateTime> _unlockExpiryMap = {};
  bool _isPreloading = false;
  bool _isAdReady = false;
  int _totalAdsWatched = 0;
  int _totalRewardsEarned = 0;

  bool get isAdReady => _isAdReady;
  int get totalAdsWatched => _totalAdsWatched;
  int get totalRewardsEarned => _totalRewardsEarned;

  /// Default duration granted per rewarded ad watch (1 hour).
  static const Duration defaultUnlockDuration = Duration(hours: 1);

  /// Pre-loads high-eCPM rewarded ad assets to ensure instant zero-latency playback.
  Future<void> preloadRewardedVideoAd() async {
    if (_isPreloading || _isAdReady) return;
    _isPreloading = true;
    try {
      // Simulate fast network pre-fetch of rewarded video creative manifest & tracking
      await Future.delayed(const Duration(milliseconds: 350));
      _isAdReady = true;
      AnalyticsService().logOperationSuccess('ad_preload_success');
    } catch (e) {
      _isAdReady = false;
      AnalyticsService().logNonFatalException(e);
    } finally {
      _isPreloading = false;
    }
  }

  /// Checks whether a premium feature is currently unlocked with an active token.
  bool isFeatureUnlocked(UnlockFeature feature) {
    final expiry = _unlockExpiryMap[feature];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Returns the remaining unlock duration in minutes.
  int getRemainingMinutes(UnlockFeature feature) {
    final expiry = _unlockExpiryMap[feature];
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Grants temporary unlock token for the specified feature.
  void grantUnlock(
    UnlockFeature feature, {
    Duration duration = defaultUnlockDuration,
  }) {
    final currentExpiry = _unlockExpiryMap[feature];
    final baseTime = (currentExpiry != null && currentExpiry.isAfter(DateTime.now()))
        ? currentExpiry
        : DateTime.now();

    _unlockExpiryMap[feature] = baseTime.add(duration);
    _totalRewardsEarned++;
    AnalyticsService().logOperationSuccess('reward_granted_${feature.name}');
  }

  /// Revokes an unlock token (primarily for testing/session resets).
  void revokeUnlock(UnlockFeature feature) {
    _unlockExpiryMap.remove(feature);
  }

  /// Clears all unlock tokens.
  void clearAllUnlocks() {
    _unlockExpiryMap.clear();
  }

  /// Displays the High-eCPM Rewarded Video Ad overlay.
  /// If the ad completes, calls [onRewarded], grants the unlock token, and shows the reward celebration.
  Future<bool> showRewardedVideoAd({
    required BuildContext context,
    required Function onRewarded,
    UnlockFeature? featureToUnlock,
    String? customRewardTitle,
    VoidCallback? onAdClosed,
    Function(String error)? onError,
  }) async {
    // 1. Show clean loading overlay if ad is not yet pre-buffered
    if (!_isAdReady) {
      final loadingFuture = preloadRewardedVideoAd();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _AdLoadingDialog(),
      );

      await loadingFuture;

      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Dismiss loading dialog
      }
    }

    if (!context.mounted) return false;

    // Reset pre-load flag so next ad gets prepared
    _isAdReady = false;

    // 2. Launch high-eCPM Rewarded Video Ad Modal
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Rewarded Ad',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return _RewardedVideoPlayerModal(
          feature: featureToUnlock ?? UnlockFeature.vectorExport,
          customRewardTitle: customRewardTitle,
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
            child: child,
          ),
        );
      },
    );

    // Pre-load next ad in background
    unawaited(preloadRewardedVideoAd());

    final bool rewardGranted = result == true;

    if (rewardGranted) {
      _totalAdsWatched++;
      if (featureToUnlock != null) {
        grantUnlock(featureToUnlock);
      }

      try {
        onRewarded();
      } catch (e) {
        AnalyticsService().logNonFatalException(e);
      }

      // 3. Display Reward Confirmation Checkmark Celebration
      if (context.mounted) {
        await _showRewardGrantedCelebration(
          context: context,
          feature: featureToUnlock ?? UnlockFeature.vectorExport,
          customTitle: customRewardTitle,
        );
      }

      if (onAdClosed != null) onAdClosed();
      return true;
    } else {
      if (onAdClosed != null) onAdClosed();
      return false;
    }
  }

  /// Displays the confirmation checkmark dialog after reward is granted.
  Future<void> _showRewardGrantedCelebration({
    required BuildContext context,
    required UnlockFeature feature,
    String? customTitle,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) => _RewardGrantedDialog(
        feature: feature,
        customTitle: customTitle,
      ),
    );
  }

  /// Gating Helper: Checks if feature is unlocked. If not, shows an unlock prompt dialog.
  /// Returns `true` if feature is already unlocked or if user unlocked it via ad.
  Future<bool> ensureFeatureUnlocked(
    BuildContext context, {
    required UnlockFeature feature,
    String? customPrompt,
  }) async {
    if (isFeatureUnlocked(feature)) {
      return true;
    }

    final bool? watchAd = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnlockPromptBottomSheet(
        feature: feature,
        customPrompt: customPrompt,
      ),
    );

    if (watchAd == true && context.mounted) {
      return await showRewardedVideoAd(
        context: context,
        featureToUnlock: feature,
        onRewarded: () {},
      );
    }

    return false;
  }
}

/// Loading indicator during ad loading.
class _AdLoadingDialog extends StatelessWidget {
  const _AdLoadingDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading Video Ad...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting to high-eCPM ad network...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// High-eCPM Rewarded Video Ad Modal with progress bar, countdown timer, sound toggle, and sponsor cards.
class _RewardedVideoPlayerModal extends StatefulWidget {
  final UnlockFeature feature;
  final String? customRewardTitle;

  const _RewardedVideoPlayerModal({
    Key? key,
    required this.feature,
    this.customRewardTitle,
  }) : super(key: key);

  @override
  State<_RewardedVideoPlayerModal> createState() =>
      _RewardedVideoPlayerModalState();
}

class _RewardedVideoPlayerModalState extends State<_RewardedVideoPlayerModal>
    with SingleTickerProviderStateMixin {
  static const int _adDurationSeconds = 5; // Snappy 5-second rewarded experience for smooth UX
  int _secondsRemaining = _adDurationSeconds;
  bool _rewardEarned = false;
  bool _isMuted = false;
  Timer? _timer;
  late AnimationController _progressController;

  final List<Map<String, dynamic>> _adSponsors = [
    {
      'sponsor': 'Gemini Ultra 2.0',
      'tagline': 'Advanced Multimodal Document Reasoning',
      'cta': 'Try Cloud AI',
      'color': const Color(0xFF6366F1),
      'icon': Icons.auto_awesome_rounded,
    },
    {
      'sponsor': 'VectorPDF Cloud Engine',
      'tagline': '300 DPI Ultra Lossless PDF Rendering',
      'cta': 'Upgrade Pro',
      'color': const Color(0xFF0EA5E9),
      'icon': Icons.high_quality_rounded,
    },
    {
      'sponsor': 'AI Smart Signatures',
      'tagline': 'Legally Binding Cryptographic PDF Seals',
      'cta': 'Explore Now',
      'color': const Color(0xFF10B981),
      'icon': Icons.draw_rounded,
    },
  ];

  late final Map<String, dynamic> _currentSponsor;

  @override
  void initState() {
    super.initState();
    _currentSponsor =
        _adSponsors[math.Random().nextInt(_adSponsors.length)];

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _adDurationSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _rewardEarned = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _onClosePressed() {
    if (_rewardEarned) {
      Navigator.pop(context, true);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Leave Video Ad?'),
          content: Text(
            'If you close now, you will lose your free unlock for ${widget.customRewardTitle ?? widget.feature.title}.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // dismiss dialog
                Navigator.pop(context, false); // close ad without reward
              },
              child: const Text('Close Anyway',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Watching'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sponsorColor = _currentSponsor['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Ad Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Ad badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AD',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Timer / Reward Status Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _rewardEarned
                              ? Icons.check_circle_rounded
                              : Icons.timer_rounded,
                          color: _rewardEarned
                              ? const Color(0xFF22C55E)
                              : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _rewardEarned
                              ? 'Reward Earned!'
                              : 'Reward in $_secondsRemaining s',
                          style: TextStyle(
                            color: _rewardEarned
                                ? const Color(0xFF22C55E)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Sound Mute Toggle
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),

                  // Close / Claim Button
                  IconButton(
                    icon: Icon(
                      _rewardEarned
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      color: _rewardEarned
                          ? const Color(0xFF22C55E)
                          : Colors.white70,
                    ),
                    onPressed: _onClosePressed,
                  ),
                ],
              ),
            ),

            // Video Progress Bar
            AnimatedBuilder(
              animation: _progressController,
              builder: (ctx, _) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _rewardEarned
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF8B5CF6),
                  ),
                  minHeight: 3,
                );
              },
            ),

            // Video Creative Container (Interactive High-eCPM Simulation)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      sponsorColor.withValues(alpha: 0.35),
                      const Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: sponsorColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sponsorColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sponsor Logo Icon
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: sponsorColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: sponsorColor, width: 2),
                          ),
                          child: Icon(
                            _currentSponsor['icon'] as IconData,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sponsor Title
                        Text(
                          _currentSponsor['sponsor'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tagline
                        Text(
                          _currentSponsor['tagline'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Unlocking Feature Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Unlocking: ${widget.customRewardTitle ?? widget.feature.title}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom CTA & Claim Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _rewardEarned
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 22, color: Colors.white),
                        label: const Text(
                          'Claim Free Unlock Reward',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Reward unlocks in $_secondsRemaining seconds...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation Checkmark Celebration Dialog displaying granted reward & token active duration.
class _RewardGrantedDialog extends StatelessWidget {
  final UnlockFeature feature;
  final String? customTitle;

  const _RewardGrantedDialog({
    Key? key,
    required this.feature,
    this.customTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Confirmation Checkmark Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF22C55E), width: 3),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF22C55E),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Reward Granted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                '${customTitle ?? feature.title} has been unlocked for 1 hour of free unlimited use.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Active Token Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: feature.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feature.icon, color: feature.color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Token Active: 60 min remaining',
                      style: TextStyle(
                        color: feature.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue with Export',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet prompting the user to watch a rewarded video ad to unlock a premium feature.
class _UnlockPromptBottomSheet extends StatelessWidget {
  final UnlockFeature feature;
  final String? customPrompt;

  const _UnlockPromptBottomSheet({
    Key? key,
    required this.feature,
    this.customPrompt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // Feature Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: feature.color.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(feature.icon, color: feature.color, size: 30),
            ),
            const SizedBox(height: 14),

            // Feature Title
            Text(
              feature.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              customPrompt ?? feature.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Unlock Details Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D2D42)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Watch 1 Ad = 1 Hour Free Pass',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Enjoy unlimited exports and full feature access.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Watch Ad Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.play_circle_filled_rounded,
                    color: Colors.white, size: 22),
                label: const Text(
                  'Watch Ad to Unlock Free Export',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dismiss Button
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable Widget: Watch Ad Unlock Button for dialogs and export screens.
class WatchAdUnlockButton extends StatelessWidget {
  final UnlockFeature feature;
  final VoidCallback onUnlocked;
  final String? customLabel;

  const WatchAdUnlockButton({
    Key? key,
    required this.feature,
    required this.onUnlocked,
    this.customLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adService = AdService();
    final bool isUnlocked = adService.isFeatureUnlocked(feature);

    if (isUnlocked) {
      final minutes = adService.getRemainingMinutes(feature);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 14),
            const SizedBox(width: 6),
            Text(
              'Unlocked (${minutes}m left)',
              style: const TextStyle(
                color: Color(0xFF22C55E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        await adService.showRewardedVideoAd(
          context: context,
          featureToUnlock: feature,
          onRewarded: onUnlocked,
        );
      },
      icon: const Icon(Icons.play_circle_filled_rounded,
          size: 16, color: Colors.white),
      label: Text(
        customLabel ?? 'Watch Ad to Unlock Free',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}
