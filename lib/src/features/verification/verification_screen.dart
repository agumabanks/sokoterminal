import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _loading = true;
  Object? _error;
  bool _submitting = false;

  Map<String, dynamic> _shop = {};
  List<_VerifyField> _fields = const [];
  List<_SellerPackage> _packages = const [];

  final Map<int, TextEditingController> _textControllers = {};
  final Map<int, String?> _singleValues = {};
  final Map<int, List<String>> _multiValues = {};
  final Map<int, PlatformFile?> _files = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(sellerApiProvider);

      final shopRes = await api.fetchShopInfo();
      final shop = _unwrapData(shopRes.data);

      final formRes = await api.fetchVerificationForm();
      final formFields = _unwrapList(formRes.data);
      final fields = formFields.map(_VerifyField.fromJson).toList();

      final packagesRes = await api.fetchSellerPackages();
      final packagesRaw = _unwrapList(packagesRes.data);
      final packages = packagesRaw
          .whereType<Map<String, dynamic>>()
          .map(_SellerPackage.fromJson)
          .toList();

      _shop = shop;
      _fields = fields;
      _packages = packages;

      _resetFormState();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _resetFormState() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _textControllers.clear();
    _singleValues.clear();
    _multiValues.clear();
    _files.clear();

    for (var i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      switch (field.type) {
        case 'text':
          _textControllers[i] = TextEditingController();
          break;
        case 'select':
        case 'radio':
          _singleValues[i] = field.options.isNotEmpty ? field.options.first : null;
          break;
        case 'multi_select':
          _multiValues[i] = <String>[];
          break;
        case 'file':
          _files[i] = null;
          break;
      }
    }
  }

  bool get _isVerified => _asBool(_shop['verified']);
  bool get _isSubmitted => _asBool(_shop['is_submitted_form']);

  Future<void> _pickFile(int index) async {
    final result = await FilePicker.platform.pickFiles(withData: false, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    setState(() => _files[index] = result.files.first);
  }

  Future<void> _submitVerification() async {
    if (_fields.isEmpty) return;

    for (var i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      if (field.type == 'file' && (_files[i]?.path == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please attach: ${field.label}')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{};
      for (var i = 0; i < _fields.length; i++) {
        final field = _fields[i];
        final key = 'element_$i';
        switch (field.type) {
          case 'text':
            payload[key] = _textControllers[i]?.text.trim() ?? '';
            break;
          case 'select':
          case 'radio':
            payload[key] = (_singleValues[i] ?? '').trim();
            break;
          case 'multi_select':
            payload['$key[]'] = _multiValues[i] ?? <String>[];
            break;
          case 'file':
            final f = _files[i];
            if (f?.path == null) break;
            payload[key] = await MultipartFile.fromFile(
              f!.path!,
              filename: f.name,
            );
            break;
        }
      }

      final api = ref.read(sellerApiProvider);
      final res = await api.submitVerification(FormData.fromMap(payload));
      final msg = _extractMessage(res.data) ?? 'Verification submitted';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DesignTokens.brandAccent),
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _toggleMulti(int index, String value) {
    final list = _multiValues[index] ?? <String>[];
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    setState(() => _multiValues[index] = List<String>.from(list));
  }

  Future<void> _selectPackage(_SellerPackage pack) async {
    if (pack.price <= 0) {
      await _purchaseFreePackage(pack);
      return;
    }
    _showOfflinePaymentSheet(pack);
  }

  Future<void> _purchaseFreePackage(_SellerPackage pack) async {
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.purchaseSellerPackageFree(packageId: pack.id, amount: pack.price);
      final msg = _extractMessage(res.data) ?? 'Package selection submitted';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: DesignTokens.brandAccent),
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Package selection failed: $e')),
      );
    }
  }

  void _showOfflinePaymentSheet(_SellerPackage pack) {
    final optionCtrl = TextEditingController(text: 'bank_transfer');
    final trxCtrl = TextEditingController();
    PlatformFile? receipt;
    final parentContext = context;

    BottomSheetModal.show(
      context: context,
      title: 'Offline payment',
      subtitle: 'Package: ${pack.name}',
      child: StatefulBuilder(
        builder: (sheetContext, setLocalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: optionCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment option',
                hintText: 'e.g. bank_transfer, mobile_money',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            TextField(
              controller: trxCtrl,
              decoration: const InputDecoration(
                labelText: 'Transaction reference (optional)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long),
              title: Text(receipt?.name ?? 'Attach receipt (optional)'),
              subtitle: receipt?.path != null ? Text(receipt!.path!) : null,
              trailing: TextButton(
                onPressed: () async {
                  final picked = await FilePicker.platform.pickFiles(
                    withData: false,
                    allowMultiple: false,
                    type: FileType.image,
                  );
                  if (picked == null || picked.files.isEmpty) return;
                  setLocalState(() => receipt = picked.files.first);
                },
                child: const Text('Choose'),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: () async {
                final option = optionCtrl.text.trim();
                if (option.isEmpty) return;

                String? photoBase64;
                if (receipt?.path != null) {
                  final bytes = await File(receipt!.path!).readAsBytes();
                  photoBase64 = base64Encode(bytes);
                }

                try {
                  final api = ref.read(sellerApiProvider);
                  final res = await api.purchaseSellerPackageOffline(
                    packageId: pack.id,
                    paymentOption: option,
                    trxId: trxCtrl.text.trim().isEmpty ? null : trxCtrl.text.trim(),
                    photoBase64: photoBase64,
                  );
                  final msg = _extractMessage(res.data) ?? 'Offline payment submitted';
                  if (!parentContext.mounted) return;
                  Navigator.pop(parentContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: DesignTokens.brandAccent),
                  );
                  unawaited(_load());
                } catch (e) {
                  if (!parentContext.mounted) return;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Offline payment failed: $e')),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Verification & Packages', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  title: 'Failed to load verification',
                  error: _error!,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: DesignTokens.paddingScreen,
                    children: [
                      _StatusCard(verified: _isVerified, submitted: _isSubmitted),
                      const SizedBox(height: DesignTokens.spaceLg),
                      Text('Verification form', style: DesignTokens.textBodyBold),
                      const SizedBox(height: DesignTokens.spaceSm),
                      _fields.isEmpty
                          ? Text('No verification form configured.', style: DesignTokens.textSmall)
                          : _FormCard(
                              fields: _fields,
                              textControllers: _textControllers,
                              singleValues: _singleValues,
                              multiValues: _multiValues,
                              files: _files,
                              onPickFile: _pickFile,
                              onToggleMulti: _toggleMulti,
                              onSelectSingle: (index, value) => setState(() => _singleValues[index] = value),
                            ),
                      const SizedBox(height: DesignTokens.spaceMd),
                      ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitVerification,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_submitting ? 'Submitting…' : 'Submit verification'),
                        style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
                      ),
                      const SizedBox(height: DesignTokens.spaceXl),
                      Text('Seller packages', style: DesignTokens.textBodyBold),
                      const SizedBox(height: DesignTokens.spaceSm),
                      _packages.isEmpty
                          ? Text('No packages available.', style: DesignTokens.textSmall)
                          : Column(
                              children: _packages
                                  .map((p) => _PackageCard(
                                        pack: p,
                                        currentPackage: (_shop['seller_package'] ?? '').toString(),
                                        onSelect: () => _selectPackage(p),
                                      ))
                                  .toList(),
                            ),
                      const SizedBox(height: DesignTokens.spaceLg),
                    ],
                  ),
                ),
    );
  }
}

class _VerifyField {
  const _VerifyField({required this.type, required this.label, required this.options});

  final String type;
  final String label;
  final List<String> options;

  factory _VerifyField.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const _VerifyField(type: 'text', label: 'Field', options: <String>[]);
    }

    final type = (json['type'] ?? 'text').toString();
    final label = (json['label'] ?? 'Field').toString();
    final optionsRaw = json['options'];
    final options = <String>[];

    if (optionsRaw is String && optionsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(optionsRaw);
        if (decoded is List) {
          options.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {
        // Ignore invalid option encoding.
      }
    } else if (optionsRaw is List) {
      options.addAll(optionsRaw.map((e) => e.toString()));
    }

    return _VerifyField(type: type, label: label, options: options);
  }
}

class _SellerPackage {
  const _SellerPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.amountLabel,
    required this.durationDays,
    required this.productUploadLimit,
    required this.logoUrl,
  });

  final int id;
  final String name;
  final double price;
  final String amountLabel;
  final int durationDays;
  final int productUploadLimit;
  final String logoUrl;

  factory _SellerPackage.fromJson(Map<String, dynamic> json) {
    return _SellerPackage(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      price: _asDouble(json['price']),
      amountLabel: (json['amount'] ?? '').toString(),
      durationDays: _asInt(json['duration']),
      productUploadLimit: _asInt(json['product_upload_limit']),
      logoUrl: (json['logo'] ?? '').toString(),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verified, required this.submitted});

  final bool verified;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final statusText = verified
        ? 'VERIFIED'
        : submitted
            ? 'SUBMITTED'
            : 'NOT SUBMITTED';
    final statusColor = verified
        ? DesignTokens.success
        : submitted
            ? DesignTokens.warning
            : DesignTokens.error;

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        gradient: DesignTokens.brandGradient,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            padding: DesignTokens.paddingSm,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite.withOpacity(0.18),
              borderRadius: DesignTokens.borderRadiusSm,
            ),
            child: const Icon(Icons.verified_user, color: DesignTokens.surfaceWhite),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification', style: DesignTokens.textTitleLight),
                const SizedBox(height: DesignTokens.spaceXxs),
                Text(
                  verified
                      ? 'Your shop is verified.'
                      : submitted
                          ? 'Your verification is under review.'
                          : 'Submit your documents to unlock payouts and higher limits.',
                  style: DesignTokens.textSmallLight,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spaceSm,
              vertical: DesignTokens.spaceXxs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.18),
              borderRadius: DesignTokens.borderRadiusSm,
            ),
            child: Text(
              statusText,
              style: DesignTokens.textSmallLight.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.fields,
    required this.textControllers,
    required this.singleValues,
    required this.multiValues,
    required this.files,
    required this.onPickFile,
    required this.onToggleMulti,
    required this.onSelectSingle,
  });

  final List<_VerifyField> fields;
  final Map<int, TextEditingController> textControllers;
  final Map<int, String?> singleValues;
  final Map<int, List<String>> multiValues;
  final Map<int, PlatformFile?> files;
  final Future<void> Function(int index) onPickFile;
  final void Function(int index, String value) onToggleMulti;
  final void Function(int index, String? value) onSelectSingle;

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
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            _FieldWidget(
              index: i,
              field: fields[i],
              controller: textControllers[i],
              singleValue: singleValues[i],
              multiValue: multiValues[i] ?? const <String>[],
              file: files[i],
              onPickFile: () => onPickFile(i),
              onToggleMulti: (v) => onToggleMulti(i, v),
              onSelectSingle: (v) => onSelectSingle(i, v),
            ),
            if (i != fields.length - 1) const SizedBox(height: DesignTokens.spaceMd),
          ],
        ],
      ),
    );
  }
}

