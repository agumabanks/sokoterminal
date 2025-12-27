import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class ShopSeoScreen extends ConsumerStatefulWidget {
  const ShopSeoScreen({super.key});

  @override
  ConsumerState<ShopSeoScreen> createState() => _ShopSeoScreenState();
}

class _ShopSeoScreenState extends ConsumerState<ShopSeoScreen> {
  final _metaTitleCtrl = TextEditingController();
  final _metaDescCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  String _shopName = '';
  String _shopAddress = '';
  String _shopPhone = '';
  dynamic _logoUploadId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _metaTitleCtrl.dispose();
    _metaDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchShopInfo();
      final data = _unwrapData(res.data);

      _shopName = (data['name'] ?? '').toString();
      _shopAddress = (data['address'] ?? '').toString();
      _shopPhone = (data['phone'] ?? '').toString();
      _logoUploadId = data['upload_id'];

      _metaTitleCtrl.text = (data['title'] ?? '').toString();
      _metaDescCtrl.text = (data['description'] ?? '').toString();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final title = _metaTitleCtrl.text.trim();
    final desc = _metaDescCtrl.text.trim();

    if (_shopName.isEmpty || _shopAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop info missing. Open “Shop Info” first.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.updateShopInfo({
        'name': _shopName,
        'address': _shopAddress,
        'phone': _shopPhone,
        'meta_title': title,
        'meta_description': desc,
        if (_logoUploadId != null) 'logo': _logoUploadId,
      });
      final msg = _extractMessage(res.data) ?? 'SEO updated';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DesignTokens.brandAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Shop SEO', style: DesignTokens.textTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  title: 'Failed to load shop SEO',
                  error: _error!,
                  onRetry: _load,
                )
              : ListView(
                  padding: DesignTokens.paddingScreen,
                  children: [
                    Container(
                      padding: DesignTokens.paddingLg,
                      decoration: BoxDecoration(
                        color: DesignTokens.surfaceWhite,
                        borderRadius: DesignTokens.borderRadiusLg,
                        boxShadow: DesignTokens.shadowSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Search metadata', style: DesignTokens.textBodyBold),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _metaTitleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Meta title',
                              prefixIcon: Icon(Icons.title),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _metaDescCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Meta description',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.error, required this.onRetry});

  final String title;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: DesignTokens.textBodyBold, textAlign: TextAlign.center),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(error.toString(), style: DesignTokens.textSmall, textAlign: TextAlign.center),
            const SizedBox(height: DesignTokens.spaceMd),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _unwrapData(dynamic body) {
  if (body is Map<String, dynamic>) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
  return <String, dynamic>{};
}

String? _extractMessage(dynamic body) {
  if (body is Map<String, dynamic>) {
    final message = body['message'] ?? body['msg'] ?? body['error'];
    if (message != null) return message.toString();
  }
  return null;
}
