import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_providers.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../core/util/image_crop_helper.dart';
import '../delivery/coverage_rules.dart';

const _notProvided = Object();

/// Reactive state for product creation form
class ProductFormState {
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String? brandId;
  final String? brandName;
  final String unit;
  final String price;
  final String cost;
  final bool costUnknown;
  final Map<String, dynamic>? sellingCoverage;
  final List<String> galleryOrder;
  final String stock;
  final String discount;
  final String discountType;
  final String sku;
  final String minQty;
  final String lowStockWarning;
  final String description;
  final String tags;
  final String shippingDays;
  final String shippingFee;
  final String weight;
  final bool refundable;
  final bool cashOnDelivery;
  final bool publishOnline;

  // BNPL
  final bool bnplEnabled;
  final String bnplMinOrderAmount;
  final String bnplMaxOrderAmount;
  final String bnplInstallmentCount;

  // Tax
  final bool taxEnabled;
  final String taxRate;
  final String taxLabel;
  final String taxInclusionMode;

  // Images
  final File? thumbnailFile;
  final String? thumbnailUrl;
  final int? thumbnailUploadId;
  final List<File> galleryFiles;
  final List<String> galleryUrls;
  final List<int> galleryUploadIds;

  // Loaded data
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> brands;
  final bool isLoadingCategories;
  final bool isLoadingBrands;

  // UI State
  final int currentTab;
  final bool isSubmitting;
  final String? error;

  const ProductFormState({
    this.name = '',
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.unit = 'pc',
    this.price = '',
    this.cost = '',
    this.costUnknown = false,
    this.sellingCoverage,
    this.galleryOrder = const [],
    this.stock = '0',
    this.discount = '',
    this.discountType = 'flat',
    this.sku = '',
    this.minQty = '1',
    this.lowStockWarning = '',
    this.description = '',
    this.tags = '',
    this.shippingDays = '',
    this.shippingFee = '',
    this.weight = '',
    this.refundable = false,
    this.cashOnDelivery = true,
    this.publishOnline = false,
    this.bnplEnabled = false,
    this.bnplMinOrderAmount = '',
    this.bnplMaxOrderAmount = '',
    this.bnplInstallmentCount = '',
    this.taxEnabled = false,
    this.taxRate = '',
    this.taxLabel = 'VAT',
    this.taxInclusionMode = 'exclusive',
    this.thumbnailFile,
    this.thumbnailUrl,
    this.thumbnailUploadId,
    this.galleryFiles = const [],
    this.galleryUrls = const [],
    this.galleryUploadIds = const [],
    this.categories = const [],
    this.brands = const [],
    this.isLoadingCategories = false,
    this.isLoadingBrands = false,
    this.currentTab = 0,
    this.isSubmitting = false,
    this.error,
  });

