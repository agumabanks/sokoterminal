import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class SellerWalletPaymentScreen extends ConsumerStatefulWidget {
  const SellerWalletPaymentScreen({
    super.key,
    required this.topupId,
    required this.initialUrl,
    required this.amountLabel,
  });

  final int topupId;
  final String initialUrl;
  final String amountLabel;

  @override
  ConsumerState<SellerWalletPaymentScreen> createState() =>
      _SellerWalletPaymentScreenState();
}

class _SellerWalletPaymentScreenState
    extends ConsumerState<SellerWalletPaymentScreen> {
  late final WebViewController _webViewController;
  Timer? _pollTimer;
  bool _loading = true;
  bool _completing = false;
  String? _statusMessage;
  int _pollCount = 0;
  static const int _maxPolls = 120; // ~6 minutes at 3-second intervals

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _loading = false);
            await _pollStatus();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
  }

  void _stopPollingWithTimeout() {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _completing = false;
      _statusMessage =
          'Payment status check timed out. Please verify your balance later.';
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (_completing || !mounted) return;

    _pollCount++;
    if (_pollCount > _maxPolls) {
      _stopPollingWithTimeout();
      return;
    }

    try {
      final response = await ref
          .read(sellerApiProvider)
          .fetchSellerWalletTopupStatus(widget.topupId);
      final body = response.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final topup = data['topup'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['topup'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final status = topup['status']?.toString().toLowerCase() ?? '';
      final message = topup['status_message']?.toString();

      if (!mounted) return;
      setState(() => _statusMessage = message);

      if (status == 'completed') {
        _pollTimer?.cancel();
        setState(() {
          _completing = true;
          _statusMessage = 'Sanaa Wallet top-up completed.';
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      if (status == 'failed' || status == 'cancelled') {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _completing = false;
          _statusMessage = message ?? 'Payment was not completed.';
        });
      }
    } catch (e) {
      debugPrint('Wallet payment polling error: $e');
      // Keep polling quietly while the checkout page remains open.
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = (_statusMessage ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Sanaa Wallet Top-up'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            color: DesignTokens.surfaceWhite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay ${widget.amountLabel} via Pesapal',
                  style: DesignTokens.textBody.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The app will keep checking the payment status and update your Sanaa Wallet automatically.',
                  style: DesignTokens.textSmall,
                ),
                if (showBanner) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage!,
                    style: DesignTokens.textSmall.copyWith(
                      color: _completing
                          ? DesignTokens.success
                          : DesignTokens.grayDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_loading)
                  const ColoredBox(
                    color: Colors.white70,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
