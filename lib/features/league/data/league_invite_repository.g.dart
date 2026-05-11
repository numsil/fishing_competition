// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_invite_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$leagueInviteRepositoryHash() =>
    r'a234634f04e53ca4ccdd8a9c07f803a9ce8e81c5';

/// See also [leagueInviteRepository].
@ProviderFor(leagueInviteRepository)
final leagueInviteRepositoryProvider =
    AutoDisposeProvider<LeagueInviteRepository>.internal(
      leagueInviteRepository,
      name: r'leagueInviteRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$leagueInviteRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeagueInviteRepositoryRef =
    AutoDisposeProviderRef<LeagueInviteRepository>;
String _$sentLeagueInvitesHash() => r'be51cd110d279964280d8f3f1a92c1fdc8e2769f';

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

/// See also [sentLeagueInvites].
@ProviderFor(sentLeagueInvites)
const sentLeagueInvitesProvider = SentLeagueInvitesFamily();

/// See also [sentLeagueInvites].
class SentLeagueInvitesFamily extends Family<AsyncValue<List<LeagueInvite>>> {
  /// See also [sentLeagueInvites].
  const SentLeagueInvitesFamily();

  /// See also [sentLeagueInvites].
  SentLeagueInvitesProvider call(String leagueId) {
    return SentLeagueInvitesProvider(leagueId);
  }

  @override
  SentLeagueInvitesProvider getProviderOverride(
    covariant SentLeagueInvitesProvider provider,
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
  String? get name => r'sentLeagueInvitesProvider';
}

/// See also [sentLeagueInvites].
class SentLeagueInvitesProvider
    extends AutoDisposeFutureProvider<List<LeagueInvite>> {
  /// See also [sentLeagueInvites].
  SentLeagueInvitesProvider(String leagueId)
    : this._internal(
        (ref) => sentLeagueInvites(ref as SentLeagueInvitesRef, leagueId),
        from: sentLeagueInvitesProvider,
        name: r'sentLeagueInvitesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sentLeagueInvitesHash,
        dependencies: SentLeagueInvitesFamily._dependencies,
        allTransitiveDependencies:
            SentLeagueInvitesFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  SentLeagueInvitesProvider._internal(
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
    FutureOr<List<LeagueInvite>> Function(SentLeagueInvitesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SentLeagueInvitesProvider._internal(
        (ref) => create(ref as SentLeagueInvitesRef),
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
  AutoDisposeFutureProviderElement<List<LeagueInvite>> createElement() {
    return _SentLeagueInvitesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SentLeagueInvitesProvider && other.leagueId == leagueId;
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
mixin SentLeagueInvitesRef on AutoDisposeFutureProviderRef<List<LeagueInvite>> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _SentLeagueInvitesProviderElement
    extends AutoDisposeFutureProviderElement<List<LeagueInvite>>
    with SentLeagueInvitesRef {
  _SentLeagueInvitesProviderElement(super.provider);

  @override
  String get leagueId => (origin as SentLeagueInvitesProvider).leagueId;
}

String _$receivedLeagueInvitesHash() =>
    r'07502a8fb35f93431477cc2a6cbd847f318cad18';

/// See also [receivedLeagueInvites].
@ProviderFor(receivedLeagueInvites)
final receivedLeagueInvitesProvider =
    AutoDisposeFutureProvider<List<LeagueInvite>>.internal(
      receivedLeagueInvites,
      name: r'receivedLeagueInvitesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$receivedLeagueInvitesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReceivedLeagueInvitesRef =
    AutoDisposeFutureProviderRef<List<LeagueInvite>>;
String _$myPendingInviteForLeagueHash() =>
    r'ebb7f1c80aa79739b9490b56230b876daba23c81';

/// See also [myPendingInviteForLeague].
@ProviderFor(myPendingInviteForLeague)
const myPendingInviteForLeagueProvider = MyPendingInviteForLeagueFamily();

/// See also [myPendingInviteForLeague].
class MyPendingInviteForLeagueFamily extends Family<AsyncValue<LeagueInvite?>> {
  /// See also [myPendingInviteForLeague].
  const MyPendingInviteForLeagueFamily();

  /// See also [myPendingInviteForLeague].
  MyPendingInviteForLeagueProvider call(String leagueId) {
    return MyPendingInviteForLeagueProvider(leagueId);
  }

  @override
  MyPendingInviteForLeagueProvider getProviderOverride(
    covariant MyPendingInviteForLeagueProvider provider,
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
  String? get name => r'myPendingInviteForLeagueProvider';
}

/// See also [myPendingInviteForLeague].
class MyPendingInviteForLeagueProvider
    extends AutoDisposeFutureProvider<LeagueInvite?> {
  /// See also [myPendingInviteForLeague].
  MyPendingInviteForLeagueProvider(String leagueId)
    : this._internal(
        (ref) => myPendingInviteForLeague(
          ref as MyPendingInviteForLeagueRef,
          leagueId,
        ),
        from: myPendingInviteForLeagueProvider,
        name: r'myPendingInviteForLeagueProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$myPendingInviteForLeagueHash,
        dependencies: MyPendingInviteForLeagueFamily._dependencies,
        allTransitiveDependencies:
            MyPendingInviteForLeagueFamily._allTransitiveDependencies,
        leagueId: leagueId,
      );

  MyPendingInviteForLeagueProvider._internal(
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
    FutureOr<LeagueInvite?> Function(MyPendingInviteForLeagueRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MyPendingInviteForLeagueProvider._internal(
        (ref) => create(ref as MyPendingInviteForLeagueRef),
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
  AutoDisposeFutureProviderElement<LeagueInvite?> createElement() {
    return _MyPendingInviteForLeagueProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MyPendingInviteForLeagueProvider &&
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
mixin MyPendingInviteForLeagueRef
    on AutoDisposeFutureProviderRef<LeagueInvite?> {
  /// The parameter `leagueId` of this provider.
  String get leagueId;
}

class _MyPendingInviteForLeagueProviderElement
    extends AutoDisposeFutureProviderElement<LeagueInvite?>
    with MyPendingInviteForLeagueRef {
  _MyPendingInviteForLeagueProviderElement(super.provider);

  @override
  String get leagueId => (origin as MyPendingInviteForLeagueProvider).leagueId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
