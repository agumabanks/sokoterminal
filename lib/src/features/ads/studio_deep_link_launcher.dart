import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/telemetry.dart';
import 'studio_editor_launcher.dart';

/// Deep-link target that opens the Studio web editor for a specific entity
/// and then pops itself so the user returns to the previous screen after
/// closing the web view.
class StudioDeepLinkLauncher extends ConsumerStatefulWidget {
  const StudioDeepLinkLauncher({
    super.key,
    this.productId,
    this.serviceId,
    this.quotationId,
    this.receiptId,
    this.brandKit = false,
    this.openPanel,
  });

  final int? productId;
  final int? serviceId;
  final String? quotationId;
  final int? receiptId;
  final bool brandKit;
  final String? openPanel;

  @override
  ConsumerState<StudioDeepLinkLauncher> createState() =>
      _StudioDeepLinkLauncherState();
}

class _StudioDeepLinkLauncherState
    extends ConsumerState<StudioDeepLinkLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  Future<void> _launch() async {
    if (!mounted) return;
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.event('studio_deep_link_open', props: {
        if (widget.productId != null) 'product_id': widget.productId!,
        if (widget.serviceId != null) 'service_id': widget.serviceId!,
        if (widget.quotationId != null) 'quotation_id': widget.quotationId!,
        if (widget.receiptId != null) 'receipt_id': widget.receiptId!,
        'brand_kit': widget.brandKit,
        'open_panel': widget.openPanel ?? 'templates',
      }));
    }
    await launchFullStudioWeb(
      context,
      ref,
      productId: widget.productId,
      serviceId: widget.serviceId,
      quotationId: widget.quotationId,
      receiptId: widget.receiptId,
      brandKit: widget.brandKit,
      openPanel: widget.openPanel ?? 'templates',
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening Studio…'),
          ],
        ),
      ),
    );
  }
}
