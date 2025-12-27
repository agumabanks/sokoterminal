import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_providers.dart';

/// Reactive state for product creation form
class ProductFormState {
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String? brandId;
  final String? brandName;
  final String unit;
  final String price;
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
  
  double? get priceValue => double.tryParse(price.trim());
  int? get stockValue => int.tryParse(stock.trim());
  double? get discountValue =>
      discount.trim().isEmpty ? 0 : double.tryParse(discount.trim());
  int? get minQtyValue => int.tryParse(minQty.trim());
  int? get lowStockWarningValue =>
      lowStockWarning.trim().isEmpty ? null : int.tryParse(lowStockWarning.trim());
  double? get weightValue =>
      weight.trim().isEmpty ? null : double.tryParse(weight.trim());
  int? get shippingDaysValue =>
      shippingDays.trim().isEmpty ? null : int.tryParse(shippingDays.trim());
  double? get shippingFeeValue =>
      shippingFee.trim().isEmpty ? null : double.tryParse(shippingFee.trim());

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
    if (shippingDays.trim().isNotEmpty && shippingDaysValue == null) return false;
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
  void setStock(String v) => state = state.copyWith(stock: v);
  void setDiscount(String v) => state = state.copyWith(discount: v);
  void setDiscountType(String v) => state = state.copyWith(discountType: v);
  void setSku(String v) => state = state.copyWith(sku: v);
  void setMinQty(String v) => state = state.copyWith(minQty: v);
  void setLowStockWarning(String v) => state = state.copyWith(lowStockWarning: v);
  
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
      await Future.wait([
        _loadCategories(),
        _loadBrands(),
      ]);
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
      state = state.copyWith(categories: categories, isLoadingCategories: false);
    } catch (e) {
      state = state.copyWith(isLoadingCategories: false, error: 'Failed to load categories');
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
      state = state.copyWith(isLoadingBrands: false, error: 'Failed to load brands');
    }
  }
  
  /// Pick thumbnail image
  Future<void> pickThumbnail() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      state = state.copyWith(thumbnailFile: File(image.path));
    }
  }
  
  /// Take photo for thumbnail
  Future<void> takeThumbnailPhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      state = state.copyWith(thumbnailFile: File(image.path));
    }
  }
  
  /// Pick gallery images (multiple)
  Future<void> pickGalleryImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      final files = images.map((x) => File(x.path)).toList();
      state = state.copyWith(
        galleryFiles: [...state.galleryFiles, ...files],
      );
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
  
  /// Reset form
  void reset() => state = const ProductFormState();
  
  /// Set submitting state
  void setSubmitting(bool v) => state = state.copyWith(isSubmitting: v);
  
  /// Clear error
  void clearError() => state = state.copyWith(error: null);
}

/// Provider for product form
final productFormProvider = StateNotifierProvider.autoDispose<ProductFormController, ProductFormState>(
  (ref) => ProductFormController(ref),
);
