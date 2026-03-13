import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/business_profile_cache.dart';
import '../../core/settings/shop_payment_settings.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _bankNameCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();
  final _bankAccNoCtrl = TextEditingController();
  final _bankRoutingCtrl = TextEditingController();

  // Mobile money merchant codes
  final _mtnMerchantCtrl = TextEditingController();
  final _airtelMerchantCtrl = TextEditingController();
  final _paybillCtrl = TextEditingController();

  bool _cashEnabled = true;
  bool _bankEnabled = false;
  bool _mobileMoneyEnabled = false;

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
    _mtnMerchantCtrl.dispose();
    _airtelMerchantCtrl.dispose();
    _paybillCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = ref.read(sharedPreferencesProvider);
    final db = ref.read(appDatabaseProvider);
    final cachedProfile = await db.getBusinessProfile();
    final cached = cachedProfile != null
        ? businessProfileToPaymentSettings(cachedProfile)
        : ShopPaymentSettingsCache.tryRead(prefs);
    if (cached != null) {
      _applySettings(cached);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    }

    try {
      await ref.read(syncServiceProvider).syncNow();
      final refreshedProfile = await db.getBusinessProfile();
      if (refreshedProfile != null) {
        final settings = businessProfileToPaymentSettings(refreshedProfile);
        _applySettings(settings);
        await ShopPaymentSettingsCache.write(prefs, settings);
      }
    } catch (e) {
      if (cached == null) {
        _error = e;
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final existing = await db.getBusinessProfile();
      final settings = _collectSettings();
      await db.upsertBusinessProfile(
        BusinessProfilesCompanion.insert(
          id: kPrimaryBusinessProfileId,
          sellerId: existing?.sellerId == null
              ? const Value.absent()
              : Value(existing!.sellerId),
          sellerName: existing?.sellerName == null
              ? const Value.absent()
              : Value(existing!.sellerName),
          sellerEmail: existing?.sellerEmail == null
              ? const Value.absent()
              : Value(existing!.sellerEmail),
          sellerPhone: existing?.sellerPhone == null
              ? const Value.absent()
              : Value(existing!.sellerPhone),
          shopId: existing?.shopId == null
              ? const Value.absent()
              : Value(existing!.shopId),
          shopName: existing?.shopName ?? 'Shop',
          shopAddress: existing?.shopAddress == null
              ? const Value.absent()
              : Value(existing!.shopAddress),
          shopPhone: existing?.shopPhone == null
              ? const Value.absent()
              : Value(existing!.shopPhone),
          logoUploadId: existing?.logoUploadId == null
              ? const Value.absent()
              : Value(existing!.logoUploadId),
          logoUrl: existing?.logoUrl == null
              ? const Value.absent()
              : Value(existing!.logoUrl),
          metaTitle: existing?.metaTitle == null
              ? const Value.absent()
              : Value(existing!.metaTitle),
          metaDescription: existing?.metaDescription == null
              ? const Value.absent()
              : Value(existing!.metaDescription),
          thermalPrinterWidth: existing?.thermalPrinterWidth == null
              ? const Value.absent()
              : Value(existing!.thermalPrinterWidth),
          shippingCost: existing?.shippingCost == null
              ? const Value.absent()
              : Value(existing!.shippingCost),
          selfDeliveryActive: Value(existing?.selfDeliveryActive ?? false),
          deliveryRadiusKm: existing?.deliveryRadiusKm == null
              ? const Value.absent()
              : Value(existing!.deliveryRadiusKm),
          deliveryPickupLatitude: existing?.deliveryPickupLatitude == null
              ? const Value.absent()
              : Value(existing!.deliveryPickupLatitude),
          deliveryPickupLongitude: existing?.deliveryPickupLongitude == null
              ? const Value.absent()
              : Value(existing!.deliveryPickupLongitude),
          cashOnDeliveryEnabled: Value(settings.cashEnabled),
          bankPaymentEnabled: Value(settings.bankEnabled),
          mobileMoneyEnabled: Value(settings.mobileMoneyEnabled),
          bankName: Value(settings.bankName),
          bankAccName: Value(settings.bankAccountName),
          bankAccNo: Value(settings.bankAccountNumber),
          bankRoutingNo: Value(settings.bankRoutingNumber),
          mtnMerchantCode: Value(settings.mtnMerchantCode),
          airtelMerchantCode: Value(settings.airtelMerchantCode),
          paybillNumber: Value(settings.paybillNumber),
          receiptPaymentMethodsJson: Value(
            jsonEncode(settings.receiptPaymentMethods ?? const {}),
          ),
          deliveryProfileJson: existing?.deliveryProfileJson == null
              ? const Value.absent()
              : Value(existing!.deliveryProfileJson),
          updatedAt: Value(DateTime.now().toUtc()),
          synced: const Value(false),
        ),
      );
      await ShopPaymentSettingsCache.write(
        ref.read(sharedPreferencesProvider),
        settings,
      );
      await sync.enqueue('business_profile_patch', settings.toUpdatePayload());
      unawaited(sync.syncNow());
      const msg =
          'Payment settings saved locally. Sync will update the server.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DesignTokens.brandAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  ShopPaymentSettings _collectSettings() {
    return ShopPaymentSettings(
      cashEnabled: _cashEnabled,
      bankEnabled: _bankEnabled,
      mobileMoneyEnabled: _mobileMoneyEnabled,
      bankName: _bankNameCtrl.text.trim(),
      bankAccountName: _bankAccNameCtrl.text.trim(),
      bankAccountNumber: _bankAccNoCtrl.text.trim(),
      bankRoutingNumber: _bankRoutingCtrl.text.trim(),
      mtnMerchantCode: _mtnMerchantCtrl.text.trim(),
      airtelMerchantCode: _airtelMerchantCtrl.text.trim(),
      paybillNumber: _paybillCtrl.text.trim(),
    );
  }

  void _applySettings(ShopPaymentSettings settings) {
    _cashEnabled = settings.cashEnabled;
    _bankEnabled = settings.bankEnabled;
    _bankNameCtrl.text = settings.bankName;
    _bankAccNameCtrl.text = settings.bankAccountName;
    _bankAccNoCtrl.text = settings.bankAccountNumber;
    _bankRoutingCtrl.text = settings.bankRoutingNumber;
    _mtnMerchantCtrl.text = settings.mtnMerchantCode;
    _airtelMerchantCtrl.text = settings.airtelMerchantCode;
    _paybillCtrl.text = settings.paybillNumber;
    _mobileMoneyEnabled = settings.mobileMoneyEnabled;
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Accept mobile money'),
                        value: _mobileMoneyEnabled,
                        onChanged: (v) =>
                            setState(() => _mobileMoneyEnabled = v),
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Shown on receipts and invoices: ${_enabledMethodsSummary()}',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.grayMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_mobileMoneyEnabled) ...[
                  const SizedBox(height: DesignTokens.spaceMd),
                  _SectionCard(
                    title: 'Mobile Money',
                    child: Column(
                      children: [
                        TextField(
                          controller: _mtnMerchantCtrl,
                          decoration: InputDecoration(
                            labelText: 'MTN Merchant Code',
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCC00),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            hintText: 'e.g. 123456',
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceMd),
                        TextField(
                          controller: _airtelMerchantCtrl,
                          decoration: InputDecoration(
                            labelText: 'Airtel Merchant Code',
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFED1C24),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            hintText: 'e.g. 654321',
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceMd),
                        TextField(
                          controller: _paybillCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paybill Number',
                            prefixIcon: Icon(Icons.receipt_long),
                            hintText: 'e.g. 200200',
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Text(
                          'These codes will appear on receipts to help customers pay you via mobile money.',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.grayMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                const SizedBox(height: DesignTokens.spaceMd),
                _SectionCard(
                  title: 'Checkout defaults',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery fees and seller delivery rules live in Delivery Options so checkout, receipts, and online orders stay aligned.',
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.grayMedium,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceMd),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/home/more/delivery-settings'),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Open Delivery Options'),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                  ),
                ),
              ],
            ),
    );
  }

  String _enabledMethodsSummary() {
    final methods = <String>[];
    if (_cashEnabled) methods.add('Cash');
    if (_bankEnabled) methods.add('Bank transfer');
    if (_mobileMoneyEnabled) methods.add('Mobile money');
    return methods.isEmpty ? 'None yet' : methods.join(', ');
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
  const _ErrorState({
    required this.title,
    required this.error,
    required this.onRetry,
  });

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
            Text(
              title,
              style: DesignTokens.textBodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              error.toString(),
              style: DesignTokens.textSmall,
              textAlign: TextAlign.center,
            ),
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
