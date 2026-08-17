// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../hgfast/repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hgfastRepository)
final hgfastRepositoryProvider = HgfastRepositoryProvider._();

final class HgfastRepositoryProvider
    extends
        $FunctionalProvider<
          HgfastRepository,
          HgfastRepository,
          HgfastRepository
        >
    with $Provider<HgfastRepository> {
  HgfastRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hgfastRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hgfastRepositoryHash();

  @$internal
  @override
  $ProviderElement<HgfastRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HgfastRepository create(Ref ref) {
    return hgfastRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HgfastRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HgfastRepository>(value),
    );
  }
}

String _$hgfastRepositoryHash() => r'bd847075970fa0102e475f4262dfaae6fd5208a7';