  ProductFormState copyWith({
    String? name,
    Object? categoryId = _notProvided,
    Object? categoryName = _notProvided,
    Object? brandId = _notProvided,
    Object? brandName = _notProvided,
    String? unit,
    String? price,
    String? cost,
    bool? costUnknown,
    Object? sellingCoverage = _notProvided,
    List<String>? galleryOrder,
    String? stock,
    String? discount,
    String? discountType,
    String? sku,
    String? minQty,
    String? lowStockWarning,
    String? description,
    String? tags,
    String? shippingDays,
    String? shippingFee,
    String? weight,
    bool? refundable,
    bool? cashOnDelivery,
    bool? publishOnline,
    bool? bnplEnabled,
    String? bnplMinOrderAmount,
    String? bnplMaxOrderAmount,
    String? bnplInstallmentCount,
    bool? taxEnabled,
    String? taxRate,
    String? taxLabel,
    String? taxInclusionMode,
    Object? thumbnailFile = _notProvided,
    Object? thumbnailUrl = _notProvided,
    Object? thumbnailUploadId = _notProvided,
    List<File>? galleryFiles,
    List<String>? galleryUrls,
    List<int>? galleryUploadIds,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? brands,
    bool? isLoadingCategories,
    bool? isLoadingBrands,
    int? currentTab,
    bool? isSubmitting,
    String? error,
  }) {
    return ProductFormState(
      name: name ?? this.name,
      categoryId: identical(categoryId, _notProvided)
          ? this.categoryId
          : categoryId as String?,
      categoryName: identical(categoryName, _notProvided)
          ? this.categoryName
          : categoryName as String?,
      brandId: identical(brandId, _notProvided)
          ? this.brandId
          : brandId as String?,
      brandName: identical(brandName, _notProvided)
          ? this.brandName
          : brandName as String?,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      costUnknown: costUnknown ?? this.costUnknown,
      sellingCoverage: identical(sellingCoverage, _notProvided)
          ? this.sellingCoverage
          : sellingCoverage as Map<String, dynamic>?,
      galleryOrder: galleryOrder ?? this.galleryOrder,
      stock: stock ?? this.stock,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      sku: sku ?? this.sku,
      minQty: minQty ?? this.minQty,
      lowStockWarning: lowStockWarning ?? this.lowStockWarning,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      shippingDays: shippingDays ?? this.shippingDays,
      shippingFee: shippingFee ?? this.shippingFee,
      weight: weight ?? this.weight,
      refundable: refundable ?? this.refundable,
      cashOnDelivery: cashOnDelivery ?? this.cashOnDelivery,
      publishOnline: publishOnline ?? this.publishOnline,
      bnplEnabled: bnplEnabled ?? this.bnplEnabled,
      bnplMinOrderAmount: bnplMinOrderAmount ?? this.bnplMinOrderAmount,
      bnplMaxOrderAmount: bnplMaxOrderAmount ?? this.bnplMaxOrderAmount,
      bnplInstallmentCount: bnplInstallmentCount ?? this.bnplInstallmentCount,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      taxLabel: taxLabel ?? this.taxLabel,
      taxInclusionMode: taxInclusionMode ?? this.taxInclusionMode,
      thumbnailFile: identical(thumbnailFile, _notProvided)
          ? this.thumbnailFile
          : thumbnailFile as File?,
      thumbnailUrl: identical(thumbnailUrl, _notProvided)
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      thumbnailUploadId: identical(thumbnailUploadId, _notProvided)
          ? this.thumbnailUploadId
          : thumbnailUploadId as int?,
      galleryFiles: galleryFiles ?? this.galleryFiles,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      galleryUploadIds: galleryUploadIds ?? this.galleryUploadIds,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingBrands: isLoadingBrands ?? this.isLoadingBrands,
      currentTab: currentTab ?? this.currentTab,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  Map<String, dynamic> toDraft() => {
    'name': name,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'brandId': brandId,
    'brandName': brandName,
    'unit': unit,
    'price': price,
    'cost': cost,
    'stock': stock,
    'discount': discount,
    'discountType': discountType,
    'sku': sku,
    'minQty': minQty,
    'lowStockWarning': lowStockWarning,
    'description': description,
    'tags': tags,
    'shippingDays': shippingDays,
    'shippingFee': shippingFee,
    'weight': weight,
    'bnplMinOrderAmount': bnplMinOrderAmount,
    'bnplMaxOrderAmount': bnplMaxOrderAmount,
    'bnplInstallmentCount': bnplInstallmentCount,
    'taxRate': taxRate,
    'taxLabel': taxLabel,
    'taxInclusionMode': taxInclusionMode,
    'costUnknown': costUnknown,
    'refundable': refundable,
    'cashOnDelivery': cashOnDelivery,
    'publishOnline': publishOnline,
    'bnplEnabled': bnplEnabled,
    'taxEnabled': taxEnabled,
    'thumbnailFile': thumbnailFile?.path,
    'thumbnailUrl': thumbnailUrl,
    'thumbnailUploadId': thumbnailUploadId,
    'galleryFiles': galleryFiles.map((f) => f.path).toList(),
    'galleryUrls': galleryUrls,
    'galleryUploadIds': galleryUploadIds,
    'galleryOrder': orderedGallery,
    'sellingCoverage': sellingCoverage,
  };
  factory ProductFormState.fromDraft(Map<String, dynamic> data) =>
      ProductFormState(
        name: data['name'] as String? ?? '',
        categoryId: data['categoryId'] as String?,
        categoryName: data['categoryName'] as String?,
        brandId: data['brandId'] as String?,
        brandName: data['brandName'] as String?,
        unit: data['unit'] as String? ?? 'pc',
        price: data['price'] as String? ?? '',
        cost: data['cost'] as String? ?? '',
        stock: data['stock'] as String? ?? '0',
        discount: data['discount'] as String? ?? '',
        discountType: data['discountType'] as String? ?? 'flat',
        sku: data['sku'] as String? ?? '',
        minQty: data['minQty'] as String? ?? '1',
        lowStockWarning: data['lowStockWarning'] as String? ?? '',
        description: data['description'] as String? ?? '',
        tags: data['tags'] as String? ?? '',
        shippingDays: data['shippingDays'] as String? ?? '',
        shippingFee: data['shippingFee'] as String? ?? '',
        weight: data['weight'] as String? ?? '',
        bnplMinOrderAmount: data['bnplMinOrderAmount'] as String? ?? '',
        bnplMaxOrderAmount: data['bnplMaxOrderAmount'] as String? ?? '',
        bnplInstallmentCount: data['bnplInstallmentCount'] as String? ?? '',
        taxRate: data['taxRate'] as String? ?? '',
        taxLabel: data['taxLabel'] as String? ?? 'VAT',
        taxInclusionMode: data['taxInclusionMode'] as String? ?? 'exclusive',
        costUnknown: data['costUnknown'] == true,
        refundable: data['refundable'] == true,
        cashOnDelivery:
            data['cashOnDelivery'] == true || data['cashOnDelivery'] == null,
        publishOnline: data['publishOnline'] == true,
        bnplEnabled: data['bnplEnabled'] == true,
        taxEnabled: data['taxEnabled'] == true,
        thumbnailFile:
            data['thumbnailFile'] is String &&
                File(data['thumbnailFile']).existsSync()
            ? File(data['thumbnailFile'])
            : null,
        thumbnailUrl: data['thumbnailUrl'] as String?,
        thumbnailUploadId: data['thumbnailUploadId'] as int?,
        galleryFiles: (data['galleryFiles'] as List? ?? [])
            .cast<String>()
            .map(File.new)
            .where((f) => f.existsSync())
            .toList(),
        galleryUrls: (data['galleryUrls'] as List? ?? []).cast<String>(),
        galleryUploadIds: (data['galleryUploadIds'] as List? ?? []).cast<int>(),
        galleryOrder: (data['galleryOrder'] as List? ?? []).cast<String>(),
        sellingCoverage: data['sellingCoverage'] == null
            ? null
            : Map<String, dynamic>.from(data['sellingCoverage'] as Map),
      );

  double? get priceValue =>
      double.tryParse(CommaNumberFormatter.unformat(price.trim()));
  double? get costValue => cost.trim().isEmpty
      ? null
      : double.tryParse(CommaNumberFormatter.unformat(cost.trim()));
  int? get stockValue =>
      int.tryParse(CommaNumberFormatter.unformat(stock.trim()));
  double? get discountValue => discount.trim().isEmpty
      ? 0
      : double.tryParse(CommaNumberFormatter.unformat(discount.trim()));
  int? get minQtyValue =>
      int.tryParse(CommaNumberFormatter.unformat(minQty.trim()));
  int? get lowStockWarningValue => lowStockWarning.trim().isEmpty
      ? null
      : int.tryParse(CommaNumberFormatter.unformat(lowStockWarning.trim()));
  double? get weightValue => weight.trim().isEmpty
      ? null
      : double.tryParse(CommaNumberFormatter.unformat(weight.trim()));
  int? get shippingDaysValue => shippingDays.trim().isEmpty
      ? null
      : int.tryParse(CommaNumberFormatter.unformat(shippingDays.trim()));
  double? get shippingFeeValue => shippingFee.trim().isEmpty
      ? null
      : double.tryParse(CommaNumberFormatter.unformat(shippingFee.trim()));

  /// Check if basic info is valid
  bool get isBasicInfoValid => name.trim().isNotEmpty && unit.isNotEmpty;

  /// Check if category is valid for online
  bool get isCategoryValid => !publishOnline || categoryId != null;

  /// Check if pricing is valid
  bool get isPricingValid {
    final p = priceValue;
    final s = stockValue;
    if (p == null || p <= 0) return false;
    if (s == null || s < 0) return false;
    if (!costUnknown && costValue == null) return false;
    if (costValue != null && costValue! < 0) return false;
    return true;
  }

  bool get isDiscountValid {
    final p = priceValue;
    final d = discountValue;
    if (p == null || p <= 0) return false;
    if (d == null || d < 0) return false;
    if (discountType == 'percent') {
      return d < 100;
    }
    // flat/amount
    return d < p;
  }

  bool get isExtrasValid {
    if (coverageError(sellingCoverage) != null) return false;
    final min = minQtyValue;
    if (min == null || min < 1) return false;
    if (lowStockWarning.trim().isNotEmpty && lowStockWarningValue == null) {
      return false;
    }
    final low = lowStockWarningValue;
    if (low != null && low < 0) return false;
    if (weight.trim().isNotEmpty && weightValue == null) return false;
    final w = weightValue;
    if (w != null && w < 0) return false;
    if (shippingDays.trim().isNotEmpty && shippingDaysValue == null) {
      return false;
    }
    final days = shippingDaysValue;
    if (days != null && days < 0) return false;
    if (shippingFee.trim().isNotEmpty && shippingFeeValue == null) return false;
    final fee = shippingFeeValue;
    if (fee != null && fee < 0) return false;
    return true;
  }

  bool get hasCover =>
      thumbnailFile != null || (thumbnailUrl?.trim().isNotEmpty ?? false);
  int get galleryCount => galleryUrls.length + galleryFiles.length;
  bool get isImagesValid =>
      !publishOnline || (hasCover && galleryCount >= 3 && galleryCount <= 6);
  double? get estimatedProfit {
    if (costValue == null || priceValue == null) return null;
    final discountAmount = discountType == 'percent'
        ? priceValue! * (discountValue ?? 0) / 100
        : (discountValue ?? 0);
    var sale = priceValue! - discountAmount;
    final rate = double.tryParse(CommaNumberFormatter.unformat(taxRate)) ?? 0;
    if (taxEnabled && taxInclusionMode == 'inclusive' && rate > 0) {
      sale /= 1 + rate / 100;
    }
    return sale - costValue!;
  }

  List<String> get orderedGallery {
    final paths = [...galleryUrls, ...galleryFiles.map((f) => f.path)];
    return [
      ...galleryOrder.where(paths.contains),
      ...paths.where((p) => !galleryOrder.contains(p)),
    ];
  }

  /// Check if ready to submit
  bool get isOnlineDetailsValid {
    if (!publishOnline) return true;
    if (coverageError(sellingCoverage) != null) return false;
    final desc = description.trim();
    if (desc.isEmpty) return false;
    if (desc.length < 10) return false;

    // Marketplace requires explicit shipping signals. Use `0` for free shipping.
    final days = shippingDaysValue;
    if (days == null || days < 1) return false;
    final fee = shippingFeeValue;
    if (fee == null) return false;
    return true;
  }

  bool get canSubmit =>
      isBasicInfoValid &&
      isCategoryValid &&
      isPricingValid &&
      isDiscountValid &&
      isExtrasValid &&
      isOnlineDetailsValid &&
      isImagesValid;
}

/// Controller for product form
class ProductFormController extends StateNotifier<ProductFormState> {
  final Ref ref;
  bool _draftEnabled = false;
  late final _draftPreferences = ref.read(sharedPreferencesProvider);
  String? _draftKey;
  Timer? _draftTimer;
  final ImagePicker _imagePicker = ImagePicker();

  ProductFormController(this.ref) : super(const ProductFormState()) {
    addListener((_) {
      if (!_draftEnabled || state.isSubmitting) return;
      _draftTimer?.cancel();
      _draftTimer = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(saveDraft()),
      );
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (_draftEnabled) unawaited(saveDraft());
    super.dispose();
  }

  Future<bool> restoreDraft() async {
    final profile = await ref.read(appDatabaseProvider).getBusinessProfile();
    _draftKey = 'product_draft_v2_${profile?.sellerId ?? "local"}';
    final raw = _draftPreferences.getString(_draftKey!);
    var restored = false;
    if (raw != null) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        state = ProductFormState.fromDraft(data);
        restored = state.name.isNotEmpty || state.hasCover;
      } catch (_) {
        /* An old or incomplete draft must not block creation. */
      }
    }
    _draftEnabled = true;
    return restored;
  }

  Future<void> saveDraft() async {
    if (!_draftEnabled || _draftKey == null) return;
    await _draftPreferences.setString(_draftKey!, jsonEncode(state.toDraft()));
  }

  Future<void> discardDraft() async {
    _draftEnabled = false;
    _draftTimer?.cancel();
    if (_draftKey != null) {
      await ref.read(sharedPreferencesProvider).remove(_draftKey!);
    }
  }

  void setCostUnknown(bool value) =>
      state = state.copyWith(costUnknown: value, cost: value ? '' : state.cost);
  void setSellingCoverage(Map<String, dynamic>? value) =>
      state = state.copyWith(sellingCoverage: value);
  void reorderGallery(int oldIndex, int newIndex) {
    final order = state.orderedGallery;
    if (newIndex > oldIndex) newIndex--;
    order.insert(newIndex, order.removeAt(oldIndex));
    state = state.copyWith(galleryOrder: order);
  }

  void replaceGalleryPhoto(String path, File replacement) {
    final order = state.orderedGallery
        .map((p) => p == path ? replacement.path : p)
        .toList();
    final remote = state.galleryUrls.indexOf(path);
    if (remote >= 0) {
      final urls = [...state.galleryUrls]..removeAt(remote);
      final ids = [...state.galleryUploadIds];
      if (remote < ids.length) ids.removeAt(remote);
      state = state.copyWith(
        galleryUrls: urls,
        galleryUploadIds: ids,
        galleryFiles: [...state.galleryFiles, replacement],
        galleryOrder: order,
      );
    } else {
      replaceGalleryFile(path, replacement);
    }
  }

  Future<void> replaceGalleryFromPicker(String path) async {
    if (!await _requestMediaPermission(camera: false)) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image == null) return;
    final original = await keepOriginal(File(image.path));
    final cropped = await cropProductImage(original);
    if (cropped != null) replaceGalleryPhoto(path, await _keepEdited(cropped));
  }

