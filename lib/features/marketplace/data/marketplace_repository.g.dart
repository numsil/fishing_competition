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
String _$marketplaceItemHash() => r'ef6a05297ffb5e0c33ea393d6ec42f85a7c0abcc';

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

/// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
/// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
///
/// Copied from [marketplaceItem].
@ProviderFor(marketplaceItem)
const marketplaceItemProvider = MarketplaceItemFamily();

/// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
/// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
///
/// Copied from [marketplaceItem].
class MarketplaceItemFamily extends Family<AsyncValue<MarketplaceItem?>> {
  /// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
  /// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
  ///
  /// Copied from [marketplaceItem].
  const MarketplaceItemFamily();

  /// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
  /// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
  ///
  /// Copied from [marketplaceItem].
  MarketplaceItemProvider call(String itemId) {
    return MarketplaceItemProvider(itemId);
  }

  @override
  MarketplaceItemProvider getProviderOverride(
    covariant MarketplaceItemProvider provider,
  ) {
    return call(provider.itemId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'marketplaceItemProvider';
}

/// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
/// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
///
/// Copied from [marketplaceItem].
class MarketplaceItemProvider
    extends AutoDisposeFutureProvider<MarketplaceItem?> {
  /// 매물 id별 단일 조회. 카드가 여러 개여도 id 단위로 캐싱되어 재사용(N+1 아님).
  /// autoDispose(기본): 채팅방을 벗어나면 해제되어 다음 진입 시 최신 상태(가격/상태/삭제) 반영.
  ///
  /// Copied from [marketplaceItem].
  MarketplaceItemProvider(String itemId)
    : this._internal(
        (ref) => marketplaceItem(ref as MarketplaceItemRef, itemId),
        from: marketplaceItemProvider,
        name: r'marketplaceItemProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$marketplaceItemHash,
        dependencies: MarketplaceItemFamily._dependencies,
        allTransitiveDependencies:
            MarketplaceItemFamily._allTransitiveDependencies,
        itemId: itemId,
      );

  MarketplaceItemProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.itemId,
  }) : super.internal();

  final String itemId;

  @override
  Override overrideWith(
    FutureOr<MarketplaceItem?> Function(MarketplaceItemRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MarketplaceItemProvider._internal(
        (ref) => create(ref as MarketplaceItemRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        itemId: itemId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<MarketplaceItem?> createElement() {
    return _MarketplaceItemProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MarketplaceItemProvider && other.itemId == itemId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, itemId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MarketplaceItemRef on AutoDisposeFutureProviderRef<MarketplaceItem?> {
  /// The parameter `itemId` of this provider.
  String get itemId;
}

class _MarketplaceItemProviderElement
    extends AutoDisposeFutureProviderElement<MarketplaceItem?>
    with MarketplaceItemRef {
  _MarketplaceItemProviderElement(super.provider);

  @override
  String get itemId => (origin as MarketplaceItemProvider).itemId;
}

String _$myMarketplaceItemsHash() =>
    r'4914003af4948357e7a1b1e9775fa68c00127e2c';

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
String _$userMarketplaceItemsHash() =>
    r'9a7eb4afd744854f9b0bc6e2231daf0b3a97f7a8';

/// See also [userMarketplaceItems].
@ProviderFor(userMarketplaceItems)
const userMarketplaceItemsProvider = UserMarketplaceItemsFamily();

/// See also [userMarketplaceItems].
class UserMarketplaceItemsFamily
    extends Family<AsyncValue<List<MarketplaceItem>>> {
  /// See also [userMarketplaceItems].
  const UserMarketplaceItemsFamily();

  /// See also [userMarketplaceItems].
  UserMarketplaceItemsProvider call(String userId) {
    return UserMarketplaceItemsProvider(userId);
  }

  @override
  UserMarketplaceItemsProvider getProviderOverride(
    covariant UserMarketplaceItemsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userMarketplaceItemsProvider';
}

/// See also [userMarketplaceItems].
class UserMarketplaceItemsProvider
    extends AutoDisposeFutureProvider<List<MarketplaceItem>> {
  /// See also [userMarketplaceItems].
  UserMarketplaceItemsProvider(String userId)
    : this._internal(
        (ref) => userMarketplaceItems(ref as UserMarketplaceItemsRef, userId),
        from: userMarketplaceItemsProvider,
        name: r'userMarketplaceItemsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userMarketplaceItemsHash,
        dependencies: UserMarketplaceItemsFamily._dependencies,
        allTransitiveDependencies:
            UserMarketplaceItemsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserMarketplaceItemsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<MarketplaceItem>> Function(UserMarketplaceItemsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserMarketplaceItemsProvider._internal(
        (ref) => create(ref as UserMarketplaceItemsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<MarketplaceItem>> createElement() {
    return _UserMarketplaceItemsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserMarketplaceItemsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserMarketplaceItemsRef
    on AutoDisposeFutureProviderRef<List<MarketplaceItem>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserMarketplaceItemsProviderElement
    extends AutoDisposeFutureProviderElement<List<MarketplaceItem>>
    with UserMarketplaceItemsRef {
  _UserMarketplaceItemsProviderElement(super.provider);

  @override
  String get userId => (origin as UserMarketplaceItemsProvider).userId;
}

String _$marketplaceListHash() => r'03b01693912d227a1468693e6a0ee56381a10c75';

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
