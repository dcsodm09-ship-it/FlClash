enum NavigationDecision { allow, block, external }

final class NavigationRequest {
  const NavigationRequest({
    required this.uri,
    required this.isMainFrame,
    required this.isFirstNavigation,
  });

  final Uri uri;
  final bool isMainFrame;
  final bool isFirstNavigation;
}

abstract interface class NavigationPolicy {
  NavigationDecision evaluate(NavigationRequest request);
}

final class BridgePayload {
  const BridgePayload({required this.token, required this.data});

  final String token;
  final Map<String, Object?> data;
}

final class HgWebviewSpec {
  const HgWebviewSpec({
    required this.initialUri,
    required this.dataStoreId,
    required this.navigationPolicy,
    this.bridgePayload,
  });

  final Uri initialUri;
  final String dataStoreId;
  final NavigationPolicy navigationPolicy;
  final BridgePayload? bridgePayload;
}

abstract interface class HgWebview {
  Future<void> open(HgWebviewSpec spec);

  Future<void> postMessage(BridgePayload payload);
}