  void replaceGalleryFile(String path, File replacement) {
    final files = [...state.galleryFiles];
    final index = files.indexWhere((f) => f.path == path);
    if (index < 0) return;
    files[index] = replacement;
    state = state.copyWith(
      galleryFiles: files,
      galleryOrder: state.orderedGallery
          .map((p) => p == path ? replacement.path : p)
          .toList(),
    );
  }

  void setEditedCover(File file) => state = state.copyWith(
    thumbnailFile: file,
    thumbnailUrl: null,
    thumbnailUploadId: null,
  );
  Future<File> keepOriginal(File file) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/product_photos/originals');
    await dir.create(recursive: true);
    final digest = sha256.convert(await file.readAsBytes()).toString();
    final copy = File('${dir.path}/$digest.jpg');
    if (!await copy.exists()) await file.copy(copy.path);
    return copy;
  }

  Future<File> _keepEdited(File file) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/product_photos/edits');
    await dir.create(recursive: true);
    final digest = sha256.convert(await file.readAsBytes()).toString();
    final copy = File('${dir.path}/$digest.jpg');
    if (!await copy.exists()) await file.copy(copy.path);
    return copy;
  }

  /// Load business tax settings into the form defaults.
  Future<void> loadBusinessTaxSettings() async {
    final db = ref.read(appDatabaseProvider);
    final profile = await db.getBusinessProfile();
    if (profile == null) return;
    state = state.copyWith(
      taxEnabled: profile.taxEnabled,
      taxRate: profile.taxRate > 0
          ? CommaNumberFormatter.format(profile.taxRate.toStringAsFixed(0))
          : '',
      taxLabel: profile.taxLabel,
      taxInclusionMode: profile.taxInclusionMode,
    );
  }

  // Tab navigation
  void setTab(int tab) => state = state.copyWith(currentTab: tab);

  // Basic info
  void setName(String v) => state = state.copyWith(name: v);
  void setUnit(String v) => state = state.copyWith(unit: v);
  void setWeight(String v) => state = state.copyWith(weight: v);

  // Category/Brand
  void setCategory(String? id, String? name) {
    state = state.copyWith(categoryId: id, categoryName: name);
  }

  void setBrand(String? id, String? name) {
    state = state.copyWith(brandId: id, brandName: name);
  }

  // Pricing
  void setPrice(String v) => state = state.copyWith(price: v);
  void setCost(String v) => state = state.copyWith(cost: v);
  void setStock(String v) => state = state.copyWith(stock: v);
  void setDiscount(String v) => state = state.copyWith(discount: v);
  void setDiscountType(String v) => state = state.copyWith(discountType: v);
  void setSku(String v) => state = state.copyWith(sku: v);
  void setMinQty(String v) => state = state.copyWith(minQty: v);
  void setLowStockWarning(String v) =>
      state = state.copyWith(lowStockWarning: v);

  // Description
  void setDescription(String v) => state = state.copyWith(description: v);
  void setTags(String v) => state = state.copyWith(tags: v);

  // Shipping
  void setShippingDays(String v) => state = state.copyWith(shippingDays: v);
  void setShippingFee(String v) => state = state.copyWith(shippingFee: v);
  void setRefundable(bool v) => state = state.copyWith(refundable: v);
  void setCashOnDelivery(bool v) => state = state.copyWith(cashOnDelivery: v);

  // BNPL
  void setBnplEnabled(bool v) => state = state.copyWith(bnplEnabled: v);
  void setBnplMinOrderAmount(String v) =>
      state = state.copyWith(bnplMinOrderAmount: v);
  void setBnplMaxOrderAmount(String v) =>
      state = state.copyWith(bnplMaxOrderAmount: v);
  void setBnplInstallmentCount(String v) =>
      state = state.copyWith(bnplInstallmentCount: v);

  void setTaxRate(String v) => state = state.copyWith(taxRate: v);

  /// Toggle publish online - triggers smart prefetch
  Future<void> setPublishOnline(bool v) async {
    state = state.copyWith(publishOnline: v);
    if (v && state.categories.isEmpty) {
      // Smart prefetch when going online
      await Future.wait([_loadCategories(), _loadBrands()]);
    }
  }

  /// Load categories from API, with shared-preferences cache fallback.
  Future<void> _loadCategories() async {
    if (state.isLoadingCategories) return;
    state = state.copyWith(isLoadingCategories: true);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchCategories();
      final data = res.data;
      List<Map<String, dynamic>> categories = [];
      if (data is Map && data['data'] != null) {
        categories = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        categories = List<Map<String, dynamic>>.from(data);
      }
      await prefs.setString(
        'product_categories_cache_v1',
        jsonEncode(categories),
      );
      state = state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      );
    } catch (e) {
      final cached = prefs.getString('product_categories_cache_v1');
      List<Map<String, dynamic>>? fallback;
      if (cached != null && cached.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            fallback = List<Map<String, dynamic>>.from(decoded);
          }
        } catch (_) {}
      }
      state = state.copyWith(
        categories: fallback ?? state.categories,
        isLoadingCategories: false,
        error: fallback == null ? 'Failed to load categories' : null,
      );
    }
  }

  /// Load brands from API, with shared-preferences cache fallback.
  Future<void> _loadBrands() async {
    if (state.isLoadingBrands) return;
    state = state.copyWith(isLoadingBrands: true);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchBrands();
      final data = res.data;
      List<Map<String, dynamic>> brands = [];
      if (data is Map && data['data'] != null) {
        brands = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        brands = List<Map<String, dynamic>>.from(data);
      }
      await prefs.setString('product_brands_cache_v1', jsonEncode(brands));
      state = state.copyWith(brands: brands, isLoadingBrands: false);
    } catch (e) {
      final cached = prefs.getString('product_brands_cache_v1');
      List<Map<String, dynamic>>? fallback;
      if (cached != null && cached.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            fallback = List<Map<String, dynamic>>.from(decoded);
          }
        } catch (_) {}
      }
      state = state.copyWith(
        brands: fallback ?? state.brands,
        isLoadingBrands: false,
        error: fallback == null ? 'Failed to load brands' : null,
      );
    }
  }

  /// Requests camera access when capturing a new photo. Gallery selection uses
  /// the platform photo picker and deliberately requires no broad media access.
  Future<bool> _requestMediaPermission({required bool camera}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    if (!camera) return true;

    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      // User must go to settings; surface this via error state.
      state = state.copyWith(
        error:
            'Camera access denied. Enable it in Settings → App → Permissions.',
      );
    }
    return false;
  }

  /// Pick thumbnail image
  Future<void> pickThumbnail() async {
    if (!await _requestMediaPermission(camera: false)) return;
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image != null) {
      final cropped = await cropProductImage(
        await keepOriginal(File(image.path)),
      );
      if (cropped != null) {
        state = state.copyWith(
          thumbnailFile: await _keepEdited(cropped),
          thumbnailUrl: null,
          thumbnailUploadId: null,
          error: null,
        );
      }
    }
  }

  /// Take photo for thumbnail
  Future<void> takeThumbnailPhoto() async {
    if (!await _requestMediaPermission(camera: true)) return;
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (image != null) {
      final cropped = await cropProductImage(
        await keepOriginal(File(image.path)),
      );
      if (cropped != null) {
        state = state.copyWith(
          thumbnailFile: await _keepEdited(cropped),
          thumbnailUrl: null,
          thumbnailUploadId: null,
          error: null,
        );
      }
    }
  }

  /// Pick gallery images (multiple)
  Future<void> pickGalleryImages() async {
    if (!await _requestMediaPermission(camera: false)) return;
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 95,
    );
    if (images.isEmpty) return;
    final files = <File>[];
    final signatures = <String>{};
    for (final existing in [
      ...state.galleryFiles,
      if (state.thumbnailFile != null) state.thumbnailFile!,
    ]) {
      if (await existing.exists()) {
        signatures.add(sha256.convert(await existing.readAsBytes()).toString());
      }
    }
    for (final x in images) {
      if (state.galleryCount + files.length >= 6) break;
      final original = await keepOriginal(File(x.path));
      final cropped = await cropProductImage(original);
      if (cropped == null) continue;
      final file = await _keepEdited(cropped);
      final hash = sha256.convert(await file.readAsBytes()).toString();
      if (!signatures.add(hash)) continue;
      files.add(file);
    }
    state = state.copyWith(
      galleryFiles: [...state.galleryFiles, ...files],
      error: images.length > files.length
          ? 'Up to 6 different gallery photos. Repeated or cancelled photos were skipped.'
          : null,
    );
  }

  /// Add pre-cropped gallery files directly (from custom picker)
  void addGalleryFiles(List<File> files) {
    if (files.isEmpty) return;
    state = state.copyWith(
      galleryFiles: [...state.galleryFiles, ...files],
      error: null,
    );
  }

  /// Remove gallery image
  void removeGalleryImage(int index) {
    final newList = List<File>.from(state.galleryFiles);
    if (index < newList.length) {
      newList.removeAt(index);
      state = state.copyWith(galleryFiles: newList);
    }
  }

  /// Set a gallery file as the new thumbnail
  void setGalleryFileAsThumbnail(int galleryIndex) {
    final files = List<File>.from(state.galleryFiles);
    if (galleryIndex < 0 || galleryIndex >= files.length) return;

    final selected = files.removeAt(galleryIndex);
    final oldThumbFile = state.thumbnailFile;

    // If there was an existing thumbnail, move it to gallery
    if (oldThumbFile != null) {
      files.add(oldThumbFile);
    }

    state = state.copyWith(
      thumbnailFile: selected,
      thumbnailUrl: null,
      thumbnailUploadId: null,
      galleryFiles: files,
    );
  }

  /// Set an existing remote gallery image as thumbnail
  void setGalleryUrlAsThumbnail(int urlIndex) {
    final urls = List<String>.from(state.galleryUrls);
    final ids = List<int>.from(state.galleryUploadIds);
    if (urlIndex < 0 || urlIndex >= urls.length) return;

    final selectedUrl = urls.removeAt(urlIndex);
    int? selectedId;
    if (urlIndex < ids.length) {
      selectedId = ids.removeAt(urlIndex);
    }

    final oldThumbFile = state.thumbnailFile;
    final oldThumbUrl = state.thumbnailUrl;
    final oldThumbId = state.thumbnailUploadId;

    // Move old thumbnail to gallery if it exists
    if (oldThumbUrl != null && oldThumbUrl.isNotEmpty) {
      urls.add(oldThumbUrl);
      if (oldThumbId != null) ids.add(oldThumbId);
    } else if (oldThumbFile != null) {
      state = state.copyWith(
        galleryFiles: [...state.galleryFiles, oldThumbFile],
      );
    }

    state = state.copyWith(
      thumbnailFile: null,
      thumbnailUrl: selectedUrl,
      thumbnailUploadId: selectedId,
      galleryUrls: urls,
      galleryUploadIds: ids,
    );
  }

  void removeExistingGalleryImage(int index) {
    final urls = List<String>.from(state.galleryUrls);
    final ids = List<int>.from(state.galleryUploadIds);
    if (index < 0 || index >= urls.length) return;
    urls.removeAt(index);
    if (index < ids.length) ids.removeAt(index);
    state = state.copyWith(galleryUrls: urls, galleryUploadIds: ids);
  }

  void setExistingImages({
    Object? thumbnailUrl = _notProvided,
    Object? thumbnailUploadId = _notProvided,
    List<String> galleryUrls = const [],
    List<int> galleryUploadIds = const [],
    List<File> pendingGalleryFiles = const [],
    List<String> orderedPaths = const [],
    File? pendingThumbnailFile,
  }) {
    state = state.copyWith(
      thumbnailUrl: thumbnailUrl,
      thumbnailUploadId: thumbnailUploadId,
      galleryUrls: galleryUrls,
      galleryUploadIds: galleryUploadIds,
      galleryFiles: pendingGalleryFiles,
      galleryOrder: orderedPaths,
      thumbnailFile: pendingThumbnailFile,
    );
  }

  /// Remove thumbnail while preserving all other form state, including tax.
  void removeThumbnail() {
    state = state.copyWith(
      thumbnailFile: null,
      thumbnailUrl: null,
      thumbnailUploadId: null,
    );
  }

  /// Auto-generate a unique SKU based on product name
  String generateUniqueSKU() {
    final name = state.name.trim();
    if (name.isEmpty) {
      return 'PROD-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    }

    // Extract first 3-4 letters from product name
    final letters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix = letters.isEmpty
        ? 'PROD'
        : letters.substring(0, letters.length < 4 ? letters.length : 4);

    // Add timestamp for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$prefix-$timestamp';
  }

  /// Check if SKU already exists locally (for editing, pass current item ID to exclude)
  Future<bool> isDuplicateSKU(String sku, {String? excludeItemId}) async {
    if (sku.trim().isEmpty) return false;

    final db = ref.read(appDatabaseProvider);
    final existing = await (db.select(
      db.items,
    )..where((t) => t.sku.equals(sku.trim()))).get();

    if (existing.isEmpty) return false;

    // If editing, exclude current item from check
    if (excludeItemId != null) {
      return existing.any((item) => item.id != excludeItemId);
    }

    return true;
  }

  /// Auto-generate and set unique SKU
  Future<void> autoGenerateSKU() async {
    var sku = generateUniqueSKU();

    // Ensure it's truly unique (rare collision case)
    while (await isDuplicateSKU(sku)) {
      await Future.delayed(const Duration(milliseconds: 100));
      sku = generateUniqueSKU();
    }

    setSku(sku);
  }

  /// Validate SKU before save - returns error message if invalid, null if valid
  Future<String?> validateSKU({String? editingItemId}) async {
    final sku = state.sku.trim();

    // SKU is optional - if empty, will auto-generate on save
    if (sku.isEmpty) return null;

    // Check for duplicate
    if (await isDuplicateSKU(sku, excludeItemId: editingItemId)) {
      final suggested = generateUniqueSKU();
      return 'SKU "$sku" already exists. Try: $suggested';
    }

    return null;
  }

  /// Reset form

  void reset() => state = const ProductFormState();

  /// Set submitting state
  void setSubmitting(bool v) => state = state.copyWith(isSubmitting: v);

  /// Clear error
  void clearError() => state = state.copyWith(error: null);
}

/// Provider for product form
final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormController, ProductFormState>(
      (ref) => ProductFormController(ref),
    );
