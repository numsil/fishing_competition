// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rankingRepositoryHash() => r'60e317da7f5ba819389b7588c274d2f5cb123511';

/// See also [rankingRepository].
@ProviderFor(rankingRepository)
final rankingRepositoryProvider =
    AutoDisposeProvider<RankingRepository>.internal(
      rankingRepository,
      name: r'rankingRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$rankingRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RankingRepositoryRef = AutoDisposeProviderRef<RankingRepository>;
String _$topRankingsHash() => r'c613167064fbc244004cb08cc5da9fb37cde0605';

/// See also [topRankings].
@ProviderFor(topRankings)
final topRankingsProvider =
    AutoDisposeFutureProvider<List<RankingEntry>>.internal(
      topRankings,
      name: r'topRankingsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$topRankingsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TopRankingsRef = AutoDisposeFutureProviderRef<List<RankingEntry>>;
String _$leagueScoreRankingHash() =>
    r'793f48129f754e0c8ccbc6934141be318f73a450';

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

/// See also [leagueScoreRanking].
@ProviderFor(leagueScoreRanking)
const leagueScoreRankingProvider = LeagueScoreRankingFamily();

/// See also [leagueScoreRanking].
class LeagueScoreRankingFamily
    extends Family<AsyncValue<List<ScoreRankingEntry>>> {
  /// See also [leagueScoreRanking].
  const LeagueScoreRankingFamily();

  /// See also [leagueScoreRanking].
  LeagueScoreRankingProvider call(int year) {
    return LeagueScoreRankingProvider(year);
  }

  @override
  LeagueScoreRankingProvider getProviderOverride(
    covariant LeagueScoreRankingProvider provider,
  ) {
    return call(provider.year);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'leagueScoreRankingProvider';
}

/// See also [leagueScoreRanking].
class LeagueScoreRankingProvider
    extends AutoDisposeFutureProvider<List<ScoreRankingEntry>> {
  /// See also [leagueScoreRanking].
  LeagueScoreRankingProvider(int year)
    : this._internal(
        (ref) => leagueScoreRanking(ref as LeagueScoreRankingRef, year),
        from: leagueScoreRankingProvider,
        name: r'leagueScoreRankingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$leagueScoreRankingHash,
        dependencies: LeagueScoreRankingFamily._dependencies,
        allTransitiveDependencies:
            LeagueScoreRankingFamily._allTransitiveDependencies,
        year: year,
      );

  LeagueScoreRankingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final int year;

  @override
  Override overrideWith(
    FutureOr<List<ScoreRankingEntry>> Function(LeagueScoreRankingRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeagueScoreRankingProvider._internal(
        (ref) => create(ref as LeagueScoreRankingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ScoreRankingEntry>> createElement() {
    return _LeagueScoreRankingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeagueScoreRankingProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeagueScoreRankingRef
    on AutoDisposeFutureProviderRef<List<ScoreRankingEntry>> {
  /// The parameter `year` of this provider.
  int get year;
}

class _LeagueScoreRankingProviderElement
    extends AutoDisposeFutureProviderElement<List<ScoreRankingEntry>>
    with LeagueScoreRankingRef {
  _LeagueScoreRankingProviderElement(super.provider);

  @override
  int get year => (origin as LeagueScoreRankingProvider).year;
}

String _$personalScoreRankingHash() =>
    r'e9021fc76f92d2e5efb6e24767e4e7080da0e4f2';

/// See also [personalScoreRanking].
@ProviderFor(personalScoreRanking)
const personalScoreRankingProvider = PersonalScoreRankingFamily();

/// See also [personalScoreRanking].
class PersonalScoreRankingFamily
    extends Family<AsyncValue<List<ScoreRankingEntry>>> {
  /// See also [personalScoreRanking].
  const PersonalScoreRankingFamily();

  /// See also [personalScoreRanking].
  PersonalScoreRankingProvider call(int year) {
    return PersonalScoreRankingProvider(year);
  }

  @override
  PersonalScoreRankingProvider getProviderOverride(
    covariant PersonalScoreRankingProvider provider,
  ) {
    return call(provider.year);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'personalScoreRankingProvider';
}

/// See also [personalScoreRanking].
class PersonalScoreRankingProvider
    extends AutoDisposeFutureProvider<List<ScoreRankingEntry>> {
  /// See also [personalScoreRanking].
  PersonalScoreRankingProvider(int year)
    : this._internal(
        (ref) => personalScoreRanking(ref as PersonalScoreRankingRef, year),
        from: personalScoreRankingProvider,
        name: r'personalScoreRankingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$personalScoreRankingHash,
        dependencies: PersonalScoreRankingFamily._dependencies,
        allTransitiveDependencies:
            PersonalScoreRankingFamily._allTransitiveDependencies,
        year: year,
      );

  PersonalScoreRankingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final int year;

  @override
  Override overrideWith(
    FutureOr<List<ScoreRankingEntry>> Function(PersonalScoreRankingRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PersonalScoreRankingProvider._internal(
        (ref) => create(ref as PersonalScoreRankingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ScoreRankingEntry>> createElement() {
    return _PersonalScoreRankingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PersonalScoreRankingProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PersonalScoreRankingRef
    on AutoDisposeFutureProviderRef<List<ScoreRankingEntry>> {
  /// The parameter `year` of this provider.
  int get year;
}

class _PersonalScoreRankingProviderElement
    extends AutoDisposeFutureProviderElement<List<ScoreRankingEntry>>
    with PersonalScoreRankingRef {
  _PersonalScoreRankingProviderElement(super.provider);

  @override
  int get year => (origin as PersonalScoreRankingProvider).year;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
