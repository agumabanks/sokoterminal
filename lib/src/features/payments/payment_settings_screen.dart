import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _bankNameCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();
  final _bankAccNoCtrl = TextEditingController();
  final _bankRoutingCtrl = TextEditingController();

  bool _cashEnabled = true;
  bool _bankEnabled = false;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _bankAccNoCtrl.dispose();
    _bankRoutingCtrl.dispose();
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

      _cashEnabled = _asBool(data['cash_on_delivery_status'], defaultValue: true);
      _bankEnabled = _asBool(data['bank_payment_status'], defaultValue: false);

      _bankNameCtrl.text = (data['bank_name'] ?? '').toString();
      _bankAccNameCtrl.text = (data['bank_acc_name'] ?? '').toString();
      _bankAccNoCtrl.text = (data['bank_acc_no'] ?? '').toString();
      _bankRoutingCtrl.text = (data['bank_routing_no'] ?? '').toString();
    } catch (e) {
      _error = e;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.updateShopInfo({
        'cash_on_delivery_status': _cashEnabled ? 1 : 0,
        'bank_payment_status': _bankEnabled ? 1 : 0,
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_acc_name': _bankAccNameCtrl.text.trim(),
        'bank_acc_no': _bankAccNoCtrl.text.trim(),
        'bank_routing_no': _bankRoutingCtrl.text.trim(),
      });

      final msg = _extractMessage(res.data) ?? 'Payment settings updated';
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
        title: Text('Payment Settings', style: DesignTokens.textTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  title: 'Failed to load payment settings',
                  error: _error!,
                  onRetry: _load,
                )
              : ListView(
                  padding: DesignTokens.paddingScreen,
                  children: [
                    _SectionCard(
                      title: 'Accepted payment methods',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Accept cash'),
                            value: _cashEnabled,
                            onChanged: (v) => setState(() => _cashEnabled = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Accept bank transfer'),
                            value: _bankEnabled,
                            onChanged: (v) => setState(() => _bankEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    _SectionCard(
                      title: 'Bank account',
                      child: Column(
                        children: [
                          TextField(
                            controller: _bankAccNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Account name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _bankAccNoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Account number',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _bankNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Bank name',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          TextField(
                            controller: _bankRoutingCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Routing number (optional)',
                              prefixIcon: Icon(Icons.alt_route),
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

bool _asBool(dynamic value, {required bool defaultValue}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase().trim();
  if (s == '1' || s == 'true' || s == 'yes') return true;
  if (s == '0' || s == 'false' || s == 'no') return false;
  return defaultValue;
}

String? _extractMessage(dynamic body) {
  if (body is Map<String, dynamic>) {
    final message = body['message'] ?? body['msg'] ?? body['error'];
    if (message != null) return message.toString();
  }
  return null;
}

