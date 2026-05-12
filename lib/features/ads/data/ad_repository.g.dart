// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$adRepositoryHash() => r'61da62029183f8049707386104efb2e07abfa6a2';

/// See also [adRepository].
@ProviderFor(adRepository)
final adRepositoryProvider = AutoDisposeProvider<AdRepository>.internal(
  adRepository,
  name: r'adRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdRepositoryRef = AutoDisposeProviderRef<AdRepository>;
String _$adViewTrackerHash() => r'974df29da7947ffa73e932573e3afbd4838c1d42';

/// See also [adViewTracker].
@ProviderFor(adViewTracker)
final adViewTrackerProvider = Provider<AdViewTracker>.internal(
  adViewTracker,
  name: r'adViewTrackerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adViewTrackerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdViewTrackerRef = ProviderRef<AdViewTracker>;
String _$activeFeedAdsHash() => r'be4a99434eced75fc99d056d757c614be54e3cc1';

/// 피드 광고 풀. 10분 keepAlive (위젯에서 자체 셔플/회전).
///
/// Copied from [activeFeedAds].
@ProviderFor(activeFeedAds)
final activeFeedAdsProvider = AutoDisposeFutureProvider<List<AdFeed>>.internal(
  activeFeedAds,
  name: r'activeFeedAdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeFeedAdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveFeedAdsRef = AutoDisposeFutureProviderRef<List<AdFeed>>;
String _$adGapConfigHash() => r'957a8acc370e91ce3efbee9a3dfa574107488f3a';

/// See also [adGapConfig].
@ProviderFor(adGapConfig)
final adGapConfigProvider = AutoDisposeFutureProvider<AdGapConfig>.internal(
  adGapConfig,
  name: r'adGapConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adGapConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdGapConfigRef = AutoDisposeFutureProviderRef<AdGapConfig>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
