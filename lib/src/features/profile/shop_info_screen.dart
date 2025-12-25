import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class ShopInfoScreen extends ConsumerStatefulWidget {
  const ShopInfoScreen({super.key});

  @override
  ConsumerState<ShopInfoScreen> createState() => _ShopInfoScreenState();
}

class _ShopInfoScreenState extends ConsumerState<ShopInfoScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _metaTitleCtrl = TextEditingController();
  final _metaDescCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  String? _email;
  dynamic _logoUploadId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
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

      _nameCtrl.text = (data['name'] ?? '').toString();
      _phoneCtrl.text = (data['phone'] ?? '').toString();
      _addressCtrl.text = (data['address'] ?? '').toString();

      _email = (data['email'] ?? '').toString();
      final metaTitle = (data['title'] ?? '').toString();
      final metaDescription = (data['description'] ?? '').toString();
      _logoUploadId = data['upload_id'];
      _metaTitleCtrl.text = metaTitle;
      _metaDescCtrl.text = metaDescription;
    } catch (e) {
      _error = e;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final metaTitle = _metaTitleCtrl.text.trim();
    final metaDescription = _metaDescCtrl.text.trim();

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name and address are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(sellerApiProvider);
      final payload = <String, dynamic>{
        'name': name,
        'address': address,
        'phone': phone,
        'meta_title': metaTitle,
        'meta_description': metaDescription,
        if (_logoUploadId != null) 'logo': _logoUploadId,
      };
      final res = await api.updateShopInfo(payload);
      final msg = _extractMessage(res.data) ?? 'Shop info updated';
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
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Shop Info', style: DesignTokens.textTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  title: 'Failed to load shop info',
                  error: _error!,
                  onRetry: _load,
                )
              : ListView(
                  padding: DesignTokens.paddingScreen,
                  children: [
                    _SectionCard(
                      title: 'Basic info',
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Shop name',
                              prefixIcon: Icon(Icons.store_mall_directory_outlined),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact phone',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextFormField(
                            enabled: false,
                            initialValue: _email ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    _SectionCard(
                      title: 'Online details',
                      child: Column(
                        children: [
                          TextField(
                            controller: _metaTitleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Shop tagline',
                              prefixIcon: Icon(Icons.title),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _metaDescCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Shop description',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceMd),
          child,
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