class _FieldWidget extends StatelessWidget {
  const _FieldWidget({
    required this.index,
    required this.field,
    required this.controller,
    required this.singleValue,
    required this.multiValue,
    required this.file,
    required this.onPickFile,
    required this.onToggleMulti,
    required this.onSelectSingle,
  });

  final int index;
  final _VerifyField field;
  final TextEditingController? controller;
  final String? singleValue;
  final List<String> multiValue;
  final PlatformFile? file;
  final VoidCallback onPickFile;
  final ValueChanged<String> onToggleMulti;
  final ValueChanged<String?> onSelectSingle;

  @override
  Widget build(BuildContext context) {
    final label = field.label;
    switch (field.type) {
      case 'file':
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file),
          title: Text(label, style: DesignTokens.textBodyBold),
          subtitle: Text(file?.name ?? 'Tap to choose file', style: DesignTokens.textSmall),
          trailing: TextButton(onPressed: onPickFile, child: const Text('Choose')),
        );
      case 'multi_select':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: field.options
                  .map((opt) => FilterChip(
                        label: Text(opt),
                        selected: multiValue.contains(opt),
                        onSelected: (_) => onToggleMulti(opt),
                      ))
                  .toList(),
            ),
          ],
        );
      case 'select':
      case 'radio':
        return DropdownButtonFormField<String>(
          value: singleValue,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.list_alt_outlined),
          ),
          items: field.options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
              .toList(),
          onChanged: onSelectSingle,
        );
      case 'text':
      default:
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.edit_outlined),
          ),
        );
    }
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pack, required this.currentPackage, required this.onSelect});

  final _SellerPackage pack;
  final String currentPackage;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentPackage.trim().isNotEmpty && currentPackage == pack.name;
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
        border: isCurrent ? Border.all(color: DesignTokens.brandAccent) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(pack.name, style: DesignTokens.textBodyBold)),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceSm,
                    vertical: DesignTokens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.brandAccent.withOpacity(0.12),
                    borderRadius: DesignTokens.borderRadiusSm,
                  ),
                  child: Text('Current', style: DesignTokens.textSmall.copyWith(color: DesignTokens.brandAccent)),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            pack.amountLabel.isNotEmpty ? pack.amountLabel : 'UGX ${pack.price.toStringAsFixed(0)}',
            style: DesignTokens.textBody.copyWith(color: DesignTokens.brandAccent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text('Duration: ${pack.durationDays} days', style: DesignTokens.textSmall),
          Text('Upload limit: ${pack.productUploadLimit}', style: DesignTokens.textSmall),
          const SizedBox(height: DesignTokens.spaceMd),
          ElevatedButton(
            onPressed: onSelect,
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
            child: Text(pack.price <= 0 ? 'Select' : 'Pay offline'),
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
  final Future<void> Function() onRetry;

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
              onPressed: () => onRetry(),
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

List<dynamic> _unwrapList(dynamic body) {
  if (body is List) return body;
  if (body is Map<String, dynamic>) {
    final data = body['data'];
    if (data is List) return data;
    // Some endpoints return raw arrays under other keys.
    for (final v in body.values) {
      if (v is List) return v;
    }
  }
  return const <dynamic>[];
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase().trim();
  return s == '1' || s == 'true' || s == 'yes';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String? _extractMessage(dynamic body) {
  if (body is Map<String, dynamic>) {
    final message = body['message'] ?? body['msg'] ?? body['error'];
    if (message != null) return message.toString();
    final data = body['data'];
    if (data is String) return data;
  }
  return null;
}
