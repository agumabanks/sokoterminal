import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../items/product_preview_screen.dart';
import '../services/service_detail_screen.dart';

/// Handles incoming `/p/{id}` and `/s/{id}` deep-links by locating the local
/// product/service that matches the remote id, then opening the right detail
/// screen. If nothing is synced locally, it offers to open the web page.
class ItemDeepLinkScreen extends ConsumerStatefulWidget {
  const ItemDeepLinkScreen({
    super.key,
    required this.remoteId,
    required this.isService,
  });

  final int remoteId;
  final bool isService;

  @override
  ConsumerState<ItemDeepLinkScreen> createState() => _ItemDeepLinkScreenState();
}

class _ItemDeepLinkScreenState extends ConsumerState<ItemDeepLinkScreen> {
  bool _busy = true;
  String? _localId;
  String? _name;
  double? _price;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final db = ref.read(appDatabaseProvider);
    try {
      if (widget.isService) {
        final service = await db.getServiceByRemoteId(widget.remoteId);
        if (service != null && mounted) {
          _localId = service.id;
          _name = service.title;
          _price = service.price;
        }
      } else {
        final item = await db.getItemByRemoteId(widget.remoteId);
        if (item != null && mounted) {
          _localId = item.id;
          _name = item.name;
          _price = item.price;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _busy = false);
      if (_localId != null) {
        _openDetail();
      }
    }
  }

  void _openDetail() {
    if (!mounted) return;
    final id = _localId;
    if (id == null) return;
    Widget page;
    if (widget.isService) {
      page = ServiceDetailScreen(serviceId: id);
    } else {
      page = ProductPreviewScreen(itemId: id);
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openWeb() async {
    final path = widget.isService ? '/s/${widget.remoteId}' : '/p/${widget.remoteId}';
    final uri = Uri.parse('https://soko24.co$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.canvasParchment,
      appBar: AppBar(title: const Text('Opening…')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            widget.isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
            size: 64,
            color: DesignTokens.brandAccent,
          ),
          const SizedBox(height: 24),
          Text(
            _name ?? (widget.isService ? 'Service' : 'Product'),
            textAlign: TextAlign.center,
            style: DesignTokens.textTitle,
          ),
          if (_price != null) ...[
            const SizedBox(height: 8),
            Text(
              _price!.toUgx(),
              textAlign: TextAlign.center,
              style: DesignTokens.textBody.copyWith(color: DesignTokens.inkMuted),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'This ${widget.isService ? 'service' : 'product'} is not synced to this device yet. Open it on the web store instead.',
            textAlign: TextAlign.center,
            style: DesignTokens.textBody,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _openWeb,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: DesignTokens.canvas,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open in browser'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
