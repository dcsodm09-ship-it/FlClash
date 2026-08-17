part of '../action.dart';

const String _hgfastManagedProfileIdKey = 'hgfast_managed_profile_id';

@Riverpod(keepAlive: true)
class HgfastSyncAction extends _$HgfastSyncAction {
  Timer? _pollTimer;
  Duration _backoff = _hgfastMinBackoff;
  Future<void>? _syncInFlight;

  static const Duration _hgfastMinBackoff = Duration(seconds: 30);
  static const Duration _hgfastMaxBackoff = Duration(minutes: 15);
  static const Duration _hgfastCanaryBackoff = Duration(minutes: 5);

  @override
  void build() {
    ref.listen<HgfastAuthState>(hgfastAuthProvider, (previous, next) {
      if (!next.isAuthenticated) {
        stopPolling();
      }
    });
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
  }

  Future<void> syncAfterLogin() async {
    await _ensureCoreInitialized();
    await _syncOnce();
  }

  Future<void> retryNow() async {
    if (!ref.read(hgfastAuthProvider).isAuthenticated) {
      return;
    }
    await _ensureCoreInitialized();
    await _syncOnce();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _backoff = _hgfastMinBackoff;
  }

  Future<void> _ensureCoreInitialized() async {
    if (ref.read(initProvider)) {
      return;
    }
    final completer = Completer<void>();
    late final ProviderSubscription<bool> subscription;
    subscription = ref.listen<bool>(initProvider, (previous, next) {
      if (next && !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      await completer.future;
    } finally {
      subscription.close();
    }
  }

  void _pollTick() {
    if (!ref.read(hgfastAuthProvider).isAuthenticated) {
      return;
    }
    unawaited(_syncOnce());
  }

  void _scheduleNext({required bool succeeded}) {
    _pollTimer?.cancel();
    _backoff = succeeded ? _hgfastMinBackoff : _nextBackoff(_backoff);
    _pollTimer = Timer(_backoff, _pollTick);
  }

  Duration _nextBackoff(Duration current) {
    final doubled = current * 2;
    return doubled > _hgfastMaxBackoff ? _hgfastMaxBackoff : doubled;
  }

  Future<void> _syncOnce() {
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _runSyncOnce();
    _syncInFlight = future;
    return future.whenComplete(() {
      _syncInFlight = null;
    });
  }

  Future<void> _runSyncOnce() async {
    ref.read(hgfastNodesProvider.notifier).markLoading();
    final result = await ref.read(hgfastRepositoryProvider).nodes();
    final catalog = result.successValue;
    if (catalog != null) {
      ref.read(hgfastNodesProvider.notifier).markLoaded(catalog);
      await _applyCatalog(catalog);
      _scheduleNext(succeeded: true);
      return;
    }
    final error = result.failureError;
    if (error == null) {
      _scheduleNext(succeeded: false);
      return;
    }
    if (error is HgfastBanned ||
        error is HgfastExpired ||
        error is HgfastQuotaExhausted ||
        error is HgfastNoGroup) {
      ref.read(hgfastNodesProvider.notifier).markAccountBlocked(error);
      _pollTimer?.cancel();
      _backoff = _hgfastMinBackoff;
      return;
    }
    if (error is HgfastCanaryDenied) {
      ref.read(hgfastNodesProvider.notifier).markNotInCanary(error);
      _pollTimer?.cancel();
      _backoff = _hgfastMinBackoff;
      _pollTimer = Timer(_hgfastCanaryBackoff, _pollTick);
      return;
    }
    if (error is HgfastAuthFailed) {
      ref.read(hgfastNodesProvider.notifier).markError(error);
      await ref.read(hgfastAuthActionProvider.notifier).logout();
      return;
    }
    ref.read(hgfastNodesProvider.notifier).markError(error);
    _scheduleNext(succeeded: false);
  }

  Future<void> _applyCatalog(NodeCatalog catalog) async {
    if (catalog.nodes.isEmpty) {
      return;
    }
    final mixedPort = ref.read(patchClashConfigProvider).mixedPort;
    final Map<String, Object?> rawConfig;
    try {
      rawConfig = const HgfastConfigGenerator().generate(
        catalog: catalog,
        mixedPort: mixedPort,
      );
    } on HgfastEmptyNodeCatalogException {
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(yaml.encode(rawConfig)));

    final persistedId = await _readManagedProfileId();
    final existing = persistedId == null
        ? null
        : ref.read(profilesProvider).getProfile(persistedId);

    final Profile updated;
    try {
      if (existing != null) {
        updated = await existing
            .copyWith(lastUpdateDate: DateTime.now())
            .saveFile(bytes);
      } else if (persistedId != null) {
        final recovered = Profile(
          id: persistedId,
          label: 'HGFAST',
          autoUpdateDuration: defaultUpdateDuration,
          isManaged: true,
        );
        updated = await recovered.saveFile(bytes);
      } else {
        final fresh = Profile.normal(label: 'HGFAST', isManaged: true);
        updated = await fresh.saveFile(bytes);
        await _writeManagedProfileId(updated.id);
      }
    } catch (error) {
      commonPrint.log(
        'hgfast sync failed to write managed profile (${error.runtimeType})',
        logLevel: LogLevel.warning,
      );
      return;
    }

    ref.read(profilesProvider.notifier).put(updated);
    if (persistedId == null) {
      ref.read(currentProfileIdProvider.notifier).value = updated.id;
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    } else if (updated.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<int?> _readManagedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hgfastManagedProfileIdKey);
  }

  Future<void> _writeManagedProfileId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hgfastManagedProfileIdKey, id);
  }
}
