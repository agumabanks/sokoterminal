import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/firebase/remote_config_service.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../core/util/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../bnpl/models/bnpl_seller_status.dart';
import '../bnpl/models/product_bnpl_payload.dart';
import '../bnpl/providers/bnpl_seller_status_provider.dart';
import '../bnpl/providers/product_bnpl_provider.dart';
import '../../widgets/html_editor.dart';
import '../../widgets/offline_cached_image.dart';
import 'product_photo_editor.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../delivery/selling_coverage_card.dart';
import '../delivery/coverage_rules.dart';
import 'product_form_controller.dart';
import 'wholesale_pricing.dart';
import 'product_variants_screen.dart';

/// Smooth single-scroll product creation & editing screen.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({
    super.key,
    this.existingItem,
    this.startPublishOnline = false,
  });
  final Item? existingItem;
  final bool startPublishOnline;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen>
    with SingleTickerProviderStateMixin {
  static const _uuid = Uuid();
  int _onboardingStep = 0;
  bool _hydratingRemote = false;
  bool _hydratedRemote = false;

  var _scrollController = ScrollController();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _wholesaleEnabled = false;
  List<Map<String, dynamic>> _wholesaleRanges = [];
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _minQtyCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _shippingDaysCtrl = TextEditingController();
  final _shippingFeeCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _bnplMinCtrl = TextEditingController();
  final _bnplMaxCtrl = TextEditingController();
  final _bnplInstallmentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingItem == null) _stockCtrl.text = '0';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final controller = ref.read(productFormProvider.notifier);
        if (widget.existingItem == null && await controller.restoreDraft()) {
          if (!mounted) return;
          final draft = ref.read(productFormProvider);
          _applyDraftControllers(draft);
          if (draft.publishOnline) unawaited(controller.setPublishOnline(true));
        }
        _populateFromExisting();
        unawaited(_hydrateFromServerIfNeeded());
        unawaited(_loadBnplSettingsIfNeeded());
        await ref.read(productFormProvider.notifier).loadBusinessTaxSettings();
        final profile = await ref
            .read(appDatabaseProvider)
            .getBusinessProfile();
        if (profile?.deliveryProfileJson != null) {
          final settings = jsonDecode(profile!.deliveryProfileJson!) as Map;
          _shopCoverage = settings['selling_coverage'] == null
              ? null
              : Map<String, dynamic>.from(settings['selling_coverage'] as Map);
        }
        if (!mounted) return;
        final state = ref.read(productFormProvider);
        if (state.taxRate.isNotEmpty) {
          _taxRateCtrl.text = state.taxRate;
        }
        if (widget.startPublishOnline) {
          unawaited(
            ref.read(productFormProvider.notifier).setPublishOnline(true),
          );
        }
      } catch (e, st) {
        debugPrint('[AddProductScreen] initState error: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading product form: $e')),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _discountCtrl.dispose();
    _skuCtrl.dispose();
    _minQtyCtrl.dispose();
    _lowStockCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    _shippingDaysCtrl.dispose();
    _shippingFeeCtrl.dispose();
    _taxRateCtrl.dispose();
    _bnplMinCtrl.dispose();
    _bnplMaxCtrl.dispose();
    _bnplInstallmentCtrl.dispose();
    super.dispose();
  }

  // ─── Populate from existing item ──────────────────────────────────────────

  void _populateFromExisting() {
    final item = widget.existingItem;
    if (item == null) return;
    final ctrl = ref.read(productFormProvider.notifier);
    _wholesaleRanges = wholesaleRanges(item.wholesaleRangesJson);
    _wholesaleEnabled = _wholesaleRanges.isNotEmpty;
    ctrl.setName(item.name);
    _nameCtrl.text = item.name;
    if (item.categoryId != null) {
      ctrl.setCategory(item.categoryId, item.categoryName);
    }
    if (item.brandId != null) ctrl.setBrand(item.brandId, item.brandName);
    ctrl.setUnit(item.unit ?? 'pc');
    _weightCtrl.text = item.weight?.toString() ?? '';
    ctrl.setWeight(_weightCtrl.text);
    _priceCtrl.text = CommaNumberFormatter.format(
      item.price.toStringAsFixed(0),
    );
    ctrl.setPrice(_priceCtrl.text);
    _costCtrl.text = item.cost != null
        ? CommaNumberFormatter.format(item.cost!.toStringAsFixed(0))
        : '';
    ctrl.setCost(_costCtrl.text);
    ctrl.setCostUnknown(item.cost == null);
    ctrl.setSellingCoverage(
      item.sellingCoverageJson == null
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(item.sellingCoverageJson!) as Map,
            ),
    );
    _stockCtrl.text = CommaNumberFormatter.format(item.stockQty.toString());
    ctrl.setStock(_stockCtrl.text);
    _discountCtrl.text = item.discount != null
        ? CommaNumberFormatter.format(item.discount!.toStringAsFixed(0))
        : '';
    ctrl.setDiscount(_discountCtrl.text);
    ctrl.setDiscountType(item.discountType ?? 'flat');
    _skuCtrl.text = item.sku ?? '';
    ctrl.setSku(_skuCtrl.text);
    _minQtyCtrl.text = CommaNumberFormatter.format(
      item.minPurchaseQty.toString(),
    );
    ctrl.setMinQty(_minQtyCtrl.text);
    _lowStockCtrl.text = item.lowStockWarning != null
        ? CommaNumberFormatter.format(item.lowStockWarning!.toString())
        : '';
    ctrl.setLowStockWarning(_lowStockCtrl.text);
    _descriptionCtrl.text = item.description ?? '';
    ctrl.setDescription(_descriptionCtrl.text);
    _tagsCtrl.text = item.tags ?? '';
    ctrl.setTags(_tagsCtrl.text);
    _shippingDaysCtrl.text = item.shippingDays != null
        ? CommaNumberFormatter.format(item.shippingDays!.toString())
        : '';
    ctrl.setShippingDays(_shippingDaysCtrl.text);
    _shippingFeeCtrl.text = item.shippingFee != null
        ? CommaNumberFormatter.format(item.shippingFee!.toStringAsFixed(0))
        : '';
    ctrl.setShippingFee(_shippingFeeCtrl.text);
    ctrl.setRefundable(item.refundable);
    ctrl.setCashOnDelivery(item.cashOnDelivery);
    if (item.taxRate != null && item.taxRate! > 0) {
      _taxRateCtrl.text = CommaNumberFormatter.format(
        item.taxRate!.toStringAsFixed(0),
      );
      ctrl.setTaxRate(_taxRateCtrl.text);
    }
    if (item.publishedOnline) unawaited(ctrl.setPublishOnline(true));

    // Images
    final thumbRaw = (item.thumbnailUrl ?? item.imageUrl)?.trim();
    final galleryUrlsAll = _decodeStringList(item.galleryUrls);
    final galleryIdsAll = _decodeIntList(item.galleryUploadIds);
    final remoteGalleryUrls = <String>[];
    final validGalleryIds = <int>[];
    final pendingGalleryFiles = <File>[];
    for (var i = 0; i < galleryUrlsAll.length; i++) {
      final id = i < galleryIdsAll.length ? galleryIdsAll[i] : 0;
      if (id > 0) {
        remoteGalleryUrls.add(galleryUrlsAll[i]);
        validGalleryIds.add(id);
      } else if (!galleryUrlsAll[i].startsWith('http')) {
        pendingGalleryFiles.add(File(galleryUrlsAll[i]));
      }
    }

    File? pendingThumbnailFile;
    String? remoteThumbnailUrl = thumbRaw;
    int? remoteThumbnailId = item.thumbnailUploadId;
    if (thumbRaw != null &&
        thumbRaw.isNotEmpty &&
        !thumbRaw.startsWith('http')) {
      final f = File(thumbRaw);
      if (f.existsSync()) {
        pendingThumbnailFile = f;
        remoteThumbnailUrl = null;
        remoteThumbnailId = null;
      }
    }

    ctrl.setExistingImages(
      thumbnailUrl: remoteThumbnailUrl,
      thumbnailUploadId: remoteThumbnailId,
      galleryUrls: remoteGalleryUrls,
      galleryUploadIds: validGalleryIds,
      orderedPaths: galleryUrlsAll,
      pendingGalleryFiles: pendingGalleryFiles,
      pendingThumbnailFile: pendingThumbnailFile,
    );
  }

  // ─── Hydrate from server ───────────────────────────────────────────────────

  Future<void> _hydrateFromServerIfNeeded() async {
    final item = widget.existingItem;
    if (item == null || _hydratedRemote || _hydratingRemote) return;

    final productId = item.remoteId ?? int.tryParse(item.id);
    if (productId == null) return;

    final needsHydration =
        item.categoryId == null ||
        item.brandId == null ||
        item.unit == null ||
        item.description == null ||
        item.tags == null ||
        item.barcode == null;
    if (!needsHydration) {
      _hydratedRemote = true;
      return;
    }

    setState(() => _hydratingRemote = true);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchProductDetails(productId);
      if (!mounted) return;
      if (res.data is! Map) return;

      final data = Map<String, dynamic>.from(res.data as Map);
      final ctrl = ref.read(productFormProvider.notifier);
      final db = ref.read(appDatabaseProvider);

      final name = data['product_name']?.toString() ?? data['name']?.toString();
      final unit = data['product_unit']?.toString() ?? data['unit']?.toString();
      final description = data['description']?.toString();
      final tags = data['tags']?.toString();
      final categoryId = data['category_id']?.toString();
      final brandId = data['brand_id']?.toString();

      final unitPrice = double.tryParse(data['unit_price']?.toString() ?? '');
      final stock = int.tryParse(data['current_stock']?.toString() ?? '');
      final weight = double.tryParse(data['weight']?.toString() ?? '');
      final minQty = int.tryParse(data['min_qty']?.toString() ?? '');
      final lowStock = int.tryParse(
        data['low_stock_quantity']?.toString() ?? '',
      );
      final discount = double.tryParse(data['discount']?.toString() ?? '');
      final shippingCost = double.tryParse(
        data['shipping_cost']?.toString() ?? '',
      );
      final estShippingDays = int.tryParse(
        data['est_shipping_days']?.toString() ?? '',
      );
      final refundable = data['refundable'] == true || data['refundable'] == 1;
      final cashOnDelivery =
          data['cash_on_delivery'] == true || data['cash_on_delivery'] == 1;
      final published = data['published'] == true || data['published'] == 1;
      final barcode = data['barcode']?.toString();

      final rawDiscountType = data['discount_type']?.toString();
      final localDiscountType = rawDiscountType == null
          ? null
          : (rawDiscountType == 'amount' ? 'flat' : rawDiscountType);

      unawaited(
        db.updateItemFields(
          item.id,
          ItemsCompanion(
            remoteId: Value(productId),
            categoryId: categoryId != null
                ? Value(categoryId)
                : const Value.absent(),
            brandId: brandId != null ? Value(brandId) : const Value.absent(),
            unit: unit != null ? Value(unit) : const Value.absent(),
            weight: weight != null ? Value(weight) : const Value.absent(),
            minPurchaseQty: minQty != null
                ? Value(minQty)
                : const Value.absent(),
            lowStockWarning: lowStock != null
                ? Value(lowStock)
                : const Value.absent(),
            discount: discount != null ? Value(discount) : const Value.absent(),
            discountType: localDiscountType != null
                ? Value(localDiscountType)
                : const Value.absent(),
            shippingFee: shippingCost != null
                ? Value(shippingCost)
                : const Value.absent(),
            shippingDays: estShippingDays != null
                ? Value(estShippingDays)
                : const Value.absent(),
            refundable: Value(refundable),
            cashOnDelivery: Value(cashOnDelivery),
            barcode: barcode != null ? Value(barcode) : const Value.absent(),
            tags: tags != null ? Value(tags) : const Value.absent(),
            description: description != null
                ? Value(description)
                : const Value.absent(),
          ),
        ),
      );

      if (name != null && name.trim().isNotEmpty) {
        _nameCtrl.text = name;
        ctrl.setName(name);
      }
      if (unit != null && unit.trim().isNotEmpty) ctrl.setUnit(unit);
      if (categoryId != null) ctrl.setCategory(categoryId, null);
      if (brandId != null) ctrl.setBrand(brandId, null);
      if (description != null) {
        _descriptionCtrl.text = description;
        ctrl.setDescription(description);
      }
      if (tags != null) {
        _tagsCtrl.text = tags;
        ctrl.setTags(tags);
      }
      if (unitPrice != null) {
        _priceCtrl.text = CommaNumberFormatter.format(
          unitPrice.toStringAsFixed(0),
        );
        ctrl.setPrice(_priceCtrl.text);
      }
      if (stock != null) {
        _stockCtrl.text = CommaNumberFormatter.format(stock.toString());
        ctrl.setStock(_stockCtrl.text);
      }
      if (weight != null) {
        _weightCtrl.text = weight.toString();
        ctrl.setWeight(_weightCtrl.text);
      }
      if (minQty != null) {
        _minQtyCtrl.text = CommaNumberFormatter.format(minQty.toString());
        ctrl.setMinQty(_minQtyCtrl.text);
      }
      if (lowStock != null) {
        _lowStockCtrl.text = CommaNumberFormatter.format(lowStock.toString());
        ctrl.setLowStockWarning(_lowStockCtrl.text);
      }
      if (discount != null) {
        _discountCtrl.text = CommaNumberFormatter.format(
          discount.toStringAsFixed(0),
        );
        ctrl.setDiscount(_discountCtrl.text);
      }
      if (localDiscountType != null) ctrl.setDiscountType(localDiscountType);
      if (shippingCost != null) {
        _shippingFeeCtrl.text = CommaNumberFormatter.format(
          shippingCost.toStringAsFixed(0),
        );
        ctrl.setShippingFee(_shippingFeeCtrl.text);
      }
      if (estShippingDays != null) {
        _shippingDaysCtrl.text = CommaNumberFormatter.format(
          estShippingDays.toString(),
        );
        ctrl.setShippingDays(_shippingDaysCtrl.text);
      }
      ctrl.setRefundable(refundable);
      ctrl.setCashOnDelivery(cashOnDelivery);
      if (published && !ref.read(productFormProvider).publishOnline) {
        await ctrl.setPublishOnline(true);
      }
      _hydratedRemote = true;
    } catch (_) {
      // Best effort — offline / unauthorized
    } finally {
      if (mounted) setState(() => _hydratingRemote = false);
    }
  }

  // ─── BNPL settings from server ─────────────────────────────────────────────

  Future<void> _loadBnplSettingsIfNeeded() async {
    final productId = widget.existingItem?.remoteId;
    if (productId == null) return;

    try {
      final payload = await ref.read(productBnplProvider(productId).future);
      if (payload == null || !mounted) return;

      final ctrl = ref.read(productFormProvider.notifier);
      ctrl.setBnplEnabled(payload.enabled);

      _bnplMinCtrl.text = payload.minOrderAmount != null
          ? CommaNumberFormatter.format(
              payload.minOrderAmount!.toStringAsFixed(0),
            )
          : '';
      _bnplMaxCtrl.text = payload.maxOrderAmount != null
          ? CommaNumberFormatter.format(
              payload.maxOrderAmount!.toStringAsFixed(0),
            )
          : '';
      _bnplInstallmentCtrl.text = payload.installmentCount != null
          ? payload.installmentCount.toString()
          : '';

      ctrl.setBnplMinOrderAmount(_bnplMinCtrl.text);
      ctrl.setBnplMaxOrderAmount(_bnplMaxCtrl.text);
      ctrl.setBnplInstallmentCount(_bnplInstallmentCtrl.text);
    } catch (_) {
      // Best effort — backend may not have the endpoint yet.
    }
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  bool _isSaving = false;

  Future<void> _saveProduct({bool asDraft = false}) async {
    if (_isSaving) return;
    final wholesaleError = _wholesaleEnabled
        ? validateWholesaleRanges(_wholesaleRanges)
        : null;
    if (wholesaleError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(wholesaleError)));
      return;
    }
    _isSaving = true;

    final state = asDraft
        ? ref.read(productFormProvider).copyWith(publishOnline: false)
        : ref.read(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);
    debugPrint(
      '[AddProductScreen] save pressed. canSubmit=${state.canSubmit}, '
      'basic=${state.isBasicInfoValid}, category=${state.isCategoryValid}, '
      'pricing=${state.isPricingValid}, discount=${state.isDiscountValid}, '
      'extras=${state.isExtrasValid}, online=${state.isOnlineDetailsValid}, '
      'images=${state.isImagesValid}',
    );
    if (!state.canSubmit) {
      _isSaving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _getValidationHint(state) ??
                  'Please complete all required fields',
            ),
            backgroundColor: DesignTokens.warning,
          ),
        );
      }
      return;
    }

    String finalSku = state.sku.trim();
    if (finalSku.isEmpty) {
      await ctrl.autoGenerateSKU();
      finalSku = ref.read(productFormProvider).sku;
    } else {
      final skuError = await ctrl.validateSKU(
        editingItemId: widget.existingItem?.id,
      );
      if (skuError != null && mounted) {
        _isSaving = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(skuError),
            backgroundColor: DesignTokens.error,
            action: SnackBarAction(
              label: 'Auto-fix',
              textColor: Colors.white,
              onPressed: () async => ctrl.autoGenerateSKU(),
            ),
          ),
        );
        return;
      }
    }

    ctrl.setSubmitting(true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final id = widget.existingItem?.id ?? _uuid.v4();
      final existing = widget.existingItem;

      final thumbPathOrUrl = state.thumbnailFile?.path ?? state.thumbnailUrl;
      final thumbUploadId = state.thumbnailFile != null
          ? null
          : state.thumbnailUploadId;

      final combinedGalleryUrls = state.orderedGallery;
      final alignedGalleryIds = combinedGalleryUrls.map((path) {
        final index = state.galleryUrls.indexOf(path);
        return index >= 0 && index < state.galleryUploadIds.length
            ? state.galleryUploadIds[index]
            : 0;
      }).toList();

      final existingGalleryUrls = _decodeStringList(existing?.galleryUrls);
      final existingGalleryIds = _decodeIntList(existing?.galleryUploadIds);
      final existingRemoteCount =
          existingGalleryIds.length < existingGalleryUrls.length
          ? existingGalleryIds.length
          : existingGalleryUrls.length;
      final existingHasGallery =
          existingRemoteCount > 0 ||
          existingGalleryUrls.skip(existingRemoteCount).isNotEmpty;
      final currentHasGallery = combinedGalleryUrls.isNotEmpty;
      final shouldClearGallery = existingHasGallery && !currentHasGallery;

      final companion = ItemsCompanion(
        id: Value(id),
        name: Value(state.name.trim()),
        wholesaleRangesJson: Value(
          jsonEncode(_wholesaleEnabled ? _wholesaleRanges : []),
        ),
        price: Value(
          double.tryParse(CommaNumberFormatter.unformat(state.price)) ?? 0,
        ),
        sellingCoverageJson: Value(
          state.sellingCoverage == null
              ? null
              : jsonEncode(state.sellingCoverage),
        ),
        cost: Value(double.tryParse(CommaNumberFormatter.unformat(state.cost))),
        stockQty: Value(
          int.tryParse(CommaNumberFormatter.unformat(state.stock)) ?? 0,
        ),
        sku: Value(finalSku.isNotEmpty ? finalSku : null),
        imageUrl: Value(thumbPathOrUrl),
        publishedOnline: Value(state.publishOnline),
        categoryId: Value(state.categoryId),
        categoryName: Value(state.categoryName),
        brandId: Value(state.brandId),
        brandName: Value(state.brandName),
        unit: Value(state.unit),
        weight: Value(
          double.tryParse(CommaNumberFormatter.unformat(state.weight)),
        ),
        minPurchaseQty: Value(int.tryParse(state.minQty) ?? 1),
        tags: Value(state.tags.isNotEmpty ? state.tags : null),
        description: Value(
          state.description.isNotEmpty ? state.description : null,
        ),
        thumbnailUrl: Value(thumbPathOrUrl),
        thumbnailUploadId: Value(thumbUploadId),
        galleryUrls: currentHasGallery || shouldClearGallery
            ? Value(
                jsonEncode(
                  currentHasGallery ? combinedGalleryUrls : const <String>[],
                ),
              )
            : const Value.absent(),
        galleryUploadIds: currentHasGallery || shouldClearGallery
            ? Value(
                jsonEncode(
                  currentHasGallery ? alignedGalleryIds : const <int>[],
                ),
              )
            : const Value.absent(),
        discount: Value(
          double.tryParse(CommaNumberFormatter.unformat(state.discount)),
        ),
        discountType: Value(state.discountType),
        shippingDays: Value(
          int.tryParse(CommaNumberFormatter.unformat(state.shippingDays)),
        ),
        shippingFee: Value(
          double.tryParse(CommaNumberFormatter.unformat(state.shippingFee)),
        ),
        refundable: Value(state.refundable),
        cashOnDelivery: Value(state.cashOnDelivery),
        lowStockWarning: Value(
          int.tryParse(CommaNumberFormatter.unformat(state.lowStockWarning)),
        ),
        taxRate: state.taxRate.isNotEmpty
            ? Value(
                double.tryParse(CommaNumberFormatter.unformat(state.taxRate)),
              )
            : const Value.absent(),
        synced: const Value(false),
      );

      final opType = widget.existingItem == null
          ? 'item_create'
          : 'item_update';
      final catId = int.tryParse(state.categoryId ?? '');

      try {
        await db.saveItemAndEnqueueSync(
          item: companion,
          opType: opType,
          syncPayload: {
            'local_id': id,
            'selling_coverage': state.sellingCoverage,
            'media_contract_version': 2,
            if (widget.existingItem?.remoteId != null)
              'remote_id': widget.existingItem!.remoteId,
            'name': state.name.trim(),
            'unit_price':
                double.tryParse(CommaNumberFormatter.unformat(state.price)) ??
                0,
            'current_stock':
                int.tryParse(CommaNumberFormatter.unformat(state.stock)) ?? 0,
            'published': state.publishOnline ? 1 : 0,
            if (catId != null) 'category_ids': [catId],
            if (catId != null) 'category_id': catId,
            if (state.brandId != null) 'brand_id': int.tryParse(state.brandId!),
            'unit': state.unit.isNotEmpty ? state.unit : 'pc',
            if (state.weight.isNotEmpty)
              'weight': double.tryParse(
                CommaNumberFormatter.unformat(state.weight),
              ),
            'min_qty':
                int.tryParse(CommaNumberFormatter.unformat(state.minQty)) ?? 1,
            if (state.tags.isNotEmpty)
              'tags': state.tags
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            if (state.description.isNotEmpty) 'description': state.description,
            'discount':
                double.tryParse(
                  CommaNumberFormatter.unformat(state.discount),
                ) ??
                0,
            'discount_type': state.discountType == 'flat'
                ? 'amount'
                : 'percent',
            if (state.shippingDays.isNotEmpty)
              'est_shipping_days': int.tryParse(
                CommaNumberFormatter.unformat(state.shippingDays),
              ),
            if (state.shippingFee.isNotEmpty)
              'shipping_cost': double.tryParse(
                CommaNumberFormatter.unformat(state.shippingFee),
              ),
            'refundable': state.refundable ? 1 : 0,
            'cash_on_delivery': state.cashOnDelivery ? 1 : 0,
            if (state.lowStockWarning.isNotEmpty)
              'low_stock_quantity': int.tryParse(
                CommaNumberFormatter.unformat(state.lowStockWarning),
              ),
            if (state.taxRate.isNotEmpty)
              'tax_rate': double.tryParse(
                CommaNumberFormatter.unformat(state.taxRate),
              ),
            if (finalSku.isNotEmpty) 'sku': finalSku,
            'purchase_price': double.tryParse(
              CommaNumberFormatter.unformat(state.cost),
            ),
          },
        );
        unawaited(sync.syncCatalogImmediately());

        // Push BNPL settings to the server when editing an already-synced item.
        final remoteId = widget.existingItem?.remoteId;
        if (remoteId != null) {
          try {
            final bnplPayload = ProductBnplPayload(
              enabled: state.bnplEnabled,
              minOrderAmount: state.bnplMinOrderAmount.isEmpty
                  ? null
                  : double.tryParse(
                      CommaNumberFormatter.unformat(state.bnplMinOrderAmount),
                    ),
              maxOrderAmount: state.bnplMaxOrderAmount.isEmpty
                  ? null
                  : double.tryParse(
                      CommaNumberFormatter.unformat(state.bnplMaxOrderAmount),
                    ),
              installmentCount: state.bnplInstallmentCount.isEmpty
                  ? null
                  : int.tryParse(
                      CommaNumberFormatter.unformat(state.bnplInstallmentCount),
                    ),
            );
            await ref
                .read(sellerApiProvider)
                .updateProductBnpl(remoteId, bnplPayload);
          } catch (e) {
            debugPrint('[AddProductScreen] BNPL update failed: $e');
          }
        }
      } catch (e) {
        _isSaving = false;
        ctrl.setSubmitting(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: DesignTokens.error,
            ),
          );
        }
        return;
      }

      debugPrint(
        '[AddProductScreen] product saved: id=$id, name=${state.name.trim()}',
      );
      if (mounted) {
        await ctrl.discardDraft();
        if (!mounted) return;
        ctrl.reset();
        Navigator.pop(context, true);
        final message = state.publishOnline
            ? 'Saved — syncing to your online shop…'
            : 'Saved on this device';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DesignTokens.brandAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _isSaving = false;
      ref.read(productFormProvider.notifier).setSubmitting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);
    final bnplStatusAsync = ref.watch(bnplSellerStatusProvider);

    if (widget.existingItem == null) {
      return _buildOnboarding(state, ctrl);
    }

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: _buildAppBar(state),
      body: CustomScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Start with a name, price and stock. Add photos and online details when you are ready.',
                  ),
                ),
                // 3. Product info
                _buildFormSection(
                  icon: Icons.inventory_2_outlined,
                  title: '1. Product name',
                  child: _buildProductInfoFields(state, ctrl),
                ),
                const SizedBox(height: 8),

                // 4. Pricing & stock
                _buildFormSection(
                  icon: Icons.payments_outlined,
                  title: '2. Price & stock',
                  child: _buildPricingFields(state, ctrl),
                ),
                const SizedBox(height: 8),

                WholesaleEditor(
                  enabled: _wholesaleEnabled,
                  ranges: _wholesaleRanges,
                  onToggle: (v) => setState(() {
                    _wholesaleEnabled = v;
                    if (v && _wholesaleRanges.isEmpty) _wholesaleRanges.add({});
                  }),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  initiallyExpanded: widget.existingItem != null,
                  childrenPadding: const EdgeInsets.all(16),
                  title: const Text('Photos & online shop'),
                  subtitle: Text(
                    state.galleryCount > 0
                        ? 'Cover + ${state.galleryCount} gallery photos'
                        : 'Add a cover photo or more product photos',
                  ),
                  children: [
                    _buildPhotoSection(state, ctrl),
                    _buildMarketplaceCard(state, ctrl),
                  ],
                ),
                // 5. Marketplace details (only when publishing online)
                if (state.publishOnline) ...[
                  _buildFormSection(
                    icon: Icons.public_outlined,
                    title: 'Marketplace Details',
                    subtitle: 'Required for your online listing',
                    child: _buildMarketplaceFields(state, ctrl),
                  ),
                  const SizedBox(height: 8),
                ],

                // BNPL settings
                _buildFormSection(
                  icon: Icons.payments_outlined,
                  title: 'Sanaa Finance BNPL',
                  subtitle: 'Let buyers pay later',
                  child: _buildBnplSection(
                    state,
                    ctrl,
                    bnplStatusAsync.valueOrNull,
                  ),
                ),
                const SizedBox(height: 8),

                // 6. Variants (editing only, feature-flagged)
                if (widget.existingItem != null &&
                    ref.read(remoteConfigProvider).ffProductVariantsEditor) ...[
                  _buildVariantsSection(widget.existingItem!),
                  const SizedBox(height: 8),
                ],

                // Error from permission denial
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: _buildErrorBanner(state.error!),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(state),
    );
  }

  Map<String, dynamic>? _shopCoverage;
  void _applyDraftControllers(ProductFormState state) {
    _nameCtrl.text = state.name;
    _priceCtrl.text = state.price;
    _costCtrl.text = state.cost;
    _stockCtrl.text = state.stock;
    _weightCtrl.text = state.weight;
    _discountCtrl.text = state.discount;
    _skuCtrl.text = state.sku;
    _minQtyCtrl.text = state.minQty;
    _lowStockCtrl.text = state.lowStockWarning;
    _descriptionCtrl.text = state.description;
    _tagsCtrl.text = state.tags;
    _shippingDaysCtrl.text = state.shippingDays;
    _shippingFeeCtrl.text = state.shippingFee;
    _taxRateCtrl.text = state.taxRate;
    _bnplMinCtrl.text = state.bnplMinOrderAmount;
    _bnplMaxCtrl.text = state.bnplMaxOrderAmount;
    _bnplInstallmentCtrl.text = state.bnplInstallmentCount;
  }

  Future<void> _startFreshProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a fresh product?'),
        content: const Text(
          'This removes the unfinished details on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start fresh'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ctrl = ref.read(productFormProvider.notifier);
    await ctrl.discardDraft();
    ctrl.reset();
    await ctrl.restoreDraft();
    if (!mounted) return;
    _applyDraftControllers(ref.read(productFormProvider));
    _goToOnboardingStep(0);
  }

  Future<File> _photoFile(String path, ProductFormController ctrl) async {
    if (!path.startsWith('http')) return File(path);
    final response = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ).get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
    final temporary = File(
      '${(await getTemporaryDirectory()).path}/product-edit-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await temporary.writeAsBytes(response.data!);
    return ctrl.keepOriginal(temporary);
  }

  Future<void> _editCoverPhoto(
    ProductFormState state,
    ProductFormController ctrl,
  ) async {
    try {
      final file = await _photoFile(
        state.thumbnailFile?.path ?? state.thumbnailUrl!,
        ctrl,
      );
      if (!mounted) return;
      final edited = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => ProductPhotoEditor(source: file)),
      );
      if (edited != null && mounted) ctrl.setEditedCover(edited);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the photo. Connect to the internet and try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editGalleryPhoto(
    String path,
    ProductFormController ctrl,
  ) async {
    try {
      final file = await _photoFile(path, ctrl);
      if (!mounted) return;
      final edited = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => ProductPhotoEditor(source: file)),
      );
      if (edited != null && mounted) ctrl.replaceGalleryPhoto(path, edited);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this photo. Try again when connected.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _replaceGalleryPhoto(
    String path,
    ProductFormController ctrl,
  ) async => ctrl.replaceGalleryFromPicker(path);

  void _goToOnboardingStep(int step) {
    FocusScope.of(context).unfocus();
    final previous = _scrollController;
    setState(() {
      _onboardingStep = step;
      _scrollController = ScrollController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  Widget _buildOnboarding(ProductFormState state, ProductFormController ctrl) {
    final online = state.publishOnline;
    final titles = [
      'Where will you sell?',
      'Add your product',
      online ? 'Get ready for online buyers' : 'Ready to add',
    ];
    final basicReady = state.isBasicInfoValid && state.isPricingValid;
    final hint = _onboardingStep == 1
        ? (!state.isBasicInfoValid
              ? 'Enter a product name'
              : !state.isPricingValid
              ? (!state.costUnknown && state.costValue == null
                    ? 'Enter a buying price, or choose “I don’t know”'
                    : 'Enter a selling price and a quantity of 0 or more')
              : null)
        : _onboardingStep == 2
        ? _getValidationHint(state)
        : null;
    return PopScope(
      canPop: _onboardingStep == 0 || state.isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !state.isSubmitting) {
          _goToOnboardingStep(_onboardingStep - 1);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff7f8fa),
        appBar: AppBar(
          title: const Text('Add product'),
          actions: [
            IconButton(
              tooltip: 'Start a fresh product',
              icon: const Icon(Icons.restart_alt),
              onPressed: state.isSubmitting ? null : _startFreshProduct,
            ),
          ],
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: state.isSubmitting
                ? null
                : () {
                    if (_onboardingStep > 0) {
                      _goToOnboardingStep(_onboardingStep - 1);
                    } else {
                      Navigator.pop(context);
                    }
                  },
          ),
        ),
        body: ListView(
          key: ValueKey(_onboardingStep),
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Step ${_onboardingStep + 1} of 3',
              style: DesignTokens.textSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_onboardingStep + 1) / 3),
            const SizedBox(height: 20),
            Text(
              titles[_onboardingStep],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _onboardingStep == 0
                  ? 'Choose one. You can change this later.'
                  : _onboardingStep == 1
                  ? 'Add the details you know. You can finish later.'
                  : online
                  ? 'Show buyers the product and how it reaches them.'
                  : 'Check your product, then add it to your till.',
            ),
            const SizedBox(height: 20),
            if (_onboardingStep == 0) ...[
              _sellingChoice(
                state,
                ctrl,
                false,
                Icons.storefront_outlined,
                'In my shop',
                'Add stock and sell at the till. No online listing.',
              ),
              const SizedBox(height: 12),
              _sellingChoice(
                state,
                ctrl,
                true,
                Icons.public,
                'In my shop + online',
                'Sell at the till and list on Soko for online buyers.',
              ),
            ],
            if (_onboardingStep == 1) ...[
              _buildFormSection(
                icon: Icons.inventory_2_outlined,
                title: 'What are you selling?',
                child: _buildProductInfoFields(state, ctrl),
              ),
              const SizedBox(height: 16),
              _buildPhotoSection(state, ctrl),
              const SizedBox(height: 16),
              _buildFormSection(
                icon: Icons.payments_outlined,
                title: 'Price & stock',
                child: _buildPricingFields(state, ctrl),
              ),
              ExpansionTile(
                title: const Text('Wholesale pricing (optional)'),
                children: [
                  WholesaleEditor(
                    enabled: _wholesaleEnabled,
                    ranges: _wholesaleRanges,
                    onToggle: (v) => setState(() {
                      _wholesaleEnabled = v;
                      if (v && _wholesaleRanges.isEmpty) {
                        _wholesaleRanges.add({});
                      }
                    }),
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
            ],
            if (_onboardingStep == 2) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.name, style: DesignTokens.textBodyBold),
                      const SizedBox(height: 8),
                      Text(
                        'UGX ${_priceCtrl.text} · ${_stockCtrl.text} in stock',
                      ),
                      Text(online ? 'In my shop + online' : 'In my shop'),
                      TextButton(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _goToOnboardingStep(1),
                        child: const Text('Edit product details'),
                      ),
                    ],
                  ),
                ),
              ),
              if (online) ...[
                _buildPhotoSection(state, ctrl),
                const SizedBox(height: 16),
                _buildFormSection(
                  icon: Icons.category_outlined,
                  title: 'Help buyers find it',
                  child: Column(
                    children: [
                      _buildCategorySelector(state, ctrl),
                      ExpansionTile(
                        title: const Text('Brand & weight (optional)'),
                        children: [
                          _buildBrandSelector(state, ctrl),
                          AppInput(
                            controller: _weightCtrl,
                            label: 'Weight (kg)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: ctrl.setWeight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildFormSection(
                  icon: Icons.local_shipping_outlined,
                  title: 'Description & delivery',
                  child: _buildMarketplaceFields(state, ctrl),
                ),
                SellingCoverageCard(
                  value: state.sellingCoverage,
                  product: true,
                  shopValue: _shopCoverage,
                  onChanged: ctrl.setSellingCoverage,
                ),
              ] else
                _buildPhotoSection(state, ctrl),
              ExpansionTile(
                title: const Text('Let buyers pay later (optional)'),
                children: [
                  _buildBnplSection(
                    state,
                    ctrl,
                    ref.watch(bnplSellerStatusProvider).valueOrNull,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                online
                    ? 'Saved to your till first. Your online listing is sent when connected.'
                    : 'Saved on this device and ready to use at the till.',
              ),
            ],
            if (state.error != null) _buildErrorBanner(state.error!),
          ],
        ),
        bottomNavigationBar: Container(
          color: DesignTokens.surfaceRaised,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(hint),
                  ),
                if (_onboardingStep == 2 && online && !state.canSubmit)
                  TextButton(
                    onPressed: state.isSubmitting || !basicReady
                        ? null
                        : () => _saveProduct(asDraft: true),
                    child: const Text('Save in my shop · finish online later'),
                  ),
                AppButton(
                  label: _onboardingStep == 0
                      ? 'Continue'
                      : _onboardingStep == 1
                      ? (online ? 'Next: online' : 'Review product')
                      : (online ? 'Add & send online' : 'Add to my shop'),
                  isLoading: state.isSubmitting,
                  expand: true,
                  onPressed:
                      state.isSubmitting ||
                          (_onboardingStep == 1 && !basicReady) ||
                          (_onboardingStep == 2 && !state.canSubmit)
                      ? null
                      : () {
                          if (_onboardingStep < 2) {
                            _goToOnboardingStep(_onboardingStep + 1);
                          } else {
                            _saveProduct();
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sellingChoice(
    ProductFormState state,
    ProductFormController ctrl,
    bool online,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = state.publishOnline == online;
    return Card(
      color: selected
          ? DesignTokens.brandPrimary.withValues(alpha: 0.08)
          : DesignTokens.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? DesignTokens.brandPrimary : DesignTokens.grayLight,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title, style: DesignTokens.textBodyBold),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
        onTap: () => ctrl.setPublishOnline(online),
      ),
    );
  }

  AppBar _buildAppBar(ProductFormState state) {
    return AppBar(
      backgroundColor: DesignTokens.surfaceRaised,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.existingItem == null ? 'New Product' : 'Edit Product',
        style: DesignTokens.textHeadline.copyWith(fontSize: 17),
      ),
      actions: [
        if (_hydratingRemote)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Photo Section ─────────────────────────────────────────────────────────

  Widget _buildPhotoSection(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cover photo${state.publishOnline ? "" : " · optional"}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.publishOnline
                  ? 'The first photo buyers see.'
                  : 'A photo helps you find the product at the till.',
            ),
            const SizedBox(height: 16),
            if (state.hasCover)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: _buildThumbImage(state),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => _showPhotoOptions(ctrl),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(state.hasCover ? 'Change photo' : 'Add photo'),
                ),
                if (state.hasCover)
                  OutlinedButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _editCoverPhoto(state, ctrl),
                    icon: const Icon(Icons.tune),
                    label: const Text('Edit photo'),
                  ),
                if (state.hasCover)
                  TextButton(
                    onPressed: state.isSubmitting ? null : ctrl.removeThumbnail,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.collections_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'More product photos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${state.galleryCount}/6',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              state.publishOnline
                  ? 'Show different sides of your product. Add 3–6 clear photos.'
                  : 'Add extra views so you can recognise the product easily.',
            ),
            if (state.galleryCount > 0) ...[
              const SizedBox(height: 12),
              _buildGalleryStrip(state, ctrl),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.isSubmitting || state.galleryCount >= 6
                  ? null
                  : ctrl.pickGalleryImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                state.galleryCount == 0
                    ? 'Add gallery photos'
                    : 'Add more photos',
              ),
            ),
            if (state.galleryCount >= 6)
              Text(
                'You have added the maximum of 6 photos.',
                style: DesignTokens.textSmall.copyWith(
                  color: DesignTokens.grayMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbImage(ProductFormState state) {
    if (state.thumbnailFile != null) {
      return Image.file(
        state.thumbnailFile!,
        width: double.infinity,
        height: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
      );
    }
    final url = state.thumbnailUrl!;
    if (url.startsWith('http')) {
      return OfflineCachedImage(
        imageUrl: url,
        width: double.infinity,
        height: 240,
        fit: BoxFit.cover,
        errorWidget: _buildPhotoPlaceholder(),
      );
    }
    final f = File(url);
    if (f.existsSync()) {
      return Image.file(
        f,
        width: double.infinity,
        height: 240,
        fit: BoxFit.cover,
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo_outlined,
            size: 32,
            color: DesignTokens.brandPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add product photo',
          style: DesignTokens.textBodyBold.copyWith(
            color: DesignTokens.brandPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to shoot or choose from gallery',
          style: DesignTokens.textSmall.copyWith(
            color: DesignTokens.grayMedium,
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions(ProductFormController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DesignTokens.grayLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Add Photo',
                  style: DesignTokens.textHeadline.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 16),
                _photoOptionTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a photo',
                  onTap: () {
                    Navigator.pop(context);
                    ctrl.takeThumbnailPhoto();
                  },
                ),
                const Divider(height: 1),
                _photoOptionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: () {
                    Navigator.pop(context);
                    ctrl.pickThumbnail();
                  },
                ),
                const Divider(height: 1),
                _photoOptionTile(
                  icon: Icons.collections_outlined,
                  label: 'Add gallery photos',
                  subtitle: 'Select multiple photos',
                  onTap: () {
                    Navigator.pop(context);
                    ctrl.pickGalleryImages();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoOptionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: DesignTokens.brandPrimary, size: 20),
      ),
      title: Text(
        label,
        style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: DesignTokens.textSmall)
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  Widget _buildGalleryStrip(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    final photos = state.orderedGallery;
    if (photos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No gallery photos yet'),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: photos.length,
      onReorderItem: (oldIndex, newIndex) => ctrl.reorderGallery(
        oldIndex,
        newIndex > oldIndex ? newIndex + 1 : newIndex,
      ),
      itemBuilder: (context, index) {
        final path = photos[index];
        final remoteIndex = state.galleryUrls.indexOf(path);
        final localIndex = state.galleryFiles.indexWhere((f) => f.path == path);
        return ListTile(
          key: ValueKey(path),
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: remoteIndex >= 0
                  ? OfflineCachedImage(imageUrl: path, fit: BoxFit.cover)
                  : Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
          title: Text('Photo ${index + 1}'),
          subtitle: const Text('Hold the handle to reorder'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Photo options',
                onSelected: (action) {
                  if (action == 'cover') {
                    if (remoteIndex >= 0) {
                      ctrl.setGalleryUrlAsThumbnail(remoteIndex);
                    } else {
                      ctrl.setGalleryFileAsThumbnail(localIndex);
                    }
                  }
                  if (action == 'remove') {
                    if (remoteIndex >= 0) {
                      ctrl.removeExistingGalleryImage(remoteIndex);
                    } else {
                      ctrl.removeGalleryImage(localIndex);
                    }
                  }
                  if (action == 'edit') _editGalleryPhoto(path, ctrl);
                  if (action == 'replace') _replaceGalleryPhoto(path, ctrl);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Crop, rotate & filters'),
                  ),
                  PopupMenuItem(value: 'replace', child: Text('Replace photo')),
                  PopupMenuItem(value: 'cover', child: Text('Use as cover')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: state.publishOnline
            ? DesignTokens.brandAccent.withValues(alpha: 0.1)
            : DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.publishOnline
              ? DesignTokens.brandAccent.withValues(alpha: 0.4)
              : DesignTokens.dividerSolid,
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(state.publishOnline),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: state.publishOnline
                    ? DesignTokens.brandAccent.withValues(alpha: 0.15)
                    : DesignTokens.surfaceGrouped,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                state.publishOnline
                    ? Icons.public_rounded
                    : Icons.store_outlined,
                color: state.publishOnline
                    ? DesignTokens.brandAccent
                    : DesignTokens.grayMedium,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.publishOnline
                      ? 'Listed on Marketplace'
                      : 'In-Store Only',
                  style: DesignTokens.textBodyBold,
                ),
                Text(
                  state.publishOnline
                      ? 'Added to your online shop after saving and syncing'
                      : 'Use this product at your till',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoadingCategories ||
              state.isLoadingBrands ||
              _hydratingRemote)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: state.publishOnline,
              activeTrackColor: DesignTokens.brandAccent,
              activeThumbColor: DesignTokens.brandAccent,
              onChanged: (v) => ctrl.setPublishOnline(v),
            ),
        ],
      ),
    );
  }

  // ─── Section card wrapper ──────────────────────────────────────────────────

  Widget _buildFormSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    if (title == 'Sanaa Finance BNPL') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          title: const Text('Pay later options'),
          subtitle: const Text('Optional'),
          childrenPadding: const EdgeInsets.all(16),
          children: [child],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.dividerSolid.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 17, color: DesignTokens.brandPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DesignTokens.textBodyBold),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.grayMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Material(color: Colors.transparent, child: child),
          ),
        ],
      ),
    );
  }

  // ─── Product Info Fields ───────────────────────────────────────────────────

  Widget _buildProductInfoFields(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: _nameCtrl,
          label: 'What is the product called?',
          hint: 'e.g. Sugar 1 kg',
          prefixIcon: Icons.inventory_2_outlined,
          textCapitalization: TextCapitalization.words,
          onChanged: ctrl.setName,
        ),
        const SizedBox(height: 16),

        if (state.publishOnline && widget.existingItem != null) ...[
          _buildCategorySelector(state, ctrl),
          const SizedBox(height: 16),
          _buildBrandSelector(state, ctrl),
          const SizedBox(height: 16),
        ],

        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue:
              const [
                'pc',
                'kg',
                'g',
                'set',
                'pair',
                'pack',
                'box',
                'dozen',
                'liter',
                'meter',
              ].contains(state.unit)
              ? state.unit
              : null,
          hint: Text(state.unit.isEmpty ? 'Choose a unit' : state.unit),
          decoration: const InputDecoration(labelText: 'How do you sell it?'),
          items: const [
            DropdownMenuItem(value: 'pc', child: Text('Each (one item)')),
            DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
            DropdownMenuItem(value: 'g', child: Text('Gram')),
            DropdownMenuItem(value: 'set', child: Text('Set')),
            DropdownMenuItem(value: 'pair', child: Text('Pair')),
            DropdownMenuItem(value: 'pack', child: Text('Pack')),
            DropdownMenuItem(value: 'box', child: Text('Box')),
            DropdownMenuItem(value: 'dozen', child: Text('Dozen (12 items)')),
            DropdownMenuItem(value: 'liter', child: Text('Litre')),
            DropdownMenuItem(value: 'meter', child: Text('Metre')),
          ],
          onChanged: (value) {
            if (value != null) ctrl.setUnit(value);
          },
        ),

        if (state.publishOnline && widget.existingItem != null) ...[
          const SizedBox(height: 16),
          AppInput(
            controller: _weightCtrl,
            label: 'Weight (kg)',
            hint: '0.5',
            prefixIcon: Icons.scale_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: ctrl.setWeight,
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelector(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    final hasError = state.categoryId == null && state.publishOnline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category *', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCategoryPicker(state, ctrl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: hasError
                  ? DesignTokens.error.withValues(alpha: 0.04)
                  : DesignTokens.surfaceGrouped,
              border: Border.all(
                color: hasError ? DesignTokens.error : DesignTokens.grayLight,
                width: hasError ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  color: state.categoryId != null
                      ? DesignTokens.brandPrimary
                      : DesignTokens.grayMedium,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.categoryName ?? 'Select category',
                    style: DesignTokens.textBody.copyWith(
                      color: state.categoryName != null
                          ? DesignTokens.textPrimary
                          : DesignTokens.grayMedium,
                    ),
                  ),
                ),
                if (state.isLoadingCategories)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: DesignTokens.grayMedium,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Choose a category to list online',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          ),
      ],
    );
  }

  Widget _buildBrandSelector(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brand (optional)', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showBrandPicker(state, ctrl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceGrouped,
              border: Border.all(color: DesignTokens.grayLight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.branding_watermark_outlined,
                  color: state.brandId != null
                      ? DesignTokens.brandPrimary
                      : DesignTokens.grayMedium,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.brandName ?? 'Select brand',
                    style: DesignTokens.textBody.copyWith(
                      color: state.brandName != null
                          ? DesignTokens.textPrimary
                          : DesignTokens.grayMedium,
                    ),
                  ),
                ),
                if (state.brandId != null)
                  GestureDetector(
                    onTap: () => ctrl.setBrand(null, null),
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: DesignTokens.grayMedium,
                    ),
                  )
                else if (state.isLoadingBrands)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: DesignTokens.grayMedium,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Pricing Fields ────────────────────────────────────────────────────────

  Widget _buildPricingFields(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: _costCtrl,
          label: 'Buying price (UGX)',
          hint: 'What you paid for one item',
          keyboardType: TextInputType.number,
          inputFormatters: const [CommaNumberFormatter()],
          onChanged: (value) {
            ctrl.setCostUnknown(false);
            ctrl.setCost(value);
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I don’t know the buying price yet'),
          value: state.costUnknown,
          onChanged: (value) {
            if (value == true) _costCtrl.clear();
            ctrl.setCostUnknown(value == true);
          },
        ),
        const SizedBox(height: 16),
        AppInput(
          controller: _priceCtrl,
          label: 'Selling price (UGX)',
          hint: 'What the customer pays for one item',
          prefixIcon: Icons.attach_money,
          keyboardType: TextInputType.number,
          inputFormatters: const [CommaNumberFormatter()],
          onChanged: ctrl.setPrice,
        ),
        if (state.estimatedProfit != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${state.estimatedProfit! < 0 ? "Estimated loss" : "Estimated profit"} per item: UGX ${CommaNumberFormatter.format(state.estimatedProfit!.abs().toStringAsFixed(0))}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: state.estimatedProfit! < 0
                    ? const Color(0xffa12222)
                    : const Color(0xff14623c),
              ),
            ),
          ),
        const SizedBox(height: 16),
        AppInput(
          controller: _stockCtrl,
          label: 'How many do you have?',
          hint: '0',
          keyboardType: TextInputType.number,
          inputFormatters: const [CommaNumberFormatter()],
          onChanged: ctrl.setStock,
        ),
        const SizedBox(height: 12),
        if (widget.existingItem == null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('More options (optional)'),
            subtitle: const Text('Discounts, stock alerts and tax'),
            children: _buildExtraPricingFields(state, ctrl),
          )
        else
          ..._buildExtraPricingFields(state, ctrl),
      ],
    );
  }

  List<Widget> _buildExtraPricingFields(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    final remoteConfig = ref.read(remoteConfigProvider);
    return [
      if (state.publishOnline) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppInput(
                controller: _discountCtrl,
                label: 'Discount',
                hint: '0',
                prefixIcon: Icons.discount_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaNumberFormatter()],
                onChanged: ctrl.setDiscount,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type', style: DesignTokens.textSmallBold),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'flat', label: Text('/=')),
                    ButtonSegment(value: 'percent', label: Text('%')),
                  ],
                  selected: {state.discountType},
                  onSelectionChanged: (v) => ctrl.setDiscountType(v.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: DesignTokens.brandPrimary,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      ExpansionTile(
        title: const Text('More stock settings'),
        subtitle: const Text(
          'Item code, minimum order, low-stock alerts and tax',
        ),
        tilePadding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: _skuCtrl,
                  label: 'Item code (automatic)',
                  hint: 'AUTO',
                  prefixIcon: Icons.qr_code,
                  onChanged: ctrl.setSku,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _minQtyCtrl,
                  label: 'Min Order Qty',
                  hint: '1',
                  prefixIcon: Icons.add_shopping_cart_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
                  onChanged: ctrl.setMinQty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _lowStockCtrl,
            label: 'Low stock alert when below',
            hint: 'e.g. 5',
            prefixIcon: Icons.warning_amber_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: const [CommaNumberFormatter()],
            onChanged: ctrl.setLowStockWarning,
          ),
          if (state.taxEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceGrouped,
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        color: DesignTokens.brandPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.taxLabel} Tax',
                        style: DesignTokens.textBodyBold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppInput(
                    controller: _taxRateCtrl,
                    label: '${state.taxLabel} rate (%)',
                    hint: '18',
                    prefixIcon: Icons.percent,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [CommaNumberFormatter()],
                    onChanged: ctrl.setTaxRate,
                  ),
                  const SizedBox(height: 8),
                  _buildTaxInclusionHint(state),
                ],
              ),
            ),
          ],
          if (remoteConfig.ffProductVariantsEditor &&
              widget.existingItem == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceGrouped,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    color: DesignTokens.grayMedium,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Variants can be added after saving the product',
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.grayMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ];
  }

  // ─── Marketplace Fields ────────────────────────────────────────────────────

  Widget _buildMarketplaceFields(
    ProductFormState state,
    ProductFormController ctrl,
  ) {
    final plainDesc = state.description.plainText.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Product Description *',
            style: DesignTokens.textBodyBold.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(height: 6),
        if (widget.existingItem == null)
          AppInput(
            controller: _descriptionCtrl,
            label: 'What should buyers know?',
            hint: 'e.g. A sealed 1 kg bag of white sugar.',
            maxLines: 4,
            onChanged: ctrl.setDescription,
          )
        else
          HtmlEditor(
            initialHtml: _descriptionCtrl.text,
            placeholder: 'Tell buyers what makes this product great…',
            onChanged: ctrl.setDescription,
          ),
        const SizedBox(height: 4),
        if (plainDesc.isNotEmpty && plainDesc.length < 10)
          Text(
            'Needs at least 10 characters (${plainDesc.length}/10)',
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.warning),
          ),
        const SizedBox(height: 16),
        AppInput(
          controller: _tagsCtrl,
          label: 'Tags',
          hint: 'electronics, apple, smartphone',
          prefixIcon: Icons.tag,
          onChanged: ctrl.setTags,
        ),
        const SizedBox(height: 20),
        Text('Delivery', style: DesignTokens.textBodyBold),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: _shippingDaysCtrl,
                label: 'Delivery days *',
                hint: '3',
                prefixIcon: Icons.local_shipping_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaNumberFormatter()],
                onChanged: ctrl.setShippingDays,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInput(
                controller: _shippingFeeCtrl,
                label: 'Delivery fee (UGX)',
                hint: '0 = free',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaNumberFormatter()],
                onChanged: ctrl.setShippingFee,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          icon: Icons.refresh_outlined,
          title: 'Refundable',
          subtitle: 'Customers can request refunds',
          value: state.refundable,
          onChanged: ctrl.setRefundable,
        ),
        const SizedBox(height: 10),
        _buildSwitchTile(
          icon: Icons.payments_rounded,
          title: 'Cash on Delivery',
          subtitle: 'Accept payment on delivery',
          value: state.cashOnDelivery,
          onChanged: ctrl.setCashOnDelivery,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value
            ? DesignTokens.brandAccent.withValues(alpha: 0.06)
            : DesignTokens.surfaceGrouped,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? DesignTokens.brandAccent.withValues(alpha: 0.3)
              : DesignTokens.grayLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? DesignTokens.brandAccent : DesignTokens.grayMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTokens.textBody.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: DesignTokens.brandAccent,
            activeThumbColor: DesignTokens.brandAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildBnplSection(
    ProductFormState state,
    ProductFormController ctrl,
    BnplSellerStatus? status,
  ) {
    final active = status?.isActive ?? false;
    final disabledHint = status == null
        ? 'Loading BNPL status…'
        : switch (status.status) {
            'pending' => 'Enrollment pending — BNPL will unlock once approved.',
            'suspended' => 'BNPL access is suspended.',
            'active' => null,
            _ => 'Request Sanaa Finance BNPL enrollment to enable this option.',
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwitchTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Allow BNPL / Pay Later',
          subtitle: active
              ? 'Customers can buy now and pay later for this product'
              : (disabledHint ?? 'Enable BNPL to use this option'),
          value: state.bnplEnabled,
          onChanged: active ? ctrl.setBnplEnabled : (_) {},
        ),
        if (!active && disabledHint != null) ...[
          const SizedBox(height: 8),
          Text(
            disabledHint,
            style: DesignTokens.textSmall.copyWith(
              color: DesignTokens.inkMuted,
            ),
          ),
        ],
        if (active && state.bnplEnabled) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: _bnplMinCtrl,
                  label: 'Min order amount (/=)',
                  hint: '10,000',
                  prefixIcon: Icons.arrow_downward_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
                  onChanged: ctrl.setBnplMinOrderAmount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _bnplMaxCtrl,
                  label: 'Max order amount (/=)',
                  hint: '500,000',
                  prefixIcon: Icons.arrow_upward_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
                  onChanged: ctrl.setBnplMaxOrderAmount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _bnplInstallmentCtrl,
            label: 'Installment count (optional)',
            hint: 'e.g. 3',
            prefixIcon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: const [CommaNumberFormatter()],
            onChanged: ctrl.setBnplInstallmentCount,
          ),
        ],
      ],
    );
  }

  // ─── Variants Section ─────────────────────────────────────────────────────

  Widget _buildVariantsSection(Item item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.dividerSolid.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductVariantsScreen(itemId: item.id),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.layers_outlined,
            color: DesignTokens.brandPrimary,
            size: 20,
          ),
        ),
        title: const Text(
          'Variants',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Sizes, colors, and other options'),
        trailing: const Icon(
          Icons.chevron_right,
          color: DesignTokens.grayMedium,
        ),
      ),
    );
  }

  // ─── Error Banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: DesignTokens.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(productFormProvider.notifier).clearError(),
            child: const Icon(Icons.close, size: 16, color: DesignTokens.error),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Save Bar ───────────────────────────────────────────────────────

  Widget _buildSaveBar(ProductFormState state) {
    final hint = _getValidationHint(state);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: DesignTokens.warning,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        hint,
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            AppButton(
              label: widget.existingItem == null
                  ? 'Save Product'
                  : 'Update Product',
              onPressed: state.canSubmit ? _saveProduct : null,
              isLoading: state.isSubmitting,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  String? _getValidationHint(ProductFormState state) {
    if (state.name.trim().isEmpty) {
      return 'Enter a product name to continue';
    }
    if (state.unit.trim().isEmpty) {
      return 'Enter a unit of measure (e.g. pc, kg)';
    }
    if (!state.isCategoryValid) {
      return 'Select a category for marketplace listing';
    }
    if (!state.isPricingValid) {
      return 'Enter a valid selling price and stock quantity';
    }
    if (!state.isDiscountValid) {
      return state.discountType == 'percent'
          ? 'Discount must be less than 100%'
          : 'Discount must be less than the selling price';
    }
    if (!state.isExtrasValid) {
      if (coverageError(state.sellingCoverage) != null) {
        return coverageError(state.sellingCoverage);
      }
      return 'Check minimum order quantity, weight and delivery details';
    }
    if (state.publishOnline && !state.isOnlineDetailsValid) {
      if (coverageError(state.sellingCoverage) != null) {
        return coverageError(state.sellingCoverage);
      }
      if (state.description.trim().length < 10) {
        return 'Write a description (at least 10 characters)';
      }
      if (state.shippingDaysValue == null || state.shippingDaysValue! < 1) {
        return 'Set delivery days (e.g. 3)';
      }
      if (state.shippingFeeValue == null) {
        return 'Set delivery fee (0 for free)';
      }
    }
    if (!state.isImagesValid) {
      return !state.hasCover
          ? 'Add a cover photo'
          : 'Add 3–6 different gallery photos (${state.galleryCount} added)';
    }
    return null;
  }

  Widget _buildTaxInclusionHint(ProductFormState state) {
    final isInclusive = state.taxInclusionMode == 'inclusive';
    return Row(
      children: [
        Icon(
          isInclusive ? Icons.check_circle_outline : Icons.add_circle_outline,
          size: 14,
          color: DesignTokens.grayMedium,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isInclusive
                ? 'Price includes ${state.taxLabel}. Tax is shown on receipts.'
                : 'Price excludes ${state.taxLabel}. Tax is added at checkout.',
            style: DesignTokens.textSmall.copyWith(
              color: DesignTokens.grayMedium,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Pickers ───────────────────────────────────────────────────────────────

  void _showCategoryPicker(ProductFormState state, ProductFormController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Text(
                      'Select Category',
                      style: DesignTokens.textHeadline.copyWith(fontSize: 17),
                    ),
                    const Spacer(),
                    if (state.isLoadingCategories)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: state.categories.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: state.categories.length,
                        itemBuilder: (_, i) {
                          final cat = state.categories[i];
                          final isSelected =
                              cat['id']?.toString() == state.categoryId;
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.category_outlined,
                              color: isSelected
                                  ? DesignTokens.brandPrimary
                                  : DesignTokens.grayMedium,
                            ),
                            title: Text(cat['name']?.toString() ?? ''),
                            selected: isSelected,
                            selectedTileColor: DesignTokens.brandPrimary
                                .withValues(alpha: 0.05),
                            onTap: () {
                              ctrl.setCategory(
                                cat['id']?.toString(),
                                cat['name']?.toString(),
                              );
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandPicker(ProductFormState state, ProductFormController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'Select Brand',
                  style: DesignTokens.textHeadline.copyWith(fontSize: 17),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: state.brands.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: state.brands.length,
                        itemBuilder: (_, i) {
                          final brand = state.brands[i];
                          final isSelected =
                              brand['id']?.toString() == state.brandId;
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.branding_watermark_outlined,
                              color: isSelected
                                  ? DesignTokens.brandPrimary
                                  : DesignTokens.grayMedium,
                            ),
                            title: Text(brand['name']?.toString() ?? ''),
                            selected: isSelected,
                            selectedTileColor: DesignTokens.brandPrimary
                                .withValues(alpha: 0.05),
                            onTap: () {
                              ctrl.setBrand(
                                brand['id']?.toString(),
                                brand['name']?.toString(),
                              );
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: DesignTokens.grayLight,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  List<int> _decodeIntList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e?.toString() ?? ''))
            .whereType<int>()
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
