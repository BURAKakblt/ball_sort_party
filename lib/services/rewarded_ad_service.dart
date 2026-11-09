/// Result of showing a rewarded ad.
enum AdResult {
  /// The SDK confirmed the user watched the ad to the end.
  completed,

  /// Closed early, failed to load or not available. Never reward.
  notCompleted,
}

/// What a rewarded ad unlocks.
enum AdPlacement { rescue, extraLife }

/// Contract for a rewarded-ad provider (e.g. AdMob later).
///
/// Callers must grant a reward **only** when [show] returns
/// [AdResult.completed], which an implementation may return only after the ad
/// SDK's own "reward earned" callback fired.
abstract interface class RewardedAdService {
  /// Whether an ad can be shown right now.
  bool isReady(AdPlacement placement);

  Future<AdResult> show(AdPlacement placement);
}

/// Current implementation: no ad SDK is integrated, so ads are never ready
/// and never reward. UI shows these buttons as "YAKINDA" (disabled).
class UnavailableRewardedAdService implements RewardedAdService {
  const UnavailableRewardedAdService();

  @override
  bool isReady(AdPlacement placement) => false;

  @override
  Future<AdResult> show(AdPlacement placement) async => AdResult.notCompleted;
}
