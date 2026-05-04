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
String _$topRankingsHash() => r'cf6d1a5d55906b7efa60635dad9ad7213d0b9abc';

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
    r'b10e8ab6a2df2f7219c0feca70149910967ed798';

/// See also [leagueScoreRanking].
@ProviderFor(leagueScoreRanking)
final leagueScoreRankingProvider =
    AutoDisposeFutureProvider<List<ScoreRankingEntry>>.internal(
      leagueScoreRanking,
      name: r'leagueScoreRankingProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$leagueScoreRankingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeagueScoreRankingRef =
    AutoDisposeFutureProviderRef<List<ScoreRankingEntry>>;
String _$personalScoreRankingHash() =>
    r'e063d7d0a2bc40de334fe7154c51f27f79a1efdd';

/// See also [personalScoreRanking].
@ProviderFor(personalScoreRanking)
final personalScoreRankingProvider =
    AutoDisposeFutureProvider<List<ScoreRankingEntry>>.internal(
      personalScoreRanking,
      name: r'personalScoreRankingProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$personalScoreRankingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PersonalScoreRankingRef =
    AutoDisposeFutureProviderRef<List<ScoreRankingEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
