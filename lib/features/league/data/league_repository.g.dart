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
String _$leaguesHash() => r'79e8b292e2d37b69418e5b961ee6a654cb8087d6';

/// See also [leagues].
@ProviderFor(leagues)
final leaguesProvider = AutoDisposeFutureProvider<List<League>>.internal(
  leagues,
  name: r'leaguesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$leaguesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeaguesRef = AutoDisposeFutureProviderRef<List<League>>;
String _$myJoinedLeaguesHash() => r'4b0f3c3280f1930217c70045880350cd4e2731ab';

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

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
