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
import '../../widgets/html_editor.dart';
import '../../widgets/offline_cached_image.dart';
import 'product_form_controller.dart';
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
  bool _hydratingRemote = false;
  bool _hydratedRemote = false;

  final _scrollController = ScrollController();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateFromExisting();
      unawaited(_hydrateFromServerIfNeeded());
      if (widget.startPublishOnline) {
        unawaited(ref.read(productFormProvider.notifier).setPublishOnline(true));
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
    super.dispose();
  }

  // ─── Populate from existing item ──────────────────────────────────────────

  void _populateFromExisting() {
    final item = widget.existingItem;
    if (item == null) return;
    final ctrl = ref.read(productFormProvider.notifier);
    ctrl.setName(item.name);
    _nameCtrl.text = item.name;
    if (item.categoryId != null) ctrl.setCategory(item.categoryId, item.categoryName);
    if (item.brandId != null) ctrl.setBrand(item.brandId, item.brandName);
    ctrl.setUnit(item.unit ?? 'pc');
    _weightCtrl.text = item.weight?.toString() ?? '';
    ctrl.setWeight(_weightCtrl.text);
    _priceCtrl.text = CommaNumberFormatter.format(item.price.toStringAsFixed(0));
    ctrl.setPrice(_priceCtrl.text);
    _costCtrl.text = item.cost != null
        ? CommaNumberFormatter.format(item.cost!.toStringAsFixed(0))
        : '';
    ctrl.setCost(_costCtrl.text);
    _stockCtrl.text = CommaNumberFormatter.format(item.stockQty.toString());
    ctrl.setStock(_stockCtrl.text);
    _discountCtrl.text = item.discount != null
        ? CommaNumberFormatter.format(item.discount!.toStringAsFixed(0))
        : '';
    ctrl.setDiscount(_discountCtrl.text);
    ctrl.setDiscountType(item.discountType ?? 'flat');
    _skuCtrl.text = item.sku ?? '';
    ctrl.setSku(_skuCtrl.text);
    _minQtyCtrl.text = CommaNumberFormatter.format(item.minPurchaseQty.toString());
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
    if (item.publishedOnline) unawaited(ctrl.setPublishOnline(true));

    // Images
    final thumbRaw = (item.thumbnailUrl ?? item.imageUrl)?.trim();
    final galleryUrlsAll = _decodeStringList(item.galleryUrls);
    final galleryIdsAll = _decodeIntList(item.galleryUploadIds);
    final remoteCount =
        galleryIdsAll.length < galleryUrlsAll.length ? galleryIdsAll.length : galleryUrlsAll.length;
    final remoteGalleryUrls = galleryUrlsAll.take(remoteCount).toList();
    final pendingGalleryFiles =
        galleryUrlsAll.skip(remoteCount).map((p) => File(p)).where((f) => f.existsSync()).toList();

    File? pendingThumbnailFile;
    String? remoteThumbnailUrl = thumbRaw;
    int? remoteThumbnailId = item.thumbnailUploadId;
    if (thumbRaw != null && thumbRaw.isNotEmpty && !thumbRaw.startsWith('http')) {
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
      galleryUploadIds: galleryIdsAll.take(remoteCount).toList(),
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

    final needsHydration = item.categoryId == null ||
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
      final lowStock = int.tryParse(data['low_stock_quantity']?.toString() ?? '');
      final discount = double.tryParse(data['discount']?.toString() ?? '');
      final shippingCost = double.tryParse(data['shipping_cost']?.toString() ?? '');
      final estShippingDays = int.tryParse(data['est_shipping_days']?.toString() ?? '');
      final refundable = data['refundable'] == true || data['refundable'] == 1;
      final cashOnDelivery = data['cash_on_delivery'] == true || data['cash_on_delivery'] == 1;
      final published = data['published'] == true || data['published'] == 1;
      final barcode = data['barcode']?.toString();

      final rawDiscountType = data['discount_type']?.toString();
      final localDiscountType =
          rawDiscountType == null ? null : (rawDiscountType == 'amount' ? 'flat' : rawDiscountType);

      unawaited(db.updateItemFields(
        item.id,
        ItemsCompanion(
          remoteId: Value(productId),
          categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
          brandId: brandId != null ? Value(brandId) : const Value.absent(),
          unit: unit != null ? Value(unit) : const Value.absent(),
          weight: weight != null ? Value(weight) : const Value.absent(),
          minPurchaseQty: minQty != null ? Value(minQty) : const Value.absent(),
          lowStockWarning: lowStock != null ? Value(lowStock) : const Value.absent(),
          discount: discount != null ? Value(discount) : const Value.absent(),
          discountType: localDiscountType != null ? Value(localDiscountType) : const Value.absent(),
          shippingFee: shippingCost != null ? Value(shippingCost) : const Value.absent(),
          shippingDays: estShippingDays != null ? Value(estShippingDays) : const Value.absent(),
          refundable: Value(refundable),
          cashOnDelivery: Value(cashOnDelivery),
          barcode: barcode != null ? Value(barcode) : const Value.absent(),
          tags: tags != null ? Value(tags) : const Value.absent(),
          description: description != null ? Value(description) : const Value.absent(),
        ),
      ));

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
        _priceCtrl.text = CommaNumberFormatter.format(unitPrice.toStringAsFixed(0));
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
        _discountCtrl.text = CommaNumberFormatter.format(discount.toStringAsFixed(0));
        ctrl.setDiscount(_discountCtrl.text);
      }
      if (localDiscountType != null) ctrl.setDiscountType(localDiscountType);
      if (shippingCost != null) {
        _shippingFeeCtrl.text = CommaNumberFormatter.format(shippingCost.toStringAsFixed(0));
        ctrl.setShippingFee(_shippingFeeCtrl.text);
      }
      if (estShippingDays != null) {
        _shippingDaysCtrl.text = CommaNumberFormatter.format(estShippingDays.toString());
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

  // ─── Save ──────────────────────────────────────────────────────────────────

  bool _isSaving = false;

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    _isSaving = true;

    final state = ref.read(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);
    if (!state.canSubmit) {
      _isSaving = false;
      return;
    }

    String finalSku = state.sku.trim();
    if (finalSku.isEmpty) {
      await ctrl.autoGenerateSKU();
      finalSku = ref.read(productFormProvider).sku;
    } else {
      final skuError = await ctrl.validateSKU(editingItemId: widget.existingItem?.id);
      if (skuError != null && mounted) {
        _isSaving = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(skuError),
          backgroundColor: DesignTokens.error,
          action: SnackBarAction(
            label: 'Auto-fix',
            textColor: Colors.white,
            onPressed: () async => ctrl.autoGenerateSKU(),
          ),
        ));
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
      final thumbUploadId = state.thumbnailFile != null ? null : state.thumbnailUploadId;

      final pendingGalleryPaths = state.galleryFiles.map((f) => f.path).toList();
      final combinedGalleryUrls = [...state.galleryUrls, ...pendingGalleryPaths];

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
        price: Value(double.tryParse(CommaNumberFormatter.unformat(state.price)) ?? 0),
        cost: Value(double.tryParse(CommaNumberFormatter.unformat(state.cost))),
        stockQty: Value(int.tryParse(CommaNumberFormatter.unformat(state.stock)) ?? 0),
        sku: Value(finalSku.isNotEmpty ? finalSku : null),
        imageUrl: Value(thumbPathOrUrl),
        publishedOnline: Value(state.publishOnline),
        categoryId: Value(state.categoryId),
        categoryName: Value(state.categoryName),
        brandId: Value(state.brandId),
        brandName: Value(state.brandName),
        unit: Value(state.unit),
        weight: Value(double.tryParse(CommaNumberFormatter.unformat(state.weight))),
        minPurchaseQty: Value(int.tryParse(state.minQty) ?? 1),
        tags: Value(state.tags.isNotEmpty ? state.tags : null),
        description: Value(state.description.isNotEmpty ? state.description : null),
        thumbnailUrl: Value(thumbPathOrUrl),
        thumbnailUploadId: Value(thumbUploadId),
        galleryUrls: currentHasGallery || shouldClearGallery
            ? Value(jsonEncode(currentHasGallery ? combinedGalleryUrls : const <String>[]))
            : const Value.absent(),
        galleryUploadIds: currentHasGallery || shouldClearGallery
            ? Value(jsonEncode(currentHasGallery ? state.galleryUploadIds : const <int>[]))
            : const Value.absent(),
        discount: Value(double.tryParse(CommaNumberFormatter.unformat(state.discount))),
        discountType: Value(state.discountType),
        shippingDays: Value(int.tryParse(CommaNumberFormatter.unformat(state.shippingDays))),
        shippingFee: Value(double.tryParse(CommaNumberFormatter.unformat(state.shippingFee))),
        refundable: Value(state.refundable),
        cashOnDelivery: Value(state.cashOnDelivery),
        lowStockWarning: Value(int.tryParse(CommaNumberFormatter.unformat(state.lowStockWarning))),
        synced: const Value(false),
      );

      final opType = widget.existingItem == null ? 'item_create' : 'item_update';
      final catId = int.tryParse(state.categoryId ?? '');

      try {
        await db.saveItemAndEnqueueSync(
          item: companion,
          opType: opType,
          syncPayload: {
            'local_id': id,
            if (widget.existingItem?.remoteId != null) 'remote_id': widget.existingItem!.remoteId,
            'name': state.name.trim(),
            'unit_price': double.tryParse(CommaNumberFormatter.unformat(state.price)) ?? 0,
            'current_stock': int.tryParse(CommaNumberFormatter.unformat(state.stock)) ?? 0,
            'published': state.publishOnline ? 1 : 0,
            if (catId != null) 'category_ids': [catId],
            if (catId != null) 'category_id': catId,
            if (state.brandId != null) 'brand_id': int.tryParse(state.brandId!),
            'unit': state.unit.isNotEmpty ? state.unit : 'pc',
            if (state.weight.isNotEmpty) 'weight': double.tryParse(CommaNumberFormatter.unformat(state.weight)),
            'min_qty': int.tryParse(CommaNumberFormatter.unformat(state.minQty)) ?? 1,
            if (state.tags.isNotEmpty)
              'tags': state.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
            if (state.description.isNotEmpty) 'description': state.description,
            'discount': double.tryParse(CommaNumberFormatter.unformat(state.discount)) ?? 0,
            'discount_type': state.discountType == 'flat' ? 'amount' : 'percent',
            if (state.shippingDays.isNotEmpty)
              'est_shipping_days': int.tryParse(CommaNumberFormatter.unformat(state.shippingDays)),
            if (state.shippingFee.isNotEmpty)
              'shipping_cost': double.tryParse(CommaNumberFormatter.unformat(state.shippingFee)),
            'refundable': state.refundable ? 1 : 0,
            'cash_on_delivery': state.cashOnDelivery ? 1 : 0,
            if (state.lowStockWarning.isNotEmpty)
              'low_stock_quantity': int.tryParse(CommaNumberFormatter.unformat(state.lowStockWarning)),
            if (finalSku.isNotEmpty) 'sku': finalSku,
            if (state.cost.isNotEmpty)
              'purchase_price': double.tryParse(CommaNumberFormatter.unformat(state.cost)),
          },
        );
        unawaited(sync.syncCatalogImmediately());
      } catch (e) {
        _isSaving = false;
        ctrl.setSubmitting(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e'), backgroundColor: DesignTokens.error),
          );
        }
        return;
      }

      if (mounted) {
        ctrl.reset();
        Navigator.pop(context, true);
        final message = state.publishOnline
            ? 'Saved — syncing to your online shop…'
            : 'Saved on this device';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: DesignTokens.brandAccent,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      _isSaving = false;
      ref.read(productFormProvider.notifier).setSubmitting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: DesignTokens.error,
        ));
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: _buildAppBar(state),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero photo
                _buildPhotoSection(state, ctrl),
                const SizedBox(height: 8),

                // 2. Marketplace toggle
                _buildMarketplaceCard(state, ctrl),
                const SizedBox(height: 8),

                // 3. Product info
                _buildFormSection(
                  icon: Icons.inventory_2_outlined,
                  title: 'Product Info',
                  child: _buildProductInfoFields(state, ctrl),
                ),
                const SizedBox(height: 8),

                // 4. Pricing & stock
                _buildFormSection(
                  icon: Icons.payments_outlined,
                  title: 'Pricing & Stock',
                  child: _buildPricingFields(state, ctrl),
                ),
                const SizedBox(height: 8),

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

                // 6. Variants (editing only, feature-flagged)
                if (widget.existingItem != null &&
                    ref.read(remoteConfigProvider).ffProductVariantsEditor) ...[
                  _buildVariantsSection(widget.existingItem!),
                  const SizedBox(height: 8),
                ],

                // Error from permission denial
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  Widget _buildPhotoSection(ProductFormState state, ProductFormController ctrl) {
    final hasThumb = state.thumbnailFile != null ||
        (state.thumbnailUrl != null && state.thumbnailUrl!.isNotEmpty);
    final isSynced = state.thumbnailUploadId != null ||
        (state.thumbnailUrl?.startsWith('http') == true);

    return GestureDetector(
      onTap: () => _showPhotoOptions(ctrl),
      child: Stack(
        children: [
          // Background image or placeholder
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasThumb
                  ? Colors.black
                  : DesignTokens.brandPrimary.withValues(alpha: 0.05),
            ),
            child: hasThumb ? _buildThumbImage(state) : _buildPhotoPlaceholder(),
          ),

          // Gradient overlay at bottom for the "change photo" hint
          if (hasThumb)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),

          // "Tap to change" label when image exists
          if (hasThumb)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          isSynced ? 'Change photo' : 'Tap to change photo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Synced badge
          if (isSynced && hasThumb)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DesignTokens.brandAccent.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Synced', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else if (hasThumb && state.thumbnailFile != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Uploading on sync', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),

          // Remove button
          if (hasThumb)
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: ctrl.removeThumbnail,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
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
      return Image.file(f, width: double.infinity, height: 240, fit: BoxFit.cover);
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
          style: DesignTokens.textBodyBold.copyWith(color: DesignTokens.brandPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to shoot or choose from gallery',
          style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
        ),
      ],
    );
  }

  void _showPhotoOptions(ProductFormController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text('Add Photo', style: DesignTokens.textHeadline.copyWith(fontSize: 17)),
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
              subtitle: 'Showcase multiple angles',
              onTap: () {
                Navigator.pop(context);
                ctrl.pickGalleryImages();
              },
            ),
          ],
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
      title: Text(label, style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: DesignTokens.textSmall) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  // Gallery strip (shown below the hero if gallery photos exist)
  Widget _buildGalleryStrip(ProductFormState state, ProductFormController ctrl) {
    final total = state.galleryUrls.length + state.galleryFiles.length;
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: total + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == total) {
            return GestureDetector(
              onTap: ctrl.pickGalleryImages,
              child: Container(
                width: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: DesignTokens.brandPrimary.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: DesignTokens.brandPrimary.withValues(alpha: 0.04),
                ),
                child: const Icon(Icons.add, color: DesignTokens.brandPrimary),
              ),
            );
          }
          final isRemote = i < state.galleryUrls.length;
          final fileIndex = i - state.galleryUrls.length;
          return GestureDetector(
            onLongPress: () {
              if (isRemote) ctrl.setGalleryUrlAsThumbnail(i);
              else ctrl.setGalleryFileAsThumbnail(fileIndex);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Set as main photo'), duration: Duration(seconds: 1)),
              );
            },
            child: Stack(
              children: [
                Container(
                  width: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRemote
                          ? DesignTokens.brandAccent.withValues(alpha: 0.6)
                          : DesignTokens.grayLight,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: isRemote
                        ? OfflineCachedImage(
                            imageUrl: state.galleryUrls[i],
                            width: 70,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: const SizedBox(),
                          )
                        : Image.file(
                            state.galleryFiles[fileIndex],
                            width: 70,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => isRemote
                        ? ctrl.removeExistingGalleryImage(i)
                        : ctrl.removeGalleryImage(fileIndex),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Marketplace Toggle Card ────────────────────────────────────────────────

  Widget _buildMarketplaceCard(ProductFormState state, ProductFormController ctrl) {
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
                state.publishOnline ? Icons.public_rounded : Icons.store_outlined,
                color: state.publishOnline ? DesignTokens.brandAccent : DesignTokens.grayMedium,
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
                  state.publishOnline ? 'Listed on Marketplace' : 'In-Store Only',
                  style: DesignTokens.textBodyBold,
                ),
                Text(
                  state.publishOnline
                      ? 'Visible on soko24.co to all buyers'
                      : 'Only available at point of sale',
                  style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                ),
              ],
            ),
          ),
          if (state.isLoadingCategories || state.isLoadingBrands || _hydratingRemote)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: state.publishOnline,
              activeColor: DesignTokens.brandAccent,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.dividerSolid.withValues(alpha: 0.5)),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DesignTokens.textBodyBold),
                    if (subtitle != null)
                      Text(subtitle,
                          style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ─── Product Info Fields ───────────────────────────────────────────────────

  Widget _buildProductInfoFields(ProductFormState state, ProductFormController ctrl) {
    const units = ['pc', 'kg', 'g', 'set', 'pair', 'pack', 'box', 'dozen', 'liter', 'meter'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: _nameCtrl,
          label: 'Product Name *',
          hint: 'E.g., iPhone 15 Pro Max 256GB',
          prefixIcon: Icons.inventory_2_outlined,
          textCapitalization: TextCapitalization.words,
          onChanged: ctrl.setName,
        ),
        const SizedBox(height: 16),

        if (state.publishOnline) ...[
          _buildCategorySelector(state, ctrl),
          const SizedBox(height: 16),
          _buildBrandSelector(state, ctrl),
          const SizedBox(height: 16),
        ],

        // Unit chips
        Text('Unit *', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: units.map((unit) => ChoiceChip(
            label: Text(unit),
            selected: state.unit == unit,
            onSelected: (v) { if (v) ctrl.setUnit(unit); },
            selectedColor: DesignTokens.brandPrimary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: state.unit == unit ? DesignTokens.brandPrimary : DesignTokens.grayDark,
              fontWeight: state.unit == unit ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: state.unit == unit
                  ? DesignTokens.brandPrimary.withValues(alpha: 0.5)
                  : DesignTokens.grayLight,
            ),
          )).toList(),
        ),

        if (state.publishOnline) ...[
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

        // Gallery strip (if any gallery photos)
        if (state.galleryUrls.isNotEmpty || state.galleryFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Gallery Photos', style: DesignTokens.textSmallBold),
          const SizedBox(height: 8),
          _buildGalleryStrip(state, ctrl),
        ] else if (state.publishOnline) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: ctrl.pickGalleryImages,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DesignTokens.brandPrimary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DesignTokens.brandPrimary.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: DesignTokens.brandPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add gallery photos',
                            style: DesignTokens.textBody
                                .copyWith(color: DesignTokens.brandPrimary, fontWeight: FontWeight.w600)),
                        Text('Show more angles to attract buyers',
                            style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelector(ProductFormState state, ProductFormController ctrl) {
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
                  color: state.categoryId != null ? DesignTokens.brandPrimary : DesignTokens.grayMedium,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.categoryName ?? 'Select category',
                    style: DesignTokens.textBody.copyWith(
                      color: state.categoryName != null ? DesignTokens.textPrimary : DesignTokens.grayMedium,
                    ),
                  ),
                ),
                if (state.isLoadingCategories)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.chevron_right, color: DesignTokens.grayMedium, size: 20),
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

  Widget _buildBrandSelector(ProductFormState state, ProductFormController ctrl) {
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
                  color: state.brandId != null ? DesignTokens.brandPrimary : DesignTokens.grayMedium,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.brandName ?? 'Select brand',
                    style: DesignTokens.textBody.copyWith(
                      color: state.brandName != null ? DesignTokens.textPrimary : DesignTokens.grayMedium,
                    ),
                  ),
                ),
                if (state.brandId != null)
                  GestureDetector(
                    onTap: () => ctrl.setBrand(null, null),
                    child: const Icon(Icons.clear, size: 18, color: DesignTokens.grayMedium),
                  )
                else if (state.isLoadingBrands)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.chevron_right, color: DesignTokens.grayMedium, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Pricing Fields ────────────────────────────────────────────────────────

  Widget _buildPricingFields(ProductFormState state, ProductFormController ctrl) {
    final remoteConfig = ref.read(remoteConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price — hero field
        AppInput(
          controller: _priceCtrl,
          label: 'Selling Price (UGX) *',
          hint: '50,000',
          prefixIcon: Icons.attach_money,
          keyboardType: TextInputType.number,
          inputFormatters: const [CommaNumberFormatter()],
          onChanged: ctrl.setPrice,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: _costCtrl,
                label: 'Buying Price (UGX)',
                hint: '30,000',
                prefixIcon: Icons.shopping_bag_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaNumberFormatter()],
                onChanged: ctrl.setCost,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInput(
                controller: _stockCtrl,
                label: 'Stock Qty *',
                hint: '10',
                prefixIcon: Icons.inventory,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaNumberFormatter()],
                onChanged: ctrl.setStock,
              ),
            ),
          ],
        ),

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
                      ButtonSegment(value: 'flat', label: Text('UGX')),
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

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: _skuCtrl,
                label: 'SKU',
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

        if (remoteConfig.ffProductVariantsEditor && widget.existingItem == null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceGrouped,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, color: DesignTokens.grayMedium, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Variants can be added after saving the product',
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Marketplace Fields ────────────────────────────────────────────────────

  Widget _buildMarketplaceFields(ProductFormState state, ProductFormController ctrl) {
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
                label: 'Fee (UGX) *',
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
        color: value ? DesignTokens.brandAccent.withValues(alpha: 0.06) : DesignTokens.surfaceGrouped,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? DesignTokens.brandAccent.withValues(alpha: 0.3) : DesignTokens.grayLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? DesignTokens.brandAccent : DesignTokens.grayMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: DesignTokens.brandAccent,
          ),
        ],
      ),
    );
  }

  // ─── Variants Section ─────────────────────────────────────────────────────

  Widget _buildVariantsSection(Item item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.dividerSolid.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductVariantsScreen(itemId: item.id)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.layers_outlined, color: DesignTokens.brandPrimary, size: 20),
        ),
        title: const Text('Variants', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Sizes, colors, and other options'),
        trailing: const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
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
            child: Text(message, style: DesignTokens.textSmall.copyWith(color: DesignTokens.error)),
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
                    const Icon(Icons.info_outline, size: 16, color: DesignTokens.warning),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        hint,
                        style: DesignTokens.textSmall.copyWith(color: DesignTokens.warning),
                      ),
                    ),
                  ],
                ),
              ),
            AppButton(
              label: widget.existingItem == null ? 'Save Product' : 'Update Product',
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
    if (state.name.trim().isEmpty) return 'Enter a product name to continue';
    if (!state.isCategoryValid) return 'Select a category for marketplace listing';
    if (!state.isPricingValid) return 'Enter a valid selling price and stock quantity';
    if (!state.isDiscountValid) {
      return state.discountType == 'percent'
          ? 'Discount must be less than 100%'
          : 'Discount must be less than the selling price';
    }
    if (!state.isExtrasValid) return 'Check min qty / shipping fields';
    if (state.publishOnline && !state.isOnlineDetailsValid) {
      if (state.description.trim().length < 10) return 'Write a description (at least 10 characters)';
      if (state.shippingDaysValue == null) return 'Set delivery days (e.g. 3)';
      if (state.shippingFeeValue == null) return 'Set delivery fee (0 for free)';
    }
    if (!state.isImagesValid) return 'Add a product photo for marketplace listing';
    return null;
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
                    Text('Select Category', style: DesignTokens.textHeadline.copyWith(fontSize: 17)),
                    const Spacer(),
                    if (state.isLoadingCategories)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
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
                          final isSelected = cat['id']?.toString() == state.categoryId;
                          return ListTile(
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.category_outlined,
                              color: isSelected ? DesignTokens.brandPrimary : DesignTokens.grayMedium,
                            ),
                            title: Text(cat['name']?.toString() ?? ''),
                            selected: isSelected,
                            selectedTileColor: DesignTokens.brandPrimary.withValues(alpha: 0.05),
                            onTap: () {
                              ctrl.setCategory(cat['id']?.toString(), cat['name']?.toString());
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
                child: Text('Select Brand', style: DesignTokens.textHeadline.copyWith(fontSize: 17)),
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
                          final isSelected = brand['id']?.toString() == state.brandId;
                          return ListTile(
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.branding_watermark_outlined,
                              color: isSelected ? DesignTokens.brandPrimary : DesignTokens.grayMedium,
                            ),
                            title: Text(brand['name']?.toString() ?? ''),
                            selected: isSelected,
                            selectedTileColor: DesignTokens.brandPrimary.withValues(alpha: 0.05),
                            onTap: () {
                              ctrl.setBrand(brand['id']?.toString(), brand['name']?.toString());
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
        return decoded.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  List<int> _decodeIntList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is List) {
        return decoded.map((e) => int.tryParse(e?.toString() ?? '')).whereType<int>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
