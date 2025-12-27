import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import 'product_form_controller.dart';
import 'product_variants_screen.dart';

/// Reactive multi-tab product creation screen
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
  late TabController _tabController;
  bool _hydratingRemote = false;
  bool _hydratedRemote = false;

  // Text controllers (synced with state)
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Populate from existing item if editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateFromExisting();
      unawaited(_hydrateFromServerIfNeeded());
      if (widget.startPublishOnline) {
        unawaited(ref.read(productFormProvider.notifier).setPublishOnline(true));
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref.read(productFormProvider.notifier).setTab(_tabController.index);
    }
  }

  void _populateFromExisting() {
    final item = widget.existingItem;
    if (item != null) {
      final ctrl = ref.read(productFormProvider.notifier);
      ctrl.setName(item.name);
      _nameCtrl.text = item.name;
      if (item.categoryId != null) {
        ctrl.setCategory(item.categoryId, item.categoryName);
      }
      if (item.brandId != null) {
        ctrl.setBrand(item.brandId, item.brandName);
      }
      ctrl.setUnit(item.unit ?? 'pc');
      _weightCtrl.text = item.weight?.toString() ?? '';
      ctrl.setWeight(_weightCtrl.text);
      _priceCtrl.text = item.price.toStringAsFixed(0);
      ctrl.setPrice(item.price.toStringAsFixed(0));
      _stockCtrl.text = item.stockQty.toString();
      ctrl.setStock(item.stockQty.toString());
      _discountCtrl.text = item.discount?.toStringAsFixed(0) ?? '';
      ctrl.setDiscount(_discountCtrl.text);
      ctrl.setDiscountType(item.discountType ?? 'flat');
      _skuCtrl.text = item.sku ?? '';
      ctrl.setSku(_skuCtrl.text);
      _minQtyCtrl.text = item.minPurchaseQty.toString();
      ctrl.setMinQty(_minQtyCtrl.text);
      _lowStockCtrl.text = item.lowStockWarning?.toString() ?? '';
      ctrl.setLowStockWarning(_lowStockCtrl.text);
      _descriptionCtrl.text = item.description ?? '';
      ctrl.setDescription(_descriptionCtrl.text);
      _tagsCtrl.text = item.tags ?? '';
      ctrl.setTags(_tagsCtrl.text);
      _shippingDaysCtrl.text = item.shippingDays?.toString() ?? '';
      ctrl.setShippingDays(_shippingDaysCtrl.text);
      _shippingFeeCtrl.text = item.shippingFee?.toStringAsFixed(0) ?? '';
      ctrl.setShippingFee(_shippingFeeCtrl.text);
      ctrl.setRefundable(item.refundable);
      ctrl.setCashOnDelivery(item.cashOnDelivery);
      if (item.publishedOnline) {
        ctrl.setPublishOnline(true);
      }

      // Hydrate images from local DB snapshot (remote urls + pending local paths).
      final thumbRaw = (item.thumbnailUrl ?? item.imageUrl)?.trim();
      final galleryUrlsAll = _decodeStringList(item.galleryUrls);
      final galleryIdsAll = _decodeIntList(item.galleryUploadIds);
      final remoteCount = galleryIdsAll.length < galleryUrlsAll.length ? galleryIdsAll.length : galleryUrlsAll.length;
      final remoteGalleryUrls = galleryUrlsAll.take(remoteCount).toList();
      final pendingGalleryFiles = galleryUrlsAll
          .skip(remoteCount)
          .map((p) => File(p))
          .where((f) => f.existsSync())
          .toList();

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
  }

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

      final unitPriceRaw = data['unit_price'];
      final stockRaw = data['current_stock'];
      final weightRaw = data['weight'];
      final minQtyRaw = data['min_qty'];
      final lowStockRaw = data['low_stock_quantity'];
      final discountRaw = data['discount'];
      final discountTypeRaw = data['discount_type']?.toString();
      final shippingCostRaw = data['shipping_cost'];
      final estShippingDaysRaw = data['est_shipping_days'];
      final refundableRaw = data['refundable'];
      final cashOnDeliveryRaw = data['cash_on_delivery'];
      final publishedRaw = data['published'];
      final barcode = data['barcode']?.toString();

      final unitPrice = double.tryParse(unitPriceRaw?.toString() ?? '');
      final stock = int.tryParse(stockRaw?.toString() ?? '');
      final weight = double.tryParse(weightRaw?.toString() ?? '');
      final minQty = int.tryParse(minQtyRaw?.toString() ?? '');
      final lowStock = int.tryParse(lowStockRaw?.toString() ?? '');
      final discount = double.tryParse(discountRaw?.toString() ?? '');
      final shippingCost = double.tryParse(shippingCostRaw?.toString() ?? '');
      final estShippingDays = int.tryParse(estShippingDaysRaw?.toString() ?? '');
      final refundable = refundableRaw == true || refundableRaw == 1;
      final cashOnDelivery = cashOnDeliveryRaw == true || cashOnDeliveryRaw == 1;
      final published = publishedRaw == true || publishedRaw == 1;

      final localDiscountType = discountTypeRaw == null
          ? null
          : (discountTypeRaw == 'amount' ? 'flat' : discountTypeRaw);

      // Update local DB with richer fields (best effort).
      unawaited(
        db.updateItemFields(
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
            discountType: localDiscountType != null
                ? Value(localDiscountType)
                : const Value.absent(),
            shippingFee: shippingCost != null ? Value(shippingCost) : const Value.absent(),
            shippingDays: estShippingDays != null
                ? Value(estShippingDays)
                : const Value.absent(),
            refundable: Value(refundable),
            cashOnDelivery: Value(cashOnDelivery),
            barcode: barcode != null ? Value(barcode) : const Value.absent(),
            tags: tags != null ? Value(tags) : const Value.absent(),
            description: description != null ? Value(description) : const Value.absent(),
          ),
        ),
      );

      // Hydrate form state (only when data is present).
      if (name != null && name.trim().isNotEmpty) {
        _nameCtrl.text = name;
        ctrl.setName(name);
      }
      if (unit != null && unit.trim().isNotEmpty) {
        ctrl.setUnit(unit);
      }
      if (categoryId != null) {
        ctrl.setCategory(categoryId, null);
      }
      if (brandId != null) {
        ctrl.setBrand(brandId, null);
      }
      if (description != null) {
        _descriptionCtrl.text = description;
        ctrl.setDescription(description);
      }
      if (tags != null) {
        _tagsCtrl.text = tags;
        ctrl.setTags(tags);
      }
      if (unitPrice != null) {
        _priceCtrl.text = unitPrice.toStringAsFixed(0);
        ctrl.setPrice(_priceCtrl.text);
      }
      if (stock != null) {
        _stockCtrl.text = stock.toString();
        ctrl.setStock(_stockCtrl.text);
      }
      if (weight != null) {
        _weightCtrl.text = weight.toString();
        ctrl.setWeight(_weightCtrl.text);
      }
      if (minQty != null) {
        _minQtyCtrl.text = minQty.toString();
        ctrl.setMinQty(_minQtyCtrl.text);
      }
      if (lowStock != null) {
        _lowStockCtrl.text = lowStock.toString();
        ctrl.setLowStockWarning(_lowStockCtrl.text);
      }
      if (discount != null) {
        _discountCtrl.text = discount.toStringAsFixed(0);
        ctrl.setDiscount(_discountCtrl.text);
      }
      if (localDiscountType != null) {
        ctrl.setDiscountType(localDiscountType);
      }
      if (shippingCost != null) {
        _shippingFeeCtrl.text = shippingCost.toStringAsFixed(0);
        ctrl.setShippingFee(_shippingFeeCtrl.text);
      }
      if (estShippingDays != null) {
        _shippingDaysCtrl.text = estShippingDays.toString();
        ctrl.setShippingDays(_shippingDaysCtrl.text);
      }
      ctrl.setRefundable(refundable);
      ctrl.setCashOnDelivery(cashOnDelivery);

      if (published && !ref.read(productFormProvider).publishOnline) {
        await ctrl.setPublishOnline(true);
      }

      _hydratedRemote = true;
    } catch (_) {
      // Best effort: offline/unauthorized/etc.
    } finally {
      if (mounted) {
        setState(() => _hydratingRemote = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _priceCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Add Product' : 'Edit Product'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Online toggle banner
              _buildOnlineToggle(state, ctrl),
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: DesignTokens.brandPrimary,
                unselectedLabelColor: DesignTokens.grayMedium,
                indicatorColor: DesignTokens.brandPrimary,
                tabs: [
                  Tab(icon: Icon(Icons.info_outline), text: 'Basic'),
                  Tab(icon: Icon(Icons.attach_money), text: 'Pricing'),
                  if (state.publishOnline) ...[
                    Tab(icon: Icon(Icons.image), text: 'Images'),
                    Tab(icon: Icon(Icons.description), text: 'Details'),
                  ] else ...[
                    Tab(icon: Icon(Icons.image), text: 'Images'),
                    Tab(icon: Icon(Icons.local_shipping), text: 'Shipping'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(state, ctrl),
          _buildPricingTab(state, ctrl),
          _buildImagesTab(state, ctrl),
          state.publishOnline 
              ? _buildDetailsTab(state, ctrl)
              : _buildShippingTab(state, ctrl),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildOnlineToggle(ProductFormState state, ProductFormController ctrl) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: state.publishOnline 
          ? DesignTokens.brandAccent.withValues(alpha: 0.15)
          : DesignTokens.grayLight.withValues(alpha: 0.3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              state.publishOnline ? Icons.public : Icons.store,
              key: ValueKey(state.publishOnline),
              color: state.publishOnline ? DesignTokens.brandAccent : DesignTokens.grayMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.publishOnline ? 'Marketplace Listing' : 'POS Only',
                  style: DesignTokens.textBodyBold,
                ),
                Text(
                  state.publishOnline 
                      ? 'Visible on soko.sanaa.ug' 
                      : 'Only at point of sale',
                  style: DesignTokens.textSmall,
                ),
              ],
            ),
          ),
          if (state.isLoadingCategories || state.isLoadingBrands)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_hydratingRemote)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: state.publishOnline,
              onChanged: (v) => ctrl.setPublishOnline(v),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab(ProductFormState state, ProductFormController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Information', style: DesignTokens.textTitle),
          const SizedBox(height: 16),
          
          AppInput(
            controller: _nameCtrl,
            label: 'Product Name *',
            hint: 'E.g., iPhone 15 Pro Max',
            prefixIcon: Icons.inventory_2_outlined,
            textCapitalization: TextCapitalization.words,
            onChanged: ctrl.setName,
          ),
          const SizedBox(height: 16),
          
          if (state.publishOnline) ...[
            // Category selector
            _buildCategorySelector(state, ctrl),
            const SizedBox(height: 16),
            
            // Brand selector  
            _buildBrandSelector(state, ctrl),
            const SizedBox(height: 16),
          ],
          
          // Unit selector
          _buildUnitSelector(state, ctrl),
          
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
        ],
      ),
    );
  }

  Widget _buildCategorySelector(ProductFormState state, ProductFormController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category *', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCategoryPicker(state, ctrl),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: state.categoryId == null && state.publishOnline
                    ? DesignTokens.error
                    : DesignTokens.grayLight,
                width: state.categoryId == null && state.publishOnline ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  color: state.categoryId != null 
                      ? DesignTokens.brandPrimary 
                      : DesignTokens.grayMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.categoryName ?? 'Select category',
                    style: state.categoryName != null
                        ? DesignTokens.textBody
                        : DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                  ),
                ),
                if (state.isLoadingCategories)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandSelector(ProductFormState state, ProductFormController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brand (Optional)', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showBrandPicker(state, ctrl),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: DesignTokens.grayLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.branding_watermark_outlined,
                  color: state.brandId != null 
                      ? DesignTokens.brandPrimary 
                      : DesignTokens.grayMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.brandName ?? 'Select brand',
                    style: state.brandName != null
                        ? DesignTokens.textBody
                        : DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                  ),
                ),
                if (state.brandId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => ctrl.setBrand(null, null),
                  )
                else if (state.isLoadingBrands)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector(ProductFormState state, ProductFormController ctrl) {
    const units = ['pc', 'kg', 'g', 'set', 'pair', 'pack', 'box', 'dozen', 'liter', 'meter'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit *', style: DesignTokens.textSmallBold),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: units.map((unit) => ChoiceChip(
            label: Text(unit),
            selected: state.unit == unit,
            onSelected: (v) {
              if (v) ctrl.setUnit(unit);
            },
            selectedColor: DesignTokens.brandPrimary.withValues(alpha: 0.2),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildPricingTab(ProductFormState state, ProductFormController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pricing & Stock', style: DesignTokens.textTitle),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppInput(
                  controller: _priceCtrl,
                  label: 'Unit Price (UGX) *',
                  hint: '50000',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: ctrl.setPrice,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _stockCtrl,
                  label: 'Stock *',
                  hint: '10',
                  prefixIcon: Icons.inventory,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: ctrl.setStock,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (state.publishOnline) ...[
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _discountCtrl,
                    label: 'Discount',
                    hint: '0',
                    prefixIcon: Icons.discount_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: _skuCtrl,
                  label: 'SKU',
                  hint: 'ABC-123',
                  prefixIcon: Icons.qr_code,
                  onChanged: ctrl.setSku,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _minQtyCtrl,
                  label: 'Min Qty',
                  hint: '1',
                  prefixIcon: Icons.shopping_bag_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: ctrl.setMinQty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          AppInput(
            controller: _lowStockCtrl,
            label: 'Low Stock Warning',
            hint: 'Alert when below this quantity',
            prefixIcon: Icons.warning_amber_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: ctrl.setLowStockWarning,
          ),

          const SizedBox(height: 24),

          if (widget.existingItem != null) ...[
            _buildVariantsCard(widget.existingItem!),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.grayLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined, color: DesignTokens.grayMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Variants are available after you save the product.',
                      style: DesignTokens.textSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantsCard(Item item) {
    final db = ref.read(appDatabaseProvider);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductVariantsScreen(itemId: item.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesignTokens.grayLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers_outlined, color: DesignTokens.brandPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variants', style: DesignTokens.textBodyBold),
                  const SizedBox(height: 4),
                  StreamBuilder<List<ItemStock>>(
                    stream: db.watchItemStocksForItem(item.id),
                    builder: (context, snapshot) {
                      final stocks = snapshot.data ?? const <ItemStock>[];
                      final variants =
                          stocks.where((s) => s.variant.trim().isNotEmpty).length;
                      final label = variants == 0
                          ? 'No variants yet'
                          : '$variants variants configured';
                      return Text(label, style: DesignTokens.textSmall);
                    },
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesTab(ProductFormState state, ProductFormController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Images', style: DesignTokens.textTitle),
          const SizedBox(height: 8),
          Text(
            'Add a thumbnail and gallery images to showcase your product',
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: 24),
          
          // Thumbnail
          Text('Thumbnail (Main Image)', style: DesignTokens.textBodyBold),
          const SizedBox(height: 12),
          _buildThumbnailPicker(state, ctrl),
          
          const SizedBox(height: 32),
          
          // Gallery
          Text('Gallery Images', style: DesignTokens.textBodyBold),
          const SizedBox(height: 12),
          _buildGalleryPicker(state, ctrl),
        ],
      ),
    );
  }

  Widget _buildThumbnailPicker(ProductFormState state, ProductFormController ctrl) {
    final hasFile = state.thumbnailFile != null;
    final url = state.thumbnailUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    if (hasFile || hasUrl) {
      final image = hasFile
          ? Image.file(
              state.thumbnailFile!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            )
          : (url!.startsWith('http')
              ? Image.network(
                  url,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 200),
                )
              : Image.file(
                  File(url),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 200),
                ));

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: ctrl.removeThumbnail,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DesignTokens.grayLight,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, 
                    size: 48, color: DesignTokens.grayMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: ctrl.pickThumbnail,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: ctrl.takeThumbnailPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _buildGalleryPicker(ProductFormState state, ProductFormController ctrl) {
    final total = state.galleryUrls.length + state.galleryFiles.length;
    return Column(
      children: [
        // Add button
        InkWell(
          onTap: ctrl.pickGalleryImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.brandPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DesignTokens.brandPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.add_photo_alternate, 
                    size: 32, color: DesignTokens.brandPrimary),
                const SizedBox(height: 8),
                Text('Add Gallery Images', 
                    style: DesignTokens.textBody.copyWith(
                      color: DesignTokens.brandPrimary,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
        
        if (total > 0) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: total,
            itemBuilder: (_, i) {
              final isRemote = i < state.galleryUrls.length;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isRemote
                        ? Image.network(
                            state.galleryUrls[i],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          )
                        : Image.file(
                            state.galleryFiles[i - state.galleryUrls.length],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => isRemote
                          ? ctrl.removeExistingGalleryImage(i)
                          : ctrl.removeGalleryImage(i - state.galleryUrls.length),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, 
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsTab(ProductFormState state, ProductFormController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description & Details', style: DesignTokens.textTitle),
          const SizedBox(height: 16),
          
          AppInput(
            controller: _descriptionCtrl,
            label: 'Product Description',
            hint: 'Describe your product in detail...',
            maxLines: 6,
            onChanged: ctrl.setDescription,
          ),
          const SizedBox(height: 16),
          
          AppInput(
            controller: _tagsCtrl,
            label: 'Tags (comma-separated)',
            hint: 'smartphone, apple, electronics',
            prefixIcon: Icons.tag,
            onChanged: ctrl.setTags,
          ),
          const SizedBox(height: 24),
          
          // Shipping section
          Text('Shipping & Options', style: DesignTokens.textTitle),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: _shippingDaysCtrl,
                  label: 'Shipping Days',
                  hint: '3',
                  prefixIcon: Icons.local_shipping_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: ctrl.setShippingDays,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _shippingFeeCtrl,
                  label: 'Shipping Fee (UGX)',
                  hint: '5000',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: ctrl.setShippingFee,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSwitchTile(
            title: 'Refundable',
            subtitle: 'Allow customers to request refunds',
            value: state.refundable,
            onChanged: ctrl.setRefundable,
            icon: Icons.refresh,
          ),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'Cash on Delivery',
            subtitle: 'Accept payment on delivery',
            value: state.cashOnDelivery,
            onChanged: ctrl.setCashOnDelivery,
            icon: Icons.payments,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingTab(ProductFormState state, ProductFormController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional Options', style: DesignTokens.textTitle),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: DesignTokens.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Shipping and advanced options are available when you enable "Marketplace Listing".',
                    style: DesignTokens.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.grayLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: DesignTokens.grayMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DesignTokens.textBodyBold),
                Text(subtitle, style: DesignTokens.textSmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ProductFormState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Validation status
            if (!state.canSubmit)
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                        color: DesignTokens.warning, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _getValidationMessage(state),
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            
            const SizedBox(width: 12),
            
            AppButton(
              label: widget.existingItem == null ? 'Create Product' : 'Save',
              onPressed: state.canSubmit ? _saveProduct : null,
              isLoading: state.isSubmitting,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }

  String _getValidationMessage(ProductFormState state) {
    if (!state.isBasicInfoValid) return 'Enter product name';
    if (!state.isCategoryValid) return 'Select a category';
    if (!state.isPricingValid) return 'Enter a valid price and stock';
    if (!state.isDiscountValid) {
      return state.discountType == 'percent'
          ? 'Discount must be less than 100%'
          : 'Discount must be less than price';
    }
    if (!state.isExtrasValid) return 'Check min qty / shipping fields';
    if (state.publishOnline && !state.isOnlineDetailsValid) {
      if (state.description.trim().isEmpty || state.description.trim().length < 10) {
        return 'Add a good description (10+ chars)';
      }
      if (state.shippingDaysValue == null) return 'Set shipping days (e.g. 3)';
      if (state.shippingFeeValue == null) return 'Set shipping fee (0 if free)';
      return 'Complete marketplace details';
    }
    if (!state.isImagesValid) return 'Add a product photo';
    return '';
  }

  void _showCategoryPicker(ProductFormState state, ProductFormController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select Category', style: DesignTokens.textTitle),
              ),
              Expanded(
                child: state.categories.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: state.categories.length,
                        itemBuilder: (_, i) {
                          final cat = state.categories[i];
                          final isSelected = cat['id']?.toString() == state.categoryId;
                          return ListTile(
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.category_outlined,
                              color: isSelected ? DesignTokens.brandPrimary : null,
                            ),
                            title: Text(cat['name']?.toString() ?? ''),
                            selected: isSelected,
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
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select Brand', style: DesignTokens.textTitle),
              ),
              Expanded(
                child: state.brands.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: state.brands.length,
                        itemBuilder: (_, i) {
                          final brand = state.brands[i];
                          final isSelected = brand['id']?.toString() == state.brandId;
                          return ListTile(
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.branding_watermark_outlined,
                              color: isSelected ? DesignTokens.brandPrimary : null,
                            ),
                            title: Text(brand['name']?.toString() ?? ''),
                            selected: isSelected,
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

  Future<void> _saveProduct() async {
    final state = ref.read(productFormProvider);
    final ctrl = ref.read(productFormProvider.notifier);
    
    if (!state.canSubmit) return;
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
      final existingRemoteCount = existingGalleryIds.length < existingGalleryUrls.length
          ? existingGalleryIds.length
          : existingGalleryUrls.length;
      final existingHasGallery = existingRemoteCount > 0 || existingGalleryUrls.skip(existingRemoteCount).isNotEmpty;
      final currentHasGallery = combinedGalleryUrls.isNotEmpty;
      final shouldClearGallery = existingHasGallery && !currentHasGallery;

      final companion = ItemsCompanion(
        id: Value(id),
        name: Value(state.name.trim()),
        price: Value(double.tryParse(state.price) ?? 0),
        stockQty: Value(int.tryParse(state.stock) ?? 0),
        sku: Value(state.sku.isNotEmpty ? state.sku : null),
        imageUrl: Value(thumbPathOrUrl),
        publishedOnline: Value(state.publishOnline),
        categoryId: Value(state.categoryId),
        categoryName: Value(state.categoryName),
        brandId: Value(state.brandId),
        brandName: Value(state.brandName),
        unit: Value(state.unit),
        weight: Value(double.tryParse(state.weight)),
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
        discount: Value(double.tryParse(state.discount)),
        discountType: Value(state.discountType),
        shippingDays: Value(int.tryParse(state.shippingDays)),
        shippingFee: Value(double.tryParse(state.shippingFee)),
        refundable: Value(state.refundable),
        cashOnDelivery: Value(state.cashOnDelivery),
        lowStockWarning: Value(int.tryParse(state.lowStockWarning)),
        synced: const Value(false),
      );

      await db.upsertItem(companion);

      // Enqueue sync
      final opType = widget.existingItem == null ? 'item_create' : 'item_update';
      final catId = int.tryParse(state.categoryId ?? '');
      await sync.enqueue(opType, {
        'local_id': id,
        if (widget.existingItem?.remoteId != null) 'remote_id': widget.existingItem!.remoteId,
        'name': state.name.trim(),
        'unit_price': double.tryParse(state.price) ?? 0,
        'current_stock': int.tryParse(state.stock) ?? 0,
        'published': state.publishOnline ? 1 : 0,
        if (catId != null) 'category_ids': [catId],
        if (catId != null) 'category_id': catId,
        if (state.brandId != null) 'brand_id': int.tryParse(state.brandId!),
        'unit': state.unit.isNotEmpty ? state.unit : 'pc',
        if (state.weight.isNotEmpty) 'weight': double.tryParse(state.weight),
        'min_qty': int.tryParse(state.minQty) ?? 1,
        if (state.tags.isNotEmpty) 
          'tags': state.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        if (state.description.isNotEmpty) 'description': state.description,
        'discount': double.tryParse(state.discount) ?? 0,
        'discount_type': state.discountType == 'flat' ? 'amount' : 'percent',
        if (state.shippingDays.isNotEmpty) 'est_shipping_days': int.tryParse(state.shippingDays),
        if (state.shippingFee.isNotEmpty) 'shipping_cost': double.tryParse(state.shippingFee),
        'refundable': state.refundable ? 1 : 0,
        'cash_on_delivery': state.cashOnDelivery ? 1 : 0,
        if (state.lowStockWarning.isNotEmpty) 'low_stock_quantity': int.tryParse(state.lowStockWarning),
        if (state.sku.isNotEmpty) 'sku': state.sku,
      });
      unawaited(sync.syncNow());

      if (mounted) {
        ctrl.reset();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingItem == null ? 'Product created!' : 'Product updated!'),
            backgroundColor: DesignTokens.brandAccent,
          ),
        );
      }
    } catch (e) {
      ctrl.setSubmitting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: DesignTokens.error),
        );
      }
    }
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  List<int> _decodeIntList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => int.tryParse(e?.toString() ?? '')).whereType<int>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
