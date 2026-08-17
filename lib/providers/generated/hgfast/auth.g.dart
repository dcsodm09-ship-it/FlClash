// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../hgfast/auth.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HgfastAuth)
final hgfastAuthProvider = HgfastAuthProvider._();

final class HgfastAuthProvider
    extends $NotifierProvider<HgfastAuth, HgfastAuthState> {
  HgfastAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hgfastAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hgfastAuthHash();

  @$internal
  @override
  HgfastAuth create() => HgfastAuth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HgfastAuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HgfastAuthState>(value),
    );
  }
}

String _$hgfastAuthHash() => r'b60ecc8d57dad43e9182ff78bfae3382d4d8093e';

abstract class _$HgfastAuth extends $Notifier<HgfastAuthState> {
  HgfastAuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HgfastAuthState, HgfastAuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HgfastAuthState, HgfastAuthState>,
              HgfastAuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
