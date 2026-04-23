// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileRepositoryHash() => r'98c7edfeece85e2be195aa0962369cb9145a7e4e';

/// See also [profileRepository].
@ProviderFor(profileRepository)
final profileRepositoryProvider =
    AutoDisposeProvider<ProfileRepository>.internal(
      profileRepository,
      name: r'profileRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileRepositoryRef = AutoDisposeProviderRef<ProfileRepository>;
String _$myProfileHash() => r'e7f41fddac6f1b89cc5375da7a99d70806ae5239';

/// See also [myProfile].
@ProviderFor(myProfile)
final myProfileProvider = AutoDisposeFutureProvider<UserProfile>.internal(
  myProfile,
  name: r'myProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyProfileRef = AutoDisposeFutureProviderRef<UserProfile>;
String _$myPostsHash() => r'ab6b28fd009f90739ac98b3d9cc12970386011b6';

/// See also [myPosts].
@ProviderFor(myPosts)
final myPostsProvider = AutoDisposeFutureProvider<List<Post>>.internal(
  myPosts,
  name: r'myPostsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myPostsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyPostsRef = AutoDisposeFutureProviderRef<List<Post>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
