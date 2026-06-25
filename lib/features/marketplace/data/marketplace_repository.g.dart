// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$marketplaceRepositoryHash() =>
    r'a93041f0fbf0b7aab300b2b99b1c7fb1e5319424';

/// See also [marketplaceRepository].
@ProviderFor(marketplaceRepository)
final marketplaceRepositoryProvider =
    AutoDisposeProvider<MarketplaceRepository>.internal(
      marketplaceRepository,
      name: r'marketplaceRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$marketplaceRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketplaceRepositoryRef =
    AutoDisposeProviderRef<MarketplaceRepository>;
String _$myMarketplaceItemsHash() =>
    r'554dd1b8412215101963fe606011f7ab3476d07a';

/// See also [myMarketplaceItems].
@ProviderFor(myMarketplaceItems)
final myMarketplaceItemsProvider =
    AutoDisposeFutureProvider<List<MarketplaceItem>>.internal(
      myMarketplaceItems,
      name: r'myMarketplaceItemsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myMarketplaceItemsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyMarketplaceItemsRef =
    AutoDisposeFutureProviderRef<List<MarketplaceItem>>;
String _$marketplaceListHash() => r'9f2839e3cd6186025872530cc870e136ccf61271';

/// See also [MarketplaceList].
@ProviderFor(MarketplaceList)
final marketplaceListProvider =
    AutoDisposeAsyncNotifierProvider<
      MarketplaceList,
      List<MarketplaceItem>
    >.internal(
      MarketplaceList.new,
      name: r'marketplaceListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$marketplaceListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MarketplaceList = AutoDisposeAsyncNotifier<List<MarketplaceItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
