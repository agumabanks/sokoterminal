import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  ConsumerState<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends ConsumerState<DeliverySettingsScreen> {
  static const double _maxRadiusKm = 5;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  bool _platformEnabled = true;
  bool _sellerVerified = false;

  bool _enabled = false;
  double _radiusKm = _maxRadiusKm;
  String _pricingMode = 'base_per_km';

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
    setState(() {
      _loading = true;
      _error = null;
    });

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
      _platformFeePercent = _toDouble(feeSplitPolicy['platform_fee_percent']) ?? 10;
      _minPlatformFee = _toDouble(feeSplitPolicy['min_platform_fee']) ?? 500;
      _maxPlatformFee = _toDouble(feeSplitPolicy['max_platform_fee']);

      final defaults = body['defaults'] is Map<String, dynamic> ? (body['defaults'] as Map<String, dynamic>) : <String, dynamic>{};
      final profile = body['profile'] is Map<String, dynamic> ? (body['profile'] as Map<String, dynamic>) : null;
      final shopOrigin = body['shop_origin'] is Map<String, dynamic> ? (body['shop_origin'] as Map<String, dynamic>) : <String, dynamic>{};

      final source = profile ?? defaults;

      _enabled = (source['enabled'] == true);
      _radiusKm = (_toDouble(source['radius_km']) ?? _maxRadiusKm).clamp(1, _maxRadiusKm).toDouble();
      _pricingMode = (source['pricing_mode'] ?? 'base_per_km').toString();

      final originLabel = (source['origin_label'] ?? shopOrigin['origin_label'] ?? '').toString();
      final originLat = _toDouble(source['origin_lat']) ?? _toDouble(shopOrigin['origin_lat']);
      final originLng = _toDouble(source['origin_lng']) ?? _toDouble(shopOrigin['origin_lng']);

      _originLabelCtrl.text = originLabel;
      _originLatCtrl.text = originLat != null ? originLat.toStringAsFixed(7) : '';
      _originLngCtrl.text = originLng != null ? originLng.toStringAsFixed(7) : '';

      _baseFeeCtrl.text = (_toDouble(source['base_fee']) ?? 0).toStringAsFixed(0);
      _perKmFeeCtrl.text = (_toDouble(source['per_km_fee']) ?? 0).toStringAsFixed(0);
      _minFeeCtrl.text = (_toDouble(source['min_fee']) ?? 0).toStringAsFixed(0);
      _maxFeeCtrl.text = _toDouble(source['max_fee'])?.toStringAsFixed(0) ?? '';

      _etaMinCtrl.text = (source['eta_min_minutes'] ?? '').toString();
      _etaMaxCtrl.text = (source['eta_max_minutes'] ?? '').toString();
    } catch (e) {
      _error = e;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
        const SnackBar(content: Text('Seller delivery is temporarily disabled by Soko24')),
      );
      return;
    }

    if (_enabled && (!_sellerVerified)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify your shop to enable seller delivery')),
      );
      return;
    }

    if (_enabled && (originLat == null || originLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set an origin location (lat/lng) to enable seller delivery')),
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
      final api = ref.read(sellerApiProvider);
      final payload = <String, dynamic>{
        'enabled': _enabled,
        'pricing_mode': _pricingMode,
        'radius_km': _radiusKm.clamp(1, _maxRadiusKm),
        'base_fee': baseFee,
        'per_km_fee': perKmFee,
        'min_fee': minFee,
        if (maxFee != null) 'max_fee': maxFee,
        if (originLabel.isNotEmpty) 'origin_label': originLabel,
        if (originLat != null) 'origin_lat': originLat,
        if (originLng != null) 'origin_lng': originLng,
        if (etaMin != null) 'eta_min_minutes': etaMin,
        if (etaMax != null) 'eta_max_minutes': etaMax,
      };

      final res = await api.upsertDeliveryProfile(payload);
      final body = res.data;
      final msg = (body is Map<String, dynamic> ? (body['message'] ?? body['msg']) : null)?.toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Saved'), backgroundColor: DesignTokens.brandAccent),
      );
      unawaited(_load());
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
    final baseFee = _tryParseDouble(_baseFeeCtrl.text.trim()) ?? 0;
    final perKmFee = _tryParseDouble(_perKmFeeCtrl.text.trim()) ?? 0;
    final minFee = _tryParseDouble(_minFeeCtrl.text.trim()) ?? 0;
    final maxFee = _tryParseDouble(_maxFeeCtrl.text.trim());

    final preview1 = _calcFee(distanceKm: 1, baseFee: baseFee, perKmFee: perKmFee, minFee: minFee, maxFee: maxFee, pricingMode: _pricingMode);
    final preview3 = _calcFee(distanceKm: 3, baseFee: baseFee, perKmFee: perKmFee, minFee: minFee, maxFee: maxFee, pricingMode: _pricingMode);
    final preview5 = _calcFee(distanceKm: 5, baseFee: baseFee, perKmFee: perKmFee, minFee: minFee, maxFee: maxFee, pricingMode: _pricingMode);
    final preview1PlatformFee = _platformFee(preview1);
    final preview3PlatformFee = _platformFee(preview3);
    final preview5PlatformFee = _platformFee(preview5);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: Text('Delivery Settings', style: DesignTokens.textTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  title: 'Failed to load delivery settings',
                  error: _error!,
                  onRetry: _load,
                )
              : ListView(
                  padding: DesignTokens.paddingScreen,
                  children: [
                    _SectionCard(
                      title: 'Seller delivery',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable seller delivery'),
                            subtitle: Text(
                              !_platformEnabled
                                  ? 'Seller delivery is temporarily disabled by Soko24'
                                  : (_sellerVerified
                                      ? 'Deliver locally to nearby buyers'
                                      : 'Verify your shop to enable seller delivery'),
                              style: DesignTokens.textSmall,
                            ),
                            value: _enabled,
                            onChanged: (!_sellerVerified || !_platformEnabled)
                                ? null
                                : (v) => setState(() => _enabled = v),
                          ),
                          const SizedBox(height: DesignTokens.spaceSm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Seller delivery is limited to ${_maxRadiusKm.toStringAsFixed(0)} km. Outside this radius, buyers will use Soko24 delivery.',
                              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayDark),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceSm),
                          Row(
                            children: [
                              const Icon(Icons.radio_button_checked, size: 18, color: DesignTokens.grayDark),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Radius: ${_radiusKm.toStringAsFixed(0)} km',
                                  style: DesignTokens.textBody,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _radiusKm.clamp(1, _maxRadiusKm).toDouble(),
                            min: 1,
                            max: _maxRadiusKm,
                            divisions: (_maxRadiusKm - 1).toInt(),
                            label: '${_radiusKm.toStringAsFixed(0)} km',
                            onChanged: (v) => setState(() => _radiusKm = v),
                          ),
                          const SizedBox(height: DesignTokens.spaceSm),
                          DropdownButtonFormField<String>(
                            value: _pricingMode,
                            decoration: const InputDecoration(
                              labelText: 'Pricing model',
                              prefixIcon: Icon(Icons.price_change_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'base_per_km',
                                child: Text('Base fee + per km (recommended)'),
                              ),
                              DropdownMenuItem(
                                value: 'flat',
                                child: Text('Flat fee (within radius)'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _pricingMode = v ?? 'base_per_km'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    _SectionCard(
                      title: 'Origin (where you start)',
                      child: Column(
                        children: [
                          TextField(
                            controller: _originLabelCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Location label',
                              hintText: 'e.g. Kisaasi, Kampala',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _originLatCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude',
                                    prefixIcon: Icon(Icons.my_location_outlined),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceSm),
                              Expanded(
                                child: TextField(
                                  controller: _originLngCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude',
                                    prefixIcon: Icon(Icons.my_location_outlined),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spaceSm),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pasteLocationFromClipboard,
                                  icon: const Icon(Icons.content_paste_outlined),
                                  label: const Text('Paste'),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceSm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openInMaps,
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Open in Maps'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    _SectionCard(
                      title: 'Fees (UGX)',
                      child: Column(
                        children: [
                          TextField(
                            controller: _baseFeeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _pricingMode == 'flat' ? 'Flat fee' : 'Base fee',
                              prefixIcon: const Icon(Icons.payments_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          if (_pricingMode != 'flat')
                            TextField(
                              controller: _perKmFeeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Per km fee',
                                prefixIcon: Icon(Icons.linear_scale_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          if (_pricingMode != 'flat')
                            const SizedBox(height: DesignTokens.spaceMd),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _minFeeCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Minimum fee',
                                    prefixIcon: Icon(Icons.arrow_upward),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceSm),
                              Expanded(
                                child: TextField(
                                  controller: _maxFeeCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Maximum fee (optional)',
                                    prefixIcon: Icon(Icons.arrow_downward),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DesignTokens.spaceMd),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Platform system charge: ${_platformFeePercent.toStringAsFixed(0)}% (min ${_ugx(_minPlatformFee)}${_maxPlatformFee != null ? ', max ${_ugx(_maxPlatformFee!)}' : ''}).',
                              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayDark),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spaceSm),
                          _PreviewRow(label: '1 km (customer pays)', value: _ugx(preview1)),
                          _PreviewRow(label: '1 km (you receive)', value: _ugx(math.max(0, preview1 - preview1PlatformFee))),
                          const SizedBox(height: DesignTokens.spaceSm),
                          _PreviewRow(label: '3 km (customer pays)', value: _ugx(preview3)),
                          _PreviewRow(label: '3 km (you receive)', value: _ugx(math.max(0, preview3 - preview3PlatformFee))),
                          const SizedBox(height: DesignTokens.spaceSm),
                          _PreviewRow(label: '5 km (customer pays)', value: _ugx(preview5)),
                          _PreviewRow(label: '5 km (you receive)', value: _ugx(math.max(0, preview5 - preview5PlatformFee))),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    _SectionCard(
                      title: 'ETA (optional)',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _etaMinCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Min minutes',
                                    prefixIcon: Icon(Icons.timer_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignTokens.spaceSm),
                              Expanded(
                                child: TextField(
                                  controller: _etaMaxCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Max minutes',
                                    prefixIcon: Icon(Icons.timer_outlined),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                  ],
                ),
    );
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
          const SnackBar(content: Text('Could not find coordinates in clipboard')),
        );
        return;
      }

      _originLatCtrl.text = latLng.$1.toStringAsFixed(7);
      _originLngCtrl.text = latLng.$2.toStringAsFixed(7);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _openInMaps() async {
    final lat = _tryParseDouble(_originLatCtrl.text.trim());
    final lng = _tryParseDouble(_originLngCtrl.text.trim());
    if (lat == null || lng == null) return;

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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
    final raw = pricingMode == 'flat' ? baseFee : baseFee + (distanceKm * perKmFee);
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

  String _ugx(double value) => 'UGX ${value.toStringAsFixed(0)}';

  double? _tryParseDouble(String input) {
    if (input.isEmpty) return null;
    return double.tryParse(input);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DesignTokens.textSmall)),
          Text(value, style: DesignTokens.textBodyBold),
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
