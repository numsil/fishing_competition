// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followRepositoryHash() => r'e3660e4bea42da5f1e897d6b57a4eff0ba9f2688';

/// See also [followRepository].
@ProviderFor(followRepository)
final followRepositoryProvider = AutoDisposeProvider<FollowRepository>.internal(
  followRepository,
  name: r'followRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$followRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FollowRepositoryRef = AutoDisposeProviderRef<FollowRepository>;
String _$myFollowingsForFeedHash() =>
    r'a59f9bccd6c3c6704e8c471807cebfa642da5144';

/// 피드 상단 팔로우 바 용 — 내가 팔로우한 유저 최대 100명을 캐시.
/// keepAlive 10분: 위젯이 자체 Timer로 셔플하니 잦은 재페치 불필요.
///
/// Copied from [myFollowingsForFeed].
@ProviderFor(myFollowingsForFeed)
final myFollowingsForFeedProvider =
    AutoDisposeFutureProvider<List<FollowUser>>.internal(
      myFollowingsForFeed,
      name: r'myFollowingsForFeedProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myFollowingsForFeedHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyFollowingsForFeedRef = AutoDisposeFutureProviderRef<List<FollowUser>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
