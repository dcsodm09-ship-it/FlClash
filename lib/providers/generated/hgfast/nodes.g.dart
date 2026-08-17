// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../hgfast/nodes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HgfastNodes)
final hgfastNodesProvider = HgfastNodesProvider._();

final class HgfastNodesProvider
    extends $NotifierProvider<HgfastNodes, HgfastNodesState> {
  HgfastNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hgfastNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hgfastNodesHash();

  @$internal
  @override
  HgfastNodes create() => HgfastNodes();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HgfastNodesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HgfastNodesState>(value),
    );
  }
}

String _$hgfastNodesHash() => r'81c4cba0bdcabf5f0ba176921194ada86795c62b';

abstract class _$HgfastNodes extends $Notifier<HgfastNodesState> {
  HgfastNodesState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HgfastNodesState, HgfastNodesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HgfastNodesState, HgfastNodesState>,
              HgfastNodesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
