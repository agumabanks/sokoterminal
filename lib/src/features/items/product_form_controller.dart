import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_providers.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../core/util/image_crop_helper.dart';

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
    String? categoryId,
    String? categoryName,
    String? brandId,
    String? brandName,
    String? unit,
    String? price,
    String? cost,
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
    File? thumbnailFile,
    String? thumbnailUrl,
    int? thumbnailUploadId,
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
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
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
      thumbnailFile: thumbnailFile ?? this.thumbnailFile,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailUploadId: thumbnailUploadId ?? this.thumbnailUploadId,
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

  double? get priceValue => double.tryParse(CommaNumberFormatter.unformat(price.trim()));
  double? get costValue => cost.trim().isEmpty ? null : double.tryParse(CommaNumberFormatter.unformat(cost.trim()));
  int? get stockValue => int.tryParse(CommaNumberFormatter.unformat(stock.trim()));
  double? get discountValue =>
      discount.trim().isEmpty ? 0 : double.tryParse(CommaNumberFormatter.unformat(discount.trim()));
  int? get minQtyValue => int.tryParse(CommaNumberFormatter.unformat(minQty.trim()));
  int? get lowStockWarningValue => lowStockWarning.trim().isEmpty
      ? null
      : int.tryParse(CommaNumberFormatter.unformat(lowStockWarning.trim()));
  double? get weightValue =>
      weight.trim().isEmpty ? null : double.tryParse(CommaNumberFormatter.unformat(weight.trim()));
  int? get shippingDaysValue =>
      shippingDays.trim().isEmpty ? null : int.tryParse(CommaNumberFormatter.unformat(shippingDays.trim()));
  double? get shippingFeeValue =>
      shippingFee.trim().isEmpty ? null : double.tryParse(CommaNumberFormatter.unformat(shippingFee.trim()));

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

  bool get isImagesValid =>
      !publishOnline ||
      thumbnailFile != null ||
      (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty);

  /// Check if ready to submit
  bool get isOnlineDetailsValid {
    if (!publishOnline) return true;
    final desc = description.trim();
    if (desc.isEmpty) return false;
    if (desc.length < 10) return false;

    // Marketplace requires explicit shipping signals. Use `0` for free shipping.
    final days = shippingDaysValue;
    if (days == null) return false;
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
  final ImagePicker _imagePicker = ImagePicker();

  ProductFormController(this.ref) : super(const ProductFormState());

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

  /// Toggle publish online - triggers smart prefetch
  Future<void> setPublishOnline(bool v) async {
    state = state.copyWith(publishOnline: v);
    if (v && state.categories.isEmpty) {
      // Smart prefetch when going online
      await Future.wait([_loadCategories(), _loadBrands()]);
    }
  }

  /// Load categories from API
  Future<void> _loadCategories() async {
    if (state.isLoadingCategories) return;
    state = state.copyWith(isLoadingCategories: true);
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
      state = state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        error: 'Failed to load categories',
      );
    }
  }

  /// Load brands from API
  Future<void> _loadBrands() async {
    if (state.isLoadingBrands) return;
    state = state.copyWith(isLoadingBrands: true);
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
      state = state.copyWith(brands: brands, isLoadingBrands: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingBrands: false,
        error: 'Failed to load brands',
      );
    }
  }

  /// Requests the appropriate media/camera permission for the current platform
  /// and Android API level. Returns true if the caller may proceed.
  Future<bool> _requestMediaPermission({required bool camera}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    Permission permission;
    if (camera) {
      permission = Permission.camera;
    } else if (Platform.isAndroid) {
      // READ_MEDIA_IMAGES is the correct permission on Android 13+ (API 33+);
      // on older versions image_picker handles READ_EXTERNAL_STORAGE itself.
      final sdkInt = await _androidSdkInt();
      permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
    } else {
      permission = Permission.photos;
    }

    final status = await permission.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      // User must go to settings; surface this via error state.
      state = state.copyWith(
        error: camera
            ? 'Camera access denied. Enable it in Settings → App → Permissions.'
            : 'Photo library access denied. Enable it in Settings → App → Permissions.',
      );
    }
    return false;
  }

  /// Returns the Android SDK integer or 0 on non-Android.
  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      // permission_handler exposes this via a native channel indirectly.
      // We read it from the build info available via dart:io on Android.
      final result = Platform.operatingSystemVersion; // e.g. "4.14.117... (Android 13)"
      final match = RegExp(r'Android (\d+)').firstMatch(result);
      if (match != null) {
        final version = int.tryParse(match.group(1) ?? '') ?? 0;
        return _androidMarketingVersionToApiLevel(version);
      }
    } catch (e) {
      debugPrint('[ProductForm] Could not determine Android SDK: $e');
    }
    return 0;
  }

  /// Maps Android marketing versions (e.g. 13, 14) to API levels for permissions.
  int _androidMarketingVersionToApiLevel(int version) {
    const map = <int, int>{
      15: 35,
      14: 34,
      13: 33,
      12: 31,
      11: 30,
      10: 29,
      9: 28,
      8: 26,
      7: 24,
      6: 23,
      5: 21,
    };
    return map[version] ?? (version >= 13 ? 33 + (version - 13) : version);
  }

  /// Pick thumbnail image
  Future<void> pickThumbnail() async {
    if (!await _requestMediaPermission(camera: false)) return;
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image != null) {
      final cropped = await cropProductImage(File(image.path));
      if (cropped != null) {
        state = state.copyWith(thumbnailFile: cropped, error: null);
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
      final cropped = await cropProductImage(File(image.path));
      if (cropped != null) {
        state = state.copyWith(thumbnailFile: cropped, error: null);
      }
    }
  }

  /// Pick gallery images (multiple)
  Future<void> pickGalleryImages() async {
    if (!await _requestMediaPermission(camera: false)) return;
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 95,
    );
    if (images.isNotEmpty) {
      final files = <File>[];
      for (final x in images) {
        final cropped = await cropProductImage(File(x.path));
        if (cropped != null) files.add(cropped);
      }
      if (files.isNotEmpty) {
        state = state.copyWith(
          galleryFiles: [...state.galleryFiles, ...files],
          error: null,
        );
      }
    }
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
    String? thumbnailUrl,
    int? thumbnailUploadId,
    List<String> galleryUrls = const [],
    List<int> galleryUploadIds = const [],
    List<File> pendingGalleryFiles = const [],
    File? pendingThumbnailFile,
  }) {
    state = state.copyWith(
      thumbnailUrl: thumbnailUrl,
      thumbnailUploadId: thumbnailUploadId,
      galleryUrls: galleryUrls,
      galleryUploadIds: galleryUploadIds,
      galleryFiles: pendingGalleryFiles,
      thumbnailFile: pendingThumbnailFile,
    );
  }

  /// Remove thumbnail
  void removeThumbnail() {
    state = ProductFormState(
      name: state.name,
      categoryId: state.categoryId,
      categoryName: state.categoryName,
      brandId: state.brandId,
      brandName: state.brandName,
      unit: state.unit,
      price: state.price,
      cost: state.cost,
      stock: state.stock,
      discount: state.discount,
      discountType: state.discountType,
      sku: state.sku,
      minQty: state.minQty,
      lowStockWarning: state.lowStockWarning,
      description: state.description,
      tags: state.tags,
      shippingDays: state.shippingDays,
      shippingFee: state.shippingFee,
      weight: state.weight,
      refundable: state.refundable,
      cashOnDelivery: state.cashOnDelivery,
      publishOnline: state.publishOnline,
      thumbnailFile: null,
      thumbnailUrl: null,
      thumbnailUploadId: null,
      galleryFiles: state.galleryFiles,
      galleryUrls: state.galleryUrls,
      galleryUploadIds: state.galleryUploadIds,
      categories: state.categories,
      brands: state.brands,
      isLoadingCategories: state.isLoadingCategories,
      isLoadingBrands: state.isLoadingBrands,
      currentTab: state.currentTab,
      isSubmitting: state.isSubmitting,
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
