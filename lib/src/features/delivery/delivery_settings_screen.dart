import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/business_profile_cache.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  ConsumerState<DeliverySettingsScreen> createState() =>
      _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState
    extends ConsumerState<DeliverySettingsScreen> {
  static const double _minRadiusKm = 0.5;
  double _maxRadiusKm = 5;

  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  Object? _error;
  bool _hasCachedProfile = false;

  bool _platformEnabled = true;
  bool _sellerVerified = false;

  bool _enabled = false;
  double _radiusKm = 5;
  String _pricingMode = 'flat';
  double _previewDistance = 3;
  bool _locating = false;

  double _platformFeePercent = 10;
  double _minPlatformFee = 500;
  double? _maxPlatformFee;

  final _originLabelCtrl = TextEditingController();
  final _originLatCtrl = TextEditingController();
  final _originLngCtrl = TextEditingController();

  final _baseFeeCtrl = TextEditingController();
  final _perKmFeeCtrl = TextEditingController();
  final _minFeeCtrl = TextEditingController();
  final _maxFeeCtrl = TextEditingController();

  final _etaMinCtrl = TextEditingController();
  final _etaMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _originLabelCtrl.dispose();
    _originLatCtrl.dispose();
    _originLngCtrl.dispose();
    _baseFeeCtrl.dispose();
    _perKmFeeCtrl.dispose();
    _minFeeCtrl.dispose();
    _maxFeeCtrl.dispose();
    _etaMinCtrl.dispose();
    _etaMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final cachedProfile = await db.getBusinessProfile();
    final hasCachedProfile = cachedProfile != null;

    if (!mounted) return;
    setState(() {
      _error = null;
      _hasCachedProfile = hasCachedProfile;
      _loading = !hasCachedProfile;
      _refreshing = hasCachedProfile;
    });

    if (cachedProfile != null) {
      _applyCachedBusinessProfile(cachedProfile);
    }

    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchDeliveryProfile();
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw StateError('Unexpected response');
      }
      if (body['result'] != true) {
        throw StateError((body['message'] ?? 'Failed to load').toString());
      }

      _platformEnabled = body['platform_enabled'] != false;
      _sellerVerified = body['seller_verified'] == true;

      final feeSplitPolicy = body['fee_split_policy'] is Map<String, dynamic>
          ? (body['fee_split_policy'] as Map<String, dynamic>)
          : <String, dynamic>{};
      _platformFeePercent =
          _toDouble(feeSplitPolicy['platform_fee_percent']) ?? 10;
      _minPlatformFee = _toDouble(feeSplitPolicy['min_platform_fee']) ?? 500;
      _maxPlatformFee = _toDouble(feeSplitPolicy['max_platform_fee']);

      final defaults = body['defaults'] is Map<String, dynamic>
          ? (body['defaults'] as Map<String, dynamic>)
          : <String, dynamic>{};
      final profile = body['profile'] is Map<String, dynamic>
          ? (body['profile'] as Map<String, dynamic>)
          : null;
      final shopOrigin = body['shop_origin'] is Map<String, dynamic>
          ? (body['shop_origin'] as Map<String, dynamic>)
          : <String, dynamic>{};

      _maxRadiusKm = (_toDouble(defaults['radius_km_max']) ?? _maxRadiusKm)
          .clamp(_minRadiusKm, 1000)
          .toDouble();

      if (cachedProfile != null &&
          !cachedProfile.synced &&
          cachedProfile.deliveryProfileJson != null) {
        return;
      }
      final source = profile ?? defaults;

      _enabled = (source['enabled'] == true);
      _radiusKm = (_toDouble(source['radius_km']) ?? _maxRadiusKm)
          .clamp(_minRadiusKm, _maxRadiusKm)
          .toDouble();
      _pricingMode = (source['pricing_mode'] ?? 'flat').toString();

      final originLabel =
          (source['origin_label'] ?? shopOrigin['origin_label'] ?? '')
              .toString();
      final originLat =
          _toDouble(source['origin_lat']) ??
          _toDouble(shopOrigin['origin_lat']);
      final originLng =
          _toDouble(source['origin_lng']) ??
          _toDouble(shopOrigin['origin_lng']);

      _originLabelCtrl.text = originLabel;
      _originLatCtrl.text = originLat != null
          ? originLat.toStringAsFixed(7)
          : '';
      _originLngCtrl.text = originLng != null
          ? originLng.toStringAsFixed(7)
          : '';

      _baseFeeCtrl.text = (_toDouble(source['base_fee']) ?? 0).toStringAsFixed(
        0,
      );
      _perKmFeeCtrl.text = (_toDouble(source['per_km_fee']) ?? 0)
          .toStringAsFixed(0);
      _minFeeCtrl.text = (_toDouble(source['min_fee']) ?? 0).toStringAsFixed(0);
      _maxFeeCtrl.text = _toDouble(source['max_fee'])?.toStringAsFixed(0) ?? '';

      _etaMinCtrl.text = (source['eta_min_minutes'] ?? '').toString();
      _etaMaxCtrl.text = (source['eta_max_minutes'] ?? '').toString();

      await _persistDeliveryProfileLocally(
        enabled: _enabled,
        radiusKm: _radiusKm,
        pricingMode: _pricingMode,
        baseFee: _toDouble(source['base_fee']) ?? 0,
        perKmFee: _toDouble(source['per_km_fee']) ?? 0,
        minFee: _toDouble(source['min_fee']) ?? 0,
        maxFee: _toDouble(source['max_fee']),
        originLabel: originLabel,
        originLat: originLat,
        originLng: originLng,
        etaMin: int.tryParse(_etaMinCtrl.text.trim()),
        etaMax: int.tryParse(_etaMaxCtrl.text.trim()),
        markSynced: true,
      );
    } catch (e) {
      if (!hasCachedProfile) {
        _error = e;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final originLabel = _originLabelCtrl.text.trim();
    final originLat = _tryParseDouble(_originLatCtrl.text.trim());
    final originLng = _tryParseDouble(_originLngCtrl.text.trim());

    final baseFee = _tryParseDouble(_baseFeeCtrl.text.trim()) ?? 0;
    final perKmFee = _tryParseDouble(_perKmFeeCtrl.text.trim()) ?? 0;
    final minFee = _tryParseDouble(_minFeeCtrl.text.trim()) ?? 0;
    final maxFee = _tryParseDouble(_maxFeeCtrl.text.trim());

    final etaMin = int.tryParse(_etaMinCtrl.text.trim());
    final etaMax = int.tryParse(_etaMaxCtrl.text.trim());

    if (_enabled && !_platformEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller delivery is temporarily disabled by Soko24'),
        ),
      );
      return;
    }

    if (_enabled && (!_sellerVerified)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify your shop to enable seller delivery'),
        ),
      );
      return;
    }

    if (_enabled && (originLat == null || originLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your shop location to enable local delivery'),
        ),
      );
      return;
    }

    if ([
          baseFee,
          perKmFee,
          minFee,
          if (maxFee != null) maxFee,
        ].any((v) => !v.isFinite || v < 0) ||
        (originLat != null && (!originLat.isFinite || originLat.abs() > 90)) ||
        (originLng != null && (!originLng.isFinite || originLng.abs() > 180))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the delivery fee and shop location.'),
        ),
      );
      return;
    }
    if (maxFee != null && maxFee < minFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max fee must be ≥ min fee')),
      );
      return;
    }

    if (etaMin != null && etaMax != null && etaMax < etaMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max ETA must be ≥ min ETA')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'enabled': _enabled,
        'pricing_mode': _pricingMode,
        'radius_km': _radiusKm.clamp(_minRadiusKm, _maxRadiusKm),
        'base_fee': baseFee,
        'per_km_fee': perKmFee,
        'min_fee': minFee,
        'max_fee': maxFee,
        if (originLabel.isNotEmpty) 'origin_label': originLabel,
        if (originLat != null) 'origin_lat': originLat,
        if (originLng != null) 'origin_lng': originLng,
        if (etaMin != null) 'eta_min_minutes': etaMin,
        if (etaMax != null) 'eta_max_minutes': etaMax,
      };

      await _persistDeliveryProfileLocally(
        enabled: _enabled,
        radiusKm: (_radiusKm.clamp(_minRadiusKm, _maxRadiusKm)).toDouble(),
        pricingMode: _pricingMode,
        baseFee: baseFee,
        perKmFee: perKmFee,
        minFee: minFee,
        maxFee: maxFee,
        originLabel: originLabel,
        originLat: originLat,
        originLng: originLng,
        etaMin: etaMin,
        etaMax: etaMax,
        markSynced: false,
      );

      final sync = ref.read(syncServiceProvider);
      await sync.enqueue('business_profile_patch', {
        'shipping_cost': baseFee,
        'self_delivery_active': _enabled,
        'delivery_radius_km': _radiusKm.clamp(_minRadiusKm, _maxRadiusKm),
        if (originLat != null) 'delivery_pickup_latitude': originLat,
        if (originLng != null) 'delivery_pickup_longitude': originLng,
      });
      await sync.enqueue('delivery_profile_push', payload);
      unawaited(sync.syncNow());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Delivery options saved locally. Sync will update the server.',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
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

  void _applyCachedBusinessProfile(BusinessProfile profile) {
    final deliveryProfile =
        decodeJsonObject(profile.deliveryProfileJson) ?? const {};
    final originLat =
        _toDouble(deliveryProfile['origin_lat']) ??
        profile.deliveryPickupLatitude;
    final originLng =
        _toDouble(deliveryProfile['origin_lng']) ??
        profile.deliveryPickupLongitude;

    _enabled =
        _resolveBool(deliveryProfile['enabled']) ?? profile.selfDeliveryActive;
    _radiusKm =
        (_toDouble(deliveryProfile['radius_km']) ??
                profile.deliveryRadiusKm ??
                _maxRadiusKm)
            .clamp(_minRadiusKm, _maxRadiusKm)
            .toDouble();
    _pricingMode =
        (deliveryProfile['pricing_mode']?.toString() ?? 'base_per_km')
            .trim()
            .isEmpty
        ? 'base_per_km'
        : deliveryProfile['pricing_mode'].toString();
    _originLabelCtrl.text =
        (deliveryProfile['origin_label'] ?? profile.shopAddress ?? '')
            .toString();
    _originLatCtrl.text = originLat != null ? originLat.toStringAsFixed(7) : '';
    _originLngCtrl.text = originLng != null ? originLng.toStringAsFixed(7) : '';
    _baseFeeCtrl.text =
        (_toDouble(deliveryProfile['base_fee']) ?? profile.shippingCost ?? 0)
            .toStringAsFixed(0);
    _perKmFeeCtrl.text = (_toDouble(deliveryProfile['per_km_fee']) ?? 0)
        .toStringAsFixed(0);
    _minFeeCtrl.text = (_toDouble(deliveryProfile['min_fee']) ?? 0)
        .toStringAsFixed(0);
    _maxFeeCtrl.text =
        _toDouble(deliveryProfile['max_fee'])?.toStringAsFixed(0) ?? '';
    _etaMinCtrl.text = (deliveryProfile['eta_min_minutes'] ?? '').toString();
    _etaMaxCtrl.text = (deliveryProfile['eta_max_minutes'] ?? '').toString();
  }

  Future<void> _persistDeliveryProfileLocally({
    required bool enabled,
    required double radiusKm,
    required String pricingMode,
    required double baseFee,
    required double perKmFee,
    required double minFee,
    required double? maxFee,
    required String originLabel,
    required double? originLat,
    required double? originLng,
    required int? etaMin,
    required int? etaMax,
    required bool markSynced,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getBusinessProfile();
    final payload = <String, dynamic>{
      'enabled': enabled,
      'pricing_mode': pricingMode,
      'radius_km': radiusKm,
      'base_fee': baseFee,
      'per_km_fee': perKmFee,
      'min_fee': minFee,
      if (maxFee != null) 'max_fee': maxFee,
      if (originLabel.trim().isNotEmpty) 'origin_label': originLabel.trim(),
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (etaMin != null) 'eta_min_minutes': etaMin,
      if (etaMax != null) 'eta_max_minutes': etaMax,
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
        shippingCost: Value(baseFee),
        selfDeliveryActive: Value(enabled),
        deliveryRadiusKm: Value(radiusKm),
        deliveryPickupLatitude: originLat == null
            ? const Value.absent()
            : Value(originLat),
        deliveryPickupLongitude: originLng == null
            ? const Value.absent()
            : Value(originLng),
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
        deliveryProfileJson: Value(jsonEncode(payload)),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: Value(markSynced),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final free =
        _pricingMode == 'flat' &&
        (_tryParseDouble(_baseFeeCtrl.text) ?? 0) == 0;
    final price = _calcFee(
      distanceKm: _previewDistance,
      baseFee: _tryParseDouble(_baseFeeCtrl.text) ?? 0,
      perKmFee: _tryParseDouble(_perKmFeeCtrl.text) ?? 0,
      minFee: _tryParseDouble(_minFeeCtrl.text) ?? 0,
      maxFee: _tryParseDouble(_maxFeeCtrl.text),
      pricingMode: _pricingMode,
    );
    final within = _enabled && _previewDistance <= _radiusKm;
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: const Text('Delivery area & fees'),
        actions: [
          IconButton(
            onPressed: _refreshing || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save delivery settings'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_hasCachedProfile
          ? _ErrorState(
              title: 'Could not load delivery settings',
              error: _error!,
              onRetry: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (_refreshing) const LinearProgressIndicator(),
                const Text(
                  'You handle nearby deliveries. Soko delivery options are shown at checkout for customers outside your area.',
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '1. My shop delivers nearby',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Offer local delivery'),
                        subtitle: Text(
                          !_platformEnabled
                              ? 'Local delivery is temporarily unavailable'
                              : !_sellerVerified
                              ? 'Verify your shop before enabling local delivery'
                              : 'Use your own rider or a local boda boda',
                        ),
                        value: _enabled,
                        onChanged: !_sellerVerified || !_platformEnabled
                            ? null
                            : (v) => setState(() => _enabled = v),
                      ),
                      Text(
                        'Up to ${_fmtKm(_radiusKm)} km from my shop',
                        style: DesignTokens.textBodyBold,
                      ),
                      Slider(
                        value: _radiusKm.clamp(_minRadiusKm, _maxRadiusKm),
                        min: _minRadiusKm,
                        max: _maxRadiusKm,
                        divisions: ((_maxRadiusKm - _minRadiusKm) * 2)
                            .round()
                            .clamp(1, 1000),
                        label: '${_fmtKm(_radiusKm)} km',
                        onChanged: (v) =>
                            setState(() => _radiusKm = _snapKm(v)),
                      ),
                      const Text(
                        'Distance is measured from your shop to the customer. Customers outside this area need another delivery option.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '2. What will nearby customers pay?',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Free delivery'),
                            selected: free,
                            onSelected: (_) => setState(() {
                              _pricingMode = 'flat';
                              _baseFeeCtrl.text = '0';
                              _perKmFeeCtrl.text = '0';
                              _minFeeCtrl.text = '0';
                              _maxFeeCtrl.clear();
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('One fixed fee'),
                            selected: _pricingMode == 'flat' && !free,
                            onSelected: (_) => setState(() {
                              _pricingMode = 'flat';
                              if ((_tryParseDouble(_baseFeeCtrl.text) ?? 0) ==
                                  0) {
                                _baseFeeCtrl.text = '5000';
                              }
                              _perKmFeeCtrl.text = '0';
                              _minFeeCtrl.text = '0';
                              _maxFeeCtrl.clear();
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('By distance'),
                            selected: _pricingMode != 'flat',
                            onSelected: (_) =>
                                setState(() => _pricingMode = 'base_per_km'),
                          ),
                        ],
                      ),
                      if (!free) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _baseFeeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: _pricingMode == 'flat'
                                ? 'Delivery fee (UGX)'
                                : 'Starting fee (UGX)',
                            hintText: '5000',
                          ),
                        ),
                      ],
                      if (_pricingMode != 'flat') ...[
                        TextField(
                          controller: _perKmFeeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Add per kilometre (UGX)',
                          ),
                        ),
                        ExpansionTile(
                          title: const Text('Fee limits (optional)'),
                          children: [
                            TextField(
                              controller: _minFeeCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Minimum fee (UGX)',
                              ),
                            ),
                            TextField(
                              controller: _maxFeeCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Maximum fee (UGX)',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        free
                            ? 'Customers within ${_fmtKm(_radiusKm)} km pay no delivery fee.'
                            : _pricingMode == 'flat'
                            ? 'The same fee applies anywhere within ${_fmtKm(_radiusKm)} km.'
                            : 'Starting fee + distance × your per-kilometre fee.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You arrange nearby delivery. Any platform share of the delivery fee is deducted from the amount collected.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '3. Where is your shop?',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _originLabelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Shop area or address',
                          hintText: 'e.g. Nasser Road, Kampala',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          _locating
                              ? 'Finding location…'
                              : 'Use my current location',
                        ),
                      ),
                      const Text('Use this while you are at your shop.'),
                      if (_originLatCtrl.text.isNotEmpty &&
                          _originLngCtrl.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: _openInMaps,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Shop location set • View map'),
                        ),
                      ExpansionTile(
                        title: const Text('Set location manually'),
                        children: [
                          TextField(
                            controller: _originLatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                          ),
                          TextField(
                            controller: _originLngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                          ),
                          TextButton(
                            onPressed: _pasteLocationFromClipboard,
                            child: const Text('Paste coordinates'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Check an example',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: '3',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Customer distance from shop (km)',
                        ),
                        onChanged: (v) {
                          final distance = double.tryParse(v);
                          if (distance != null &&
                              distance.isFinite &&
                              distance >= 0) {
                            setState(() => _previewDistance = distance);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        within
                            ? 'Your shop delivers • ${price == 0 ? 'Free' : _ugx(price)}'
                            : 'Outside your shop delivery area • Soko delivery options',
                        style: DesignTokens.textBodyBold,
                      ),
                      if (within && price > 0)
                        Text(
                          'Your delivery share: ${_ugx(math.max(0, price - _platformFee(price)))}',
                        ),
                      if (!within)
                        const Text(
                          'Available Soko carriers or local riders and their delivery fee are confirmed at checkout. If none is available, the customer can choose an available pickup option.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Delivery time (optional)'),
                  children: [
                    TextField(
                      controller: _etaMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Usually takes at least (minutes)',
                      ),
                    ),
                    TextField(
                      controller: _etaMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Usually takes up to (minutes)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location on your phone first.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is needed, or enter your shop coordinates manually.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      setState(() {
        _originLatCtrl.text = position.latitude.toStringAsFixed(7);
        _originLngCtrl.text = position.longitude.toStringAsFixed(7);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pasteLocationFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = (data?.text ?? '').trim();
      if (text.isEmpty) return;
      final latLng = _extractLatLng(text);
      if (latLng == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find coordinates in clipboard'),
          ),
        );
        return;
      }

      _originLatCtrl.text = latLng.$1.toStringAsFixed(7);
      _originLngCtrl.text = latLng.$2.toStringAsFixed(7);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('pasteLocationFromClipboard failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to read clipboard: $e')));
    }
  }

  Future<void> _openInMaps() async {
    final lat = _tryParseDouble(_originLatCtrl.text.trim());
    final lng = _tryParseDouble(_originLngCtrl.text.trim());
    if (lat == null || lng == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await canLaunchUrl(url)) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  (double, double)? _extractLatLng(String input) {
    final matches = RegExp(r'(-?\d+(?:\.\d+)?)').allMatches(input).toList();
    if (matches.length < 2) return null;
    final lat = double.tryParse(matches[0].group(0) ?? '');
    final lng = double.tryParse(matches[1].group(0) ?? '');
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat, lng);
  }

  double _calcFee({
    required double distanceKm,
    required double baseFee,
    required double perKmFee,
    required double minFee,
    required double? maxFee,
    required String pricingMode,
  }) {
    final raw = pricingMode == 'flat'
        ? baseFee
        : baseFee + (distanceKm * perKmFee);
    var clamped = raw < minFee ? minFee : raw;
    if (maxFee != null) clamped = clamped > maxFee ? maxFee : clamped;
    return _roundUp100(clamped);
  }

  double _roundUp100(double amount) {
    if (amount <= 0) return 0;
    return (amount / 100).ceilToDouble() * 100;
  }

  double _platformFee(double totalFee) {
    if (totalFee <= 0) return 0;

    var platformFee = _roundUp100((totalFee * _platformFeePercent) / 100);
    platformFee = math.max(_minPlatformFee, platformFee);
    if (_maxPlatformFee != null) {
      platformFee = math.min(_maxPlatformFee!, platformFee);
    }
    platformFee = math.min(totalFee, platformFee);
    return platformFee;
  }

  String _ugx(double value) => '${value.toStringAsFixed(0)} /=';

  double _snapKm(double value) {
    final snapped = (value / 0.5).round() * 0.5;
    return snapped.clamp(_minRadiusKm, _maxRadiusKm).toDouble();
  }

  String _fmtKm(double value) {
    final snapped = _snapKm(value);
    final isInt = (snapped - snapped.roundToDouble()).abs() < 0.0001;
    return isInt ? snapped.toStringAsFixed(0) : snapped.toStringAsFixed(1);
  }

  double? _tryParseDouble(String input) {
    if (input.isEmpty) return null;
    final parsed = double.tryParse(input);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool? _resolveBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
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
