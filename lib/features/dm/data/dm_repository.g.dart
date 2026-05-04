// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dmRepositoryHash() => r'51922881e5382307152d3647b6029d67eb546aea';

/// See also [dmRepository].
@ProviderFor(dmRepository)
final dmRepositoryProvider = AutoDisposeProvider<DmRepository>.internal(
  dmRepository,
  name: r'dmRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dmRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DmRepositoryRef = AutoDisposeProviderRef<DmRepository>;
String _$dmConversationsHash() => r'3fd2c3e679c93770f3b2448bae4584008d047e83';

/// See also [dmConversations].
@ProviderFor(dmConversations)
final dmConversationsProvider =
    AutoDisposeFutureProvider<List<DmConversation>>.internal(
      dmConversations,
      name: r'dmConversationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dmConversationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DmConversationsRef = AutoDisposeFutureProviderRef<List<DmConversation>>;
String _$dmMessagesHash() => r'4ad025dda7e98e0d6dc3b92a2b44c9967611a6d4';

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

/// See also [dmMessages].
@ProviderFor(dmMessages)
const dmMessagesProvider = DmMessagesFamily();

/// See also [dmMessages].
class DmMessagesFamily extends Family<AsyncValue<List<DmMessage>>> {
  /// See also [dmMessages].
  const DmMessagesFamily();

  /// See also [dmMessages].
  DmMessagesProvider call(String conversationId) {
    return DmMessagesProvider(conversationId);
  }

  @override
  DmMessagesProvider getProviderOverride(
    covariant DmMessagesProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dmMessagesProvider';
}

/// See also [dmMessages].
class DmMessagesProvider extends AutoDisposeStreamProvider<List<DmMessage>> {
  /// See also [dmMessages].
  DmMessagesProvider(String conversationId)
    : this._internal(
        (ref) => dmMessages(ref as DmMessagesRef, conversationId),
        from: dmMessagesProvider,
        name: r'dmMessagesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dmMessagesHash,
        dependencies: DmMessagesFamily._dependencies,
        allTransitiveDependencies: DmMessagesFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  DmMessagesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    Stream<List<DmMessage>> Function(DmMessagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DmMessagesProvider._internal(
        (ref) => create(ref as DmMessagesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<DmMessage>> createElement() {
    return _DmMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DmMessagesProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DmMessagesRef on AutoDisposeStreamProviderRef<List<DmMessage>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _DmMessagesProviderElement
    extends AutoDisposeStreamProviderElement<List<DmMessage>>
    with DmMessagesRef {
  _DmMessagesProviderElement(super.provider);

  @override
  String get conversationId => (origin as DmMessagesProvider).conversationId;
}

String _$hasUnreadDmsHash() => r'c40296e14b27bdf485fbc0e214693ac6653d26c6';

/// See also [hasUnreadDms].
@ProviderFor(hasUnreadDms)
final hasUnreadDmsProvider = AutoDisposeStreamProvider<bool>.internal(
  hasUnreadDms,
  name: r'hasUnreadDmsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasUnreadDmsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasUnreadDmsRef = AutoDisposeStreamProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
