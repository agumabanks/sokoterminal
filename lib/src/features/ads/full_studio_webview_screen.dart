import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';

/// WebView screen that hosts the full Soko Studio web editor.
///
/// Handles loading, generic errors, offline errors, authentication/session
/// expiry, and provides reload + open-in-browser fallbacks.
class FullStudioWebViewScreen extends StatefulWidget {
  const FullStudioWebViewScreen({
    super.key,
    required this.initialUrl,
  });

  final String initialUrl;

  @override
  State<FullStudioWebViewScreen> createState() {
    return _FullStudioWebViewScreenState();
  }
}

class _FullStudioWebViewScreenState extends State<FullStudioWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  _StudioWebError? _error;

  static const _kBrandNavy = DesignTokens.brandPrimary;
  static const _kBrandSurface = DesignTokens.brandPrimary;
  static const _kBrandGreen = DesignTokens.brandAccent;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            // If the bridge/session expires we may be redirected to login.
            if (url.contains('/seller/login') ||
                url.contains('/login') &&
                    !url.contains('/photo-editor')) {
              _setAuthError();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            final type = err.errorType;
            final description = err.description.toLowerCase();
            if (description.contains('401') ||
                description.contains('403') ||
                description.contains('unauthorized') ||
                description.contains('forbidden')) {
              _setAuthError();
              return;
            }
            if (type == WebResourceErrorType.hostLookup ||
                type == WebResourceErrorType.connect ||
                description.contains('net::err_internet_disconnected') ||
                description.contains('no address associated')) {
              setState(() {
                _loading = false;
                _error = const _StudioWebError.offline();
              });
              return;
            }
            setState(() {
              _loading = false;
              _error = _StudioWebError.generic(err.description);
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _setAuthError() {
    setState(() {
      _loading = false;
      _error = const _StudioWebError.auth();
    });
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _controller.reload();
  }

  Future<void> _openInBrowser() async {
    final currentUrl = await _controller.currentUrl();
    final urlToOpen = currentUrl != null && currentUrl.isNotEmpty
        ? currentUrl
        : widget.initialUrl;
    final uri = Uri.parse(urlToOpen);
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('studio_web_fallback_browser'));
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBrandNavy,
      appBar: AppBar(
        backgroundColor: _kBrandSurface,
        foregroundColor: Colors.white,
        title: const Text('Soko Studio'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) _buildLoadingOverlay(),
          if (_error != null) _buildErrorOverlay(_error!),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.small(
              heroTag: 'studio_refresh_fab',
              backgroundColor: _kBrandSurface,
              foregroundColor: _kBrandGreen,
              tooltip: 'Refresh Studio',
              onPressed: _reload,
              child: const Icon(Icons.refresh_rounded),
            ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: _kBrandNavy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: _kBrandGreen,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opening Soko Studio…',
              style: DesignTokens.textHeadline.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparing your canvas',
              style: DesignTokens.textBody.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(_StudioWebError error) {
    return Container(
      color: _kBrandNavy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                error.icon,
                color: error.tint,
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                error.title,
                textAlign: TextAlign.center,
                style: DesignTokens.textHeadline.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                error.message,
                textAlign: TextAlign.center,
                style: DesignTokens.textBody.copyWith(color: Colors.white70),
              ),
              if (error.detail != null) ...[
                const SizedBox(height: 12),
                Text(
                  error.detail!,
                  textAlign: TextAlign.center,
                  style: DesignTokens.textSmall.copyWith(color: Colors.white54),
                ),
              ],
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBrandGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Open in browser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _StudioWebError {
  final String title;
  final String message;
  final String? detail;
  final IconData icon;
  final Color tint;

  const _StudioWebError({
    required this.title,
    required this.message,
    this.detail,
    required this.icon,
    required this.tint,
  });

  const _StudioWebError.offline()
      : this(
          title: 'You\'re offline',
          message: 'Connect to the internet to use Soko Studio.',
          icon: Icons.wifi_off_rounded,
          tint: Colors.orangeAccent,
        );

  const _StudioWebError.auth()
      : this(
          title: 'Session expired',
          message: 'Your seller session has expired. Please log in again.',
          icon: Icons.lock_outline_rounded,
          tint: Colors.redAccent,
        );

  _StudioWebError.generic(String? description)
      : this(
          title: 'Couldn\'t load Studio',
          message: 'Something went wrong while loading the editor.',
          detail: description?.isNotEmpty == true ? description : null,
          icon: Icons.error_outline_rounded,
          tint: Colors.redAccent,
        );
}
