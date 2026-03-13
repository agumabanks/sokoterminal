import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/business_profile_cache.dart';
import '../../core/sync/sync_service.dart';
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
      final db = ref.read(appDatabaseProvider);
      final cached = await db.getBusinessProfile();
      if (cached != null) {
        _applyBusinessProfile(cached);
      }

      await ref.read(syncServiceProvider).syncNow();

      final refreshed = await db.getBusinessProfile();
      if (refreshed != null) {
        _applyBusinessProfile(refreshed);
      } else if (cached == null) {
        _error = StateError('No business profile found on device');
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final existing = await db.getBusinessProfile();
      final payload = <String, dynamic>{
        'name': name,
        'address': address,
        'phone': phone,
        'meta_title': metaTitle,
        'meta_description': metaDescription,
        if (_logoUploadId != null) 'logo': _logoUploadId,
      };
      await db.upsertBusinessProfile(
        BusinessProfilesCompanion.insert(
          id: kPrimaryBusinessProfileId,
          sellerId: existing?.sellerId == null
              ? const Value.absent()
              : Value(existing!.sellerId),
          sellerName: existing?.sellerName == null
              ? const Value.absent()
              : Value(existing!.sellerName),
          sellerEmail: Value(_email),
          sellerPhone: existing?.sellerPhone == null
              ? const Value.absent()
              : Value(existing!.sellerPhone),
          shopId: existing?.shopId == null
              ? const Value.absent()
              : Value(existing!.shopId),
          shopName: name,
          shopAddress: Value(address),
          shopPhone: Value(phone),
          logoUploadId: _logoUploadId is int
              ? Value(_logoUploadId as int)
              : const Value.absent(),
          logoUrl: existing?.logoUrl == null
              ? const Value.absent()
              : Value(existing!.logoUrl),
          metaTitle: Value(metaTitle),
          metaDescription: Value(metaDescription),
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
          cashOnDeliveryEnabled: Value(existing?.cashOnDeliveryEnabled ?? true),
          bankPaymentEnabled: Value(existing?.bankPaymentEnabled ?? false),
          mobileMoneyEnabled: Value(existing?.mobileMoneyEnabled ?? true),
          bankName: existing?.bankName == null
              ? const Value.absent()
              : Value(existing!.bankName),
          bankAccName: existing?.bankAccName == null
              ? const Value.absent()
              : Value(existing!.bankAccName),
          bankAccNo: existing?.bankAccNo == null
              ? const Value.absent()
              : Value(existing!.bankAccNo),
          bankRoutingNo: existing?.bankRoutingNo == null
              ? const Value.absent()
              : Value(existing!.bankRoutingNo),
          mtnMerchantCode: existing?.mtnMerchantCode == null
              ? const Value.absent()
              : Value(existing!.mtnMerchantCode),
          airtelMerchantCode: existing?.airtelMerchantCode == null
              ? const Value.absent()
              : Value(existing!.airtelMerchantCode),
          paybillNumber: existing?.paybillNumber == null
              ? const Value.absent()
              : Value(existing!.paybillNumber),
          receiptPaymentMethodsJson: existing?.receiptPaymentMethodsJson == null
              ? const Value.absent()
              : Value(existing!.receiptPaymentMethodsJson),
          deliveryProfileJson: existing?.deliveryProfileJson == null
              ? const Value.absent()
              : Value(existing!.deliveryProfileJson),
          updatedAt: Value(DateTime.now().toUtc()),
          synced: const Value(false),
        ),
      );
      await sync.enqueue('business_profile_patch', payload);
      unawaited(sync.syncNow());
      const msg = 'Shop info saved locally. Sync will update the server.';
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

  void _applyBusinessProfile(BusinessProfile profile) {
    _nameCtrl.text = profile.shopName;
    _phoneCtrl.text = profile.shopPhone ?? '';
    _addressCtrl.text = profile.shopAddress ?? '';
    _email = profile.sellerEmail;
    _logoUploadId = profile.logoUploadId;
    _metaTitleCtrl.text = profile.metaTitle ?? '';
    _metaDescCtrl.text = profile.metaDescription ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: Text('Shop Info', style: DesignTokens.textTitle)),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                  ),
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
