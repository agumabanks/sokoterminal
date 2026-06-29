import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/features/ads/full_studio_webview_screen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  group('FullStudioWebViewScreen', () {
    const testUrl = 'https://soko24.co/photo-editor/?skip_home=1';

    testWidgets('renders branded loading overlay while starting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FullStudioWebViewScreen(initialUrl: testUrl),
        ),
      );
      await tester.pump();

      expect(find.text('Soko Studio'), findsOneWidget);
      expect(find.text('Opening Soko Studio…'), findsOneWidget);
      expect(find.text('Preparing your canvas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('reload and browser fallback buttons are available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FullStudioWebViewScreen(initialUrl: testUrl),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Reload'), findsOneWidget);
      expect(find.byTooltip('Open in browser'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });
  });
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return _FakePlatformWebViewCookieManager(params);
  }
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  String? _currentUrl;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    _currentUrl = params.uri.toString();
  }

  @override
  Future<void> reload() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<String?> currentUrl() async => _currentUrl;
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _FakePlatformWebViewCookieManager extends PlatformWebViewCookieManager {
  _FakePlatformWebViewCookieManager(super.params) : super.implementation();

  @override
  Future<bool> clearCookies() async => true;

  @override
  Future<void> setCookie(WebViewCookie cookie) async {}
}
