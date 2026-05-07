// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$leagueRepositoryHash() => r'e9995140e6a3bfea2b249ca0181ee923a439f5eb';

/// See also [leagueRepository].
@ProviderFor(leagueRepository)
final leagueRepositoryProvider = AutoDisposeProvider<LeagueRepository>.internal(
  leagueRepository,
  name: r'leagueRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$leagueRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeagueRepositoryRef = AutoDisposeProviderRef<LeagueRepository>;
String _$myJoinedLeaguesHash() => r'097e7b31b8a668e67476d5cf29d6a65ad9c275ff';

/// See also [myJoinedLeagues].
@ProviderFor(myJoinedLeagues)
final myJoinedLeaguesProvider =
    AutoDisposeFutureProvider<List<League>>.internal(
      myJoinedLeagues,
      name: r'myJoinedLeaguesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myJoinedLeaguesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyJoinedLeaguesRef = AutoDisposeFutureProviderRef<List<League>>;
String _$isJoinedHash() => r'4b099d59414dbac4d5fa2aa8ebff80675c837f21';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [isJoined].
@ProviderFor(isJoined)
const isJoinedProvider = IsJoinedFamily();

/// See also [isJoined].
class IsJoinedFamily extends Family<AsyncValue<bool>> {
  /// See also [isJoined].
  const IsJoinedFamily();

  /// See also [isJoined].
  IsJoinedProvider call(String leagueId) {
    return IsJoinedProvider(leagueId);
  }

  @override
  IsJoinedProvider getProviderOverride(covariant IsJoinedProvider provider) {
    return call(provider.leagueId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isJoinedProvider';
}

/// See also [isJoined].
class IsJoinedProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [isJoined].
  IsJoinedProvider(String leagueId)
    : this._internal(
        (ref) => isJoined(ref as IsJoinedRef, leagueId),
        from: isJoinedProvider,
        name: r'isJoinedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$isJoinedHash,
        dependencies: IsJoinedFamily._dependencies,
        allTransitiveDependencies: IsJoinedFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  IsJoinedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leagueId,
  }) : super.internal();

  final String leagueId;

  @override
  Override overrideWith(FutureOr<bool> Function(IsJoinedRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: IsJoinedProvider._internal(
        (ref) => create(ref as IsJoinedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leagueId: leagueId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _IsJoinedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsJoinedProvider && other.leagueId == leagueId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leagueId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsJoinedRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _IsJoinedProviderElement extends AutoDisposeFutureProviderElement<bool>
    with IsJoinedRef {
  _IsJoinedProviderElement(super.provider);

  @override
  String get leagueId => (origin as IsJoinedProvider).leagueId;
}

String _$leagueRankingHash() => r'03ba07038b93db85ae943ea5ef0770f56f007bdf';

/// See also [leagueRanking].
@ProviderFor(leagueRanking)
const leagueRankingProvider = LeagueRankingFamily();

/// See also [leagueRanking].
class LeagueRankingFamily extends Family<AsyncValue<List<LeagueRankEntry>>> {
  /// See also [leagueRanking].
  const LeagueRankingFamily();

  /// See also [leagueRanking].
  LeagueRankingProvider call(String leagueId) {
    return LeagueRankingProvider(leagueId);
  }

  @override
  LeagueRankingProvider getProviderOverride(
    covariant LeagueRankingProvider provider,
  ) {
    return call(provider.leagueId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leagueRankingProvider';
}

/// See also [leagueRanking].
class LeagueRankingProvider
    extends AutoDisposeFutureProvider<List<LeagueRankEntry>> {
  /// See also [leagueRanking].
  LeagueRankingProvider(String leagueId)
    : this._internal(
        (ref) => leagueRanking(ref as LeagueRankingRef, leagueId),
        from: leagueRankingProvider,
        name: r'leagueRankingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leagueRankingHash,
        dependencies: LeagueRankingFamily._dependencies,
        allTransitiveDependencies:
            LeagueRankingFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  LeagueRankingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leagueId,
  }) : super.internal();

  final String leagueId;

  @override
  Override overrideWith(
    FutureOr<List<LeagueRankEntry>> Function(LeagueRankingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeagueRankingProvider._internal(
        (ref) => create(ref as LeagueRankingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leagueId: leagueId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LeagueRankEntry>> createElement() {
    return _LeagueRankingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeagueRankingProvider && other.leagueId == leagueId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leagueId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeagueRankingRef on AutoDisposeFutureProviderRef<List<LeagueRankEntry>> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _LeagueRankingProviderElement
    extends AutoDisposeFutureProviderElement<List<LeagueRankEntry>>
    with LeagueRankingRef {
  _LeagueRankingProviderElement(super.provider);

  @override
  String get leagueId => (origin as LeagueRankingProvider).leagueId;
}

String _$leagueUserPostsHash() => r'bdee3fb8988ceedb9c29cecaff85887714b1208d';

/// See also [leagueUserPosts].
@ProviderFor(leagueUserPosts)
const leagueUserPostsProvider = LeagueUserPostsFamily();

/// See also [leagueUserPosts].
class LeagueUserPostsFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [leagueUserPosts].
  const LeagueUserPostsFamily();

  /// See also [leagueUserPosts].
  LeagueUserPostsProvider call(String leagueId, String userId) {
    return LeagueUserPostsProvider(leagueId, userId);
  }

  @override
  LeagueUserPostsProvider getProviderOverride(
    covariant LeagueUserPostsProvider provider,
  ) {
    return call(provider.leagueId, provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leagueUserPostsProvider';
}

/// See also [leagueUserPosts].
class LeagueUserPostsProvider extends AutoDisposeFutureProvider<List<Post>> {
  /// See also [leagueUserPosts].
  LeagueUserPostsProvider(String leagueId, String userId)
    : this._internal(
        (ref) => leagueUserPosts(ref as LeagueUserPostsRef, leagueId, userId),
        from: leagueUserPostsProvider,
        name: r'leagueUserPostsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leagueUserPostsHash,
        dependencies: LeagueUserPostsFamily._dependencies,
        allTransitiveDependencies:
            LeagueUserPostsFamily._allTransitiveDependencies,
        leagueId: leagueId,
        userId: userId,
      );

  LeagueUserPostsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leagueId,
    required this.userId,
  }) : super.internal();

  final String leagueId;
  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<Post>> Function(LeagueUserPostsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeagueUserPostsProvider._internal(
        (ref) => create(ref as LeagueUserPostsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leagueId: leagueId,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Post>> createElement() {
    return _LeagueUserPostsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeagueUserPostsProvider &&
        other.leagueId == leagueId &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leagueId.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeagueUserPostsRef on AutoDisposeFutureProviderRef<List<Post>> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;

  /// The parameter `userId` of this provider.
  String get userId;
}

class _LeagueUserPostsProviderElement
    extends AutoDisposeFutureProviderElement<List<Post>>
    with LeagueUserPostsRef {
  _LeagueUserPostsProviderElement(super.provider);

  @override
  String get leagueId => (origin as LeagueUserPostsProvider).leagueId;
  @override
  String get userId => (origin as LeagueUserPostsProvider).userId;
}

String _$leaguePendingHash() => r'23078c12b26801290a3a86b351aee837b6f30fbc';

/// See also [leaguePending].
@ProviderFor(leaguePending)
const leaguePendingProvider = LeaguePendingFamily();

/// See also [leaguePending].
class LeaguePendingFamily extends Family<AsyncValue<List<LeaguePendingEntry>>> {
  /// See also [leaguePending].
  const LeaguePendingFamily();

  /// See also [leaguePending].
  LeaguePendingProvider call(String leagueId) {
    return LeaguePendingProvider(leagueId);
  }

  @override
  LeaguePendingProvider getProviderOverride(
    covariant LeaguePendingProvider provider,
  ) {
    return call(provider.leagueId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leaguePendingProvider';
}

/// See also [leaguePending].
class LeaguePendingProvider
    extends AutoDisposeFutureProvider<List<LeaguePendingEntry>> {
  /// See also [leaguePending].
  LeaguePendingProvider(String leagueId)
    : this._internal(
        (ref) => leaguePending(ref as LeaguePendingRef, leagueId),
        from: leaguePendingProvider,
        name: r'leaguePendingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leaguePendingHash,
        dependencies: LeaguePendingFamily._dependencies,
        allTransitiveDependencies:
            LeaguePendingFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  LeaguePendingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leagueId,
  }) : super.internal();

  final String leagueId;

  @override
  Override overrideWith(
    FutureOr<List<LeaguePendingEntry>> Function(LeaguePendingRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeaguePendingProvider._internal(
        (ref) => create(ref as LeaguePendingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leagueId: leagueId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LeaguePendingEntry>> createElement() {
    return _LeaguePendingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeaguePendingProvider && other.leagueId == leagueId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leagueId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeaguePendingRef
    on AutoDisposeFutureProviderRef<List<LeaguePendingEntry>> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _LeaguePendingProviderElement
    extends AutoDisposeFutureProviderElement<List<LeaguePendingEntry>>
    with LeaguePendingRef {
  _LeaguePendingProviderElement(super.provider);

  @override
  String get leagueId => (origin as LeaguePendingProvider).leagueId;
}

String _$leagueDetailHash() => r'ffe22eb0e4f7e093e2d655b84303423dbc4b1589';

/// See also [leagueDetail].
@ProviderFor(leagueDetail)
const leagueDetailProvider = LeagueDetailFamily();

/// See also [leagueDetail].
class LeagueDetailFamily extends Family<AsyncValue<League>> {
  /// See also [leagueDetail].
  const LeagueDetailFamily();

  /// See also [leagueDetail].
  LeagueDetailProvider call(String id) {
    return LeagueDetailProvider(id);
  }

  @override
  LeagueDetailProvider getProviderOverride(
    covariant LeagueDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leagueDetailProvider';
}

/// See also [leagueDetail].
class LeagueDetailProvider extends AutoDisposeFutureProvider<League> {
  /// See also [leagueDetail].
  LeagueDetailProvider(String id)
    : this._internal(
        (ref) => leagueDetail(ref as LeagueDetailRef, id),
        from: leagueDetailProvider,
        name: r'leagueDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leagueDetailHash,
        dependencies: LeagueDetailFamily._dependencies,
        allTransitiveDependencies:
            LeagueDetailFamily._allTransitiveDependencies,
        id: id,
      );

  LeagueDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<League> Function(LeagueDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeagueDetailProvider._internal(
        (ref) => create(ref as LeagueDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<League> createElement() {
    return _LeagueDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeagueDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeagueDetailRef on AutoDisposeFutureProviderRef<League> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LeagueDetailProviderElement
    extends AutoDisposeFutureProviderElement<League>
    with LeagueDetailRef {
  _LeagueDetailProviderElement(super.provider);

  @override
  String get id => (origin as LeagueDetailProvider).id;
}

String _$leagueCatchesForReviewHash() =>
    r'9ed6cadffc0af39c37f5df8e5980f44abde1b29c';

/// See also [leagueCatchesForReview].
@ProviderFor(leagueCatchesForReview)
const leagueCatchesForReviewProvider = LeagueCatchesForReviewFamily();

/// See also [leagueCatchesForReview].
class LeagueCatchesForReviewFamily extends Family<AsyncValue<List<Post>>> {
  /// See also [leagueCatchesForReview].
  const LeagueCatchesForReviewFamily();

  /// See also [leagueCatchesForReview].
  LeagueCatchesForReviewProvider call(String leagueId) {
    return LeagueCatchesForReviewProvider(leagueId);
  }

  @override
  LeagueCatchesForReviewProvider getProviderOverride(
    covariant LeagueCatchesForReviewProvider provider,
  ) {
    return call(provider.leagueId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leagueCatchesForReviewProvider';
}

/// See also [leagueCatchesForReview].
class LeagueCatchesForReviewProvider
    extends AutoDisposeFutureProvider<List<Post>> {
  /// See also [leagueCatchesForReview].
  LeagueCatchesForReviewProvider(String leagueId)
    : this._internal(
        (ref) =>
            leagueCatchesForReview(ref as LeagueCatchesForReviewRef, leagueId),
        from: leagueCatchesForReviewProvider,
        name: r'leagueCatchesForReviewProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leagueCatchesForReviewHash,
        dependencies: LeagueCatchesForReviewFamily._dependencies,
        allTransitiveDependencies:
            LeagueCatchesForReviewFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  LeagueCatchesForReviewProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leagueId,
  }) : super.internal();

  final String leagueId;

  @override
  Override overrideWith(
    FutureOr<List<Post>> Function(LeagueCatchesForReviewRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeagueCatchesForReviewProvider._internal(
        (ref) => create(ref as LeagueCatchesForReviewRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leagueId: leagueId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Post>> createElement() {
    return _LeagueCatchesForReviewProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeagueCatchesForReviewProvider &&
        other.leagueId == leagueId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leagueId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeagueCatchesForReviewRef on AutoDisposeFutureProviderRef<List<Post>> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _LeagueCatchesForReviewProviderElement
    extends AutoDisposeFutureProviderElement<List<Post>>
    with LeagueCatchesForReviewRef {
  _LeagueCatchesForReviewProviderElement(super.provider);

  @override
  String get leagueId => (origin as LeagueCatchesForReviewProvider).leagueId;
}

String _$leaguesHash() => r'58edb952f42ca906730e5751fefdcb24b9ee66e1';

/// See also [Leagues].
@ProviderFor(Leagues)
final leaguesProvider =
    AutoDisposeAsyncNotifierProvider<Leagues, List<League>>.internal(
      Leagues.new,
      name: r'leaguesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$leaguesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Leagues = AutoDisposeAsyncNotifier<List<League>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
