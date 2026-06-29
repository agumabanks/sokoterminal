import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../core/util/formatters.dart';
import '../../core/util/image_crop_helper.dart';
import '../../core/util/service_html_utils.dart';
import '../../core/util/service_pricing_utils.dart';
import '../../core/util/service_publish_utils.dart';
import 'service_categories_provider.dart';
import 'service_package_tiers_section.dart';
import '../bnpl/models/bnpl_seller_status.dart';
import '../bnpl/models/service_bnpl_payload.dart';
import '../bnpl/providers/bnpl_seller_status_provider.dart';
import '../bnpl/providers/service_bnpl_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/html_editor.dart';
import '../ads/studio_editor_launcher.dart';
import '../items/gallery_picker_screen.dart';
import '../../widgets/offline_cached_image.dart';
import '../../widgets/service_description_article.dart';

const _deliveryTimeframes = [
  '1 day',
  '2 days',
  '3 days',
  '5 days',
  '7 days',
  '14 days',
  '21 days',
  '30 days',
  '45 days',
  '60 days',
  '90 days',
];

const _serviceTypes = <String, String>{
  'virtual': 'Virtual / Online',
  'onsite': 'On-site',
  'hybrid': 'Hybrid',
};

/// Helper to unify remote and local gallery items in the service editor grid.
class _GalleryItem {
  const _GalleryItem._({
    required this.isRemote,
    required this.index,
    this.remoteUrl,
    this.localFile,
  });

  factory _GalleryItem.remote(String url, int index) {
    return _GalleryItem._(
      isRemote: true,
      index: index,
      remoteUrl: url,
    );
  }

  factory _GalleryItem.local(File file, int index) {
    return _GalleryItem._(
      isRemote: false,
      index: index,
      localFile: file,
    );
  }

  final bool isRemote;
  final int index;
  final String? remoteUrl;
  final File? localFile;
}

/// Full-screen service create/edit form — mirrors the product editor UX.
class ServiceEditScreen extends ConsumerStatefulWidget {
  const ServiceEditScreen({super.key, this.existingService});

  final Service? existingService;

  bool get isEditing => existingService != null;

  @override
  ConsumerState<ServiceEditScreen> createState() => _ServiceEditScreenState();
}

class _ServiceEditScreenState extends ConsumerState<ServiceEditScreen> {
  final _scrollController = ScrollController();
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  int? _categoryId;
  String? _categoryName;
  String _serviceType = 'virtual';
  String _deliveryTimeframe = '7 days';
  String? _moderationStatus;
  List<ServicePricingTier> _pricingTiers = ServicePricingTier.emptyTiers();
  String _descriptionHtml = '';
  File? _coverFile;
  String? _coverUrl;
  int? _coverUploadId;
  final List<File> _galleryFiles = [];
  final List<String> _galleryUrls = [];
  final List<int> _galleryUploadIds = [];
  bool _publishOnline = true;
  bool _isSaving = false;

  // BNPL
  bool _bnplEnabled = false;
  final _bnplMinCtrl = TextEditingController();
  final _bnplMaxCtrl = TextEditingController();
  final _bnplInstallmentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrateFromExisting();
    unawaited(_loadBnplSettingsIfNeeded());
  }

  void _hydrateFromExisting() {
    final service = widget.existingService;
    if (service == null) return;

    _titleCtrl.text = service.title;
    _summaryCtrl.text = service.summary ?? '';
    _categoryId = service.categoryId;
    _categoryName = service.category;
    _serviceType = service.serviceType?.trim().isNotEmpty == true
        ? service.serviceType!.trim()
        : 'virtual';
    _deliveryTimeframe = service.deliveryTimeframe?.trim().isNotEmpty == true
        ? service.deliveryTimeframe!.trim()
        : '7 days';
    _moderationStatus = service.moderationStatus;
    _pricingTiers = decodePricingPackages(service.pricingPackages);
    _priceCtrl.text = CommaNumberFormatter.format(service.price.toStringAsFixed(0));
    if (service.cost != null) {
      _costCtrl.text = CommaNumberFormatter.format(service.cost!.toStringAsFixed(0));
    }
    if (service.durationMinutes != null) {
      _durationCtrl.text =
          CommaNumberFormatter.format(service.durationMinutes!.toString());
    }
    _descriptionHtml =
        normalizeServiceDescriptionHtml(service.description);
    _coverUrl = service.imageUrl;
    _coverUploadId = service.coverUploadId;
    _publishOnline = service.publishedOnline;

    final galleryUrlsAll = _decodeStringList(service.galleryUrls);
    final galleryIdsAll = _decodeIntList(service.galleryUploadIds);
    final remoteCount = galleryIdsAll.length < galleryUrlsAll.length
        ? galleryIdsAll.length
        : galleryUrlsAll.length;
    _galleryUrls.addAll(galleryUrlsAll.take(remoteCount));
    _galleryUploadIds.addAll(galleryIdsAll.take(remoteCount));
    _galleryFiles.addAll(
      galleryUrlsAll
          .skip(remoteCount)
          .map((p) => File(p))
          .where((f) => f.existsSync()),
    );

    final raw = service.imageUrl?.trim();
    if (raw != null && raw.isNotEmpty && !raw.startsWith('http')) {
      final file = File(raw);
      if (file.existsSync()) {
        _coverFile = file;
      }
    }
  }

  Future<void> _loadBnplSettingsIfNeeded() async {
    final serviceId = widget.existingService?.remoteId;
    if (serviceId == null) return;

    try {
      final payload = await ref.read(serviceBnplProvider(serviceId).future);
      if (payload == null || !mounted) return;

      setState(() {
        _bnplEnabled = payload.enabled;
        _bnplMinCtrl.text = payload.minOrderAmount != null
            ? CommaNumberFormatter.format(payload.minOrderAmount!.toStringAsFixed(0))
            : '';
        _bnplMaxCtrl.text = payload.maxOrderAmount != null
            ? CommaNumberFormatter.format(payload.maxOrderAmount!.toStringAsFixed(0))
            : '';
        _bnplInstallmentCtrl.text = payload.installmentCount != null
            ? payload.installmentCount.toString()
            : '';
      });
    } catch (_) {
      // Best effort — backend may not have the endpoint yet.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _durationCtrl.dispose();
    _bnplMinCtrl.dispose();
    _bnplMaxCtrl.dispose();
    _bnplInstallmentCtrl.dispose();
    super.dispose();
  }

  bool get _hasCover =>
      _coverFile != null || (_coverUrl?.trim().isNotEmpty ?? false);

  bool get _canSave {
    final title = _titleCtrl.text.trim();
    final price = double.tryParse(
          CommaNumberFormatter.unformat(_priceCtrl.text.trim()),
        ) ??
        0;
    return title.isNotEmpty &&
        price > 0 &&
        _publishChecklistComplete &&
        !_isSaving;
  }

  bool get _publishChecklistComplete =>
      !_publishOnline ||
      (_categoryId != null &&
          _summaryCtrl.text.trim().length >= 10 &&
          _deliveryTimeframe.trim().isNotEmpty &&
          _descriptionHtml.plainText.trim().length >= 20 &&
          _hasCover);

  String? get _validationHint {
    if (_titleCtrl.text.trim().isEmpty) return 'Add a service name';
    final price = double.tryParse(
      CommaNumberFormatter.unformat(_priceCtrl.text.trim()),
    );
    if (price == null || price <= 0) return 'Enter a valid selling price';
    if (_publishOnline && _categoryId == null) {
      return 'Choose a category to publish online';
    }
    if (_publishOnline && _summaryCtrl.text.trim().length < 10) {
      return 'Add a short summary (10+ characters) for your shop listing';
    }
    if (_publishOnline && _deliveryTimeframe.trim().isEmpty) {
      return 'Select a delivery timeframe';
    }
    if (_publishOnline && !_hasCover) {
      return 'Add a cover photo to publish online';
    }
    if (_publishOnline && _descriptionHtml.plainText.trim().length < 20) {
      return 'Online listings work best with at least 20 characters of description';
    }
    return null;
  }

  String? get _coverImageUrl {
    if (_coverFile != null) return _coverFile!.path;
    return _coverUrl;
  }

  Future<void> _pickCover({required bool camera}) async {
    final ok = await _requestImagePermission(camera: camera);
    if (!ok || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;

    final cropped = await cropProductImage(File(picked.path));
    if (cropped == null || !mounted) return;
    setState(() {
      _coverFile = cropped;
      _coverUrl = cropped.path;
      _coverUploadId = null;
    });
  }

  Future<void> _pickGalleryImages() async {
    final ok = await _requestImagePermission(camera: false);
    if (!ok || !mounted) return;

    final files = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (_) => const GalleryPickerScreen(),
      ),
    );
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _galleryFiles.addAll(files));
  }

  Future<void> _designCoverInStudio() async {
    final title = _titleCtrl.text.trim();
    final price = double.tryParse(
      CommaNumberFormatter.unformat(_priceCtrl.text.trim()),
    );
    final tempService = Service(
      id: widget.existingService?.id ?? const Uuid().v4(),
      title: title.isEmpty ? 'New Service' : title,
      price: price ?? 0,
      publishedOnline: _publishOnline,
      updatedAt: DateTime.now().toUtc(),
      synced: false,
      imageUrl: _coverUrl,
      category: _categoryName,
      remoteId: widget.existingService?.remoteId,
    );
    final file = await launchStudioForService(
      context,
      ref,
      service: tempService,
    );
    if (file != null && mounted) {
      setState(() {
        _coverFile = file;
        _coverUrl = file.path;
        _coverUploadId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover designed in Studio')),
      );
    }
  }

  void _removeCover() {
    setState(() {
      _coverFile = null;
      _coverUrl = null;
      _coverUploadId = null;
    });
  }

  void _removeGalleryFile(int index) {
    if (index < 0 || index >= _galleryFiles.length) return;
    setState(() => _galleryFiles.removeAt(index));
  }

  void _removeGalleryUrl(int index) {
    if (index < 0 || index >= _galleryUrls.length) return;
    setState(() {
      _galleryUrls.removeAt(index);
      if (index < _galleryUploadIds.length) {
        _galleryUploadIds.removeAt(index);
      }
    });
  }

  void _setGalleryFileAsCover(int galleryIndex) {
    if (galleryIndex < 0 || galleryIndex >= _galleryFiles.length) return;
    setState(() {
      final selected = _galleryFiles.removeAt(galleryIndex);
      final oldCoverFile = _coverFile;
      final oldCoverUrl = _coverUrl;
      final oldCoverUploadId = _coverUploadId;

      _coverFile = selected;
      _coverUrl = selected.path;
      _coverUploadId = null;

      if (oldCoverUrl != null && oldCoverUrl.startsWith('http')) {
        _galleryUrls.add(oldCoverUrl);
        if (oldCoverUploadId != null) _galleryUploadIds.add(oldCoverUploadId);
      } else if (oldCoverFile != null) {
        _galleryFiles.add(oldCoverFile);
      }
    });
  }

  void _setGalleryUrlAsCover(int urlIndex) {
    if (urlIndex < 0 || urlIndex >= _galleryUrls.length) return;
    setState(() {
      final selectedUrl = _galleryUrls.removeAt(urlIndex);
      int? selectedId;
      if (urlIndex < _galleryUploadIds.length) {
        selectedId = _galleryUploadIds.removeAt(urlIndex);
      }

      final oldCoverFile = _coverFile;
      final oldCoverUrl = _coverUrl;
      final oldCoverUploadId = _coverUploadId;

      _coverUrl = selectedUrl;
      _coverUploadId = selectedId;
      _coverFile = null;

      if (oldCoverUrl != null && oldCoverUrl.isNotEmpty) {
        if (oldCoverUrl.startsWith('http')) {
          _galleryUrls.add(oldCoverUrl);
          if (oldCoverUploadId != null) _galleryUploadIds.add(oldCoverUploadId);
        } else if (oldCoverFile != null) {
          _galleryFiles.add(oldCoverFile);
        }
      }
    });
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pickCover(camera: true));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pickCover(camera: false));
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_outlined),
              title: const Text('Add gallery photos'),
              subtitle: const Text('Grid multi-select from device'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_pickGalleryImages());
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: DesignTokens.brandAccent),
              title: const Text('Design cover in Studio'),
              subtitle: const Text('Create a promo image with your service details'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_designCoverInStudio());
              },
            ),
            if (_hasCover)
              ListTile(
                leading: Icon(Icons.delete_outline, color: DesignTokens.error),
                title: Text('Remove main photo', style: TextStyle(color: DesignTokens.error)),
                onTap: () {
                  Navigator.pop(context);
                  _removeCover();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    final service = widget.existingService;
    final title = _titleCtrl.text.trim();
    final summary = _summaryCtrl.text.trim();
    final price = double.parse(
      CommaNumberFormatter.unformat(_priceCtrl.text.trim()),
    );
    final cost = double.tryParse(
      CommaNumberFormatter.unformat(_costCtrl.text.trim()),
    );
    final durationMinutes = int.tryParse(
      CommaNumberFormatter.unformat(_durationCtrl.text.trim()),
    );
    final description = prepareServiceDescriptionForSave(_descriptionHtml);
    final coverUrl = _coverImageUrl;

    final pendingGalleryPaths = _galleryFiles.map((f) => f.path).toList();
    final combinedGalleryUrls = [..._galleryUrls, ...pendingGalleryPaths];
    final galleryJson =
        combinedGalleryUrls.isNotEmpty ? jsonEncode(combinedGalleryUrls) : null;
    final galleryIdsJson =
        _galleryUploadIds.isNotEmpty ? jsonEncode(_galleryUploadIds) : null;
    final pricingPackagesJson = encodePricingPackages(_pricingTiers);
    final packagesForApi = pricingPackagesForApi(_pricingTiers);

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final id = service?.id ?? const Uuid().v4();

    final syncPayload = <String, dynamic>{
      'local_id': id,
      'title': title,
      if (summary.isNotEmpty) 'summary': summary,
      'description': description,
      'base_price': price,
      if (cost != null) 'purchase_price': cost,
      if (_categoryId != null) 'category_id': _categoryId,
      'service_type': _serviceType,
      'delivery_timeframe': _deliveryTimeframe,
      if (coverUrl != null) 'image_url': coverUrl,
      'duration_minutes': durationMinutes,
      if (packagesForApi.isNotEmpty) 'packages': packagesForApi,
      'is_published': _publishOnline,
    };

    try {
      final opType = service?.remoteId != null ? 'service_update' : 'service_create';
      final payload = service?.remoteId != null
          ? {...syncPayload, 'remote_id': service!.remoteId}
          : syncPayload;

      final companion = service == null
          ? ServicesCompanion.insert(
              id: Value(id),
              title: title,
              price: price,
              cost: cost != null ? Value(cost) : const Value.absent(),
              summary: Value(summary.isEmpty ? null : summary),
              categoryId: Value(_categoryId),
              category: Value(_categoryName),
              serviceType: Value(_serviceType),
              deliveryTimeframe: Value(_deliveryTimeframe),
              pricingPackages: Value(pricingPackagesJson),
              description: Value(description.isEmpty ? null : description),
              durationMinutes: Value(durationMinutes),
              publishedOnline: Value(_publishOnline),
              synced: const Value(false),
              updatedAt: Value(DateTime.now().toUtc()),
              imageUrl: Value(coverUrl),
              coverUploadId: _coverUploadId != null
                  ? Value(_coverUploadId)
                  : const Value.absent(),
              galleryUrls: galleryJson != null
                  ? Value(galleryJson)
                  : const Value.absent(),
              galleryUploadIds: galleryIdsJson != null
                  ? Value(galleryIdsJson)
                  : const Value.absent(),
            )
          : service.toCompanion(true).copyWith(
              title: Value(title),
              price: Value(price),
              cost: cost != null ? Value(cost) : const Value(null),
              summary: Value(summary.isEmpty ? null : summary),
              categoryId: Value(_categoryId),
              category: Value(_categoryName),
              serviceType: Value(_serviceType),
              deliveryTimeframe: Value(_deliveryTimeframe),
              pricingPackages: Value(pricingPackagesJson),
              description: Value(description.isEmpty ? null : description),
              durationMinutes: Value(durationMinutes),
              publishedOnline: Value(_publishOnline),
              synced: const Value(false),
              updatedAt: Value(DateTime.now().toUtc()),
              imageUrl: Value(coverUrl),
              coverUploadId: Value(_coverUploadId),
              galleryUrls: Value(galleryJson),
              galleryUploadIds: Value(galleryIdsJson),
            );

      await db.saveServiceAndEnqueueSync(
        service: companion,
        syncPayload: payload,
        opType: opType,
      );
      unawaited(sync.syncCatalogImmediately());

      // Push BNPL settings to the server when editing an already-synced service.
      final serviceId = service?.remoteId;
      if (serviceId != null) {
        try {
          final bnplPayload = ServiceBnplPayload(
            enabled: _bnplEnabled,
            minOrderAmount: _bnplMinCtrl.text.isEmpty
                ? null
                : double.tryParse(CommaNumberFormatter.unformat(_bnplMinCtrl.text)),
            maxOrderAmount: _bnplMaxCtrl.text.isEmpty
                ? null
                : double.tryParse(CommaNumberFormatter.unformat(_bnplMaxCtrl.text)),
            installmentCount: _bnplInstallmentCtrl.text.isEmpty
                ? null
                : int.tryParse(CommaNumberFormatter.unformat(_bnplInstallmentCtrl.text)),
          );
          await ref.read(sellerApiProvider).updateServiceBnpl(serviceId, bnplPayload);
        } catch (e) {
          debugPrint('[ServiceEditScreen] BNPL update failed: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: DesignTokens.error),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          servicePublishSnackbarMessage(
            publishing: _publishOnline,
            moderationStatus: _publishOnline ? 'pending' : null,
          ),
        ),
        backgroundColor: DesignTokens.brandAccent,
        duration: _publishOnline
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final narrow = screenWidth < 380;
    final bnplStatus = ref.watch(bnplSellerStatusProvider).valueOrNull;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.isEditing ? 'Edit Service' : 'New Service',
          style: DesignTokens.textHeadline.copyWith(fontSize: 17),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhotoSection(),
                if (_galleryUrls.isNotEmpty || _galleryFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildGalleryStrip(),
                ],
                const SizedBox(height: 8),
                _buildPublishCard(),
                if (_moderationStatus == 'pending') ...[
                  const SizedBox(height: 8),
                  _buildModerationBanner(),
                ],
                const SizedBox(height: 8),
                _buildSection(
                  icon: Icons.room_service_outlined,
                  title: 'Service Details',
                  child: Column(
                    children: [
                      AppInput(
                        controller: _titleCtrl,
                        label: 'Service name',
                        hint: 'e.g. Logo design package',
                        prefixIcon: Icons.label_outline,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        controller: _summaryCtrl,
                        label: 'Short summary',
                        hint: 'One-line pitch for your shop listing',
                        prefixIcon: Icons.short_text_outlined,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryPicker(),
                      const SizedBox(height: 16),
                      _buildServiceTypePicker(),
                      const SizedBox(height: 16),
                      _buildDeliveryTimeframePicker(),
                      const SizedBox(height: 16),
                      if (narrow)
                        Column(
                          children: [
                            AppInput(
                              controller: _priceCtrl,
                              label: 'Selling price (UGX)',
                              hint: '150,000',
                              prefixIcon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [CommaNumberFormatter()],
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            AppInput(
                              controller: _durationCtrl,
                              label: 'Duration (min)',
                              hint: '60',
                              prefixIcon: Icons.schedule_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [CommaNumberFormatter()],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: AppInput(
                                controller: _priceCtrl,
                                label: 'Selling price (UGX)',
                                hint: '150,000',
                                prefixIcon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: const [CommaNumberFormatter()],
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppInput(
                                controller: _durationCtrl,
                                label: 'Duration (min)',
                                hint: '60',
                                prefixIcon: Icons.schedule_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: const [CommaNumberFormatter()],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      AppInput(
                        controller: _costCtrl,
                        label: 'Cost / buying price (UGX)',
                        hint: 'Optional',
                        prefixIcon: Icons.shopping_bag_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [CommaNumberFormatter()],
                      ),
                      if (_galleryUrls.isEmpty && _galleryFiles.isEmpty) ...[
                        const SizedBox(height: 16),
                        _buildAddGalleryPrompt(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildSection(
                  icon: Icons.payments_outlined,
                  title: 'Sanaa Finance BNPL',
                  subtitle: 'Let buyers pay later',
                  child: _buildBnplSection(bnplStatus),
                ),
                const SizedBox(height: 8),
                _buildSection(
                  icon: Icons.layers_outlined,
                  title: 'Marketplace packages',
                  subtitle: 'Optional Basic / Standard / Premium tiers',
                  child: ServicePackageTiersSection(
                    tiers: _pricingTiers,
                    onChanged: (tiers) => setState(() => _pricingTiers = tiers),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSection(
                  icon: Icons.description_outlined,
                  title: 'Description',
                  subtitle: 'Blog-style listing shown on your online shop',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HtmlEditor(
                        initialHtml: _descriptionHtml,
                        initialMode: HtmlEditorMode.plain,
                        label: 'What does the client get?',
                        placeholder:
                            'Describe deliverables, turnaround, and what makes this service valuable…',
                        helperText:
                            'Tap Rich for headings, lists, and paste from web or docs.',
                        minHeight: 180,
                        onChanged: (html) {
                          _descriptionHtml = html;
                          setState(() {});
                        },
                      ),
                      if (_descriptionHtml.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DesignTokens.canvasCloud,
                            borderRadius: DesignTokens.borderRadiusMd,
                            border: Border.all(color: DesignTokens.hairline),
                          ),
                          child: ServiceDescriptionArticle(
                            title: 'Shop preview',
                            html: _descriptionHtml,
                            compact: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 100 + bottomInset),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  Widget _buildPhotoSection() {
    final hasCover = _hasCover;
    final isSynced =
        _coverUploadId != null || (_coverUrl?.startsWith('http') == true);

    return GestureDetector(
      onTap: _showPhotoOptions,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: DesignTokens.durationNormal,
            height: 240,
            width: double.infinity,
            color: hasCover ? Colors.black : DesignTokens.canvasCloud,
            child: hasCover ? _buildCoverImage() : _buildPhotoPlaceholder(),
          ),
          if (hasCover)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 72,
                decoration: const BoxDecoration(
                  gradient: DesignTokens.photoScrimBottom,
                ),
              ),
            ),
          if (hasCover)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: DesignTokens.borderRadiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        isSynced ? 'Change photo' : 'Tap to change photo',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (hasCover)
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: _removeCover,
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

  Widget _buildCoverImage() {
    if (_coverFile != null) {
      return Image.file(_coverFile!, fit: BoxFit.cover, width: double.infinity);
    }
    final url = _coverUrl?.trim();
    if (url != null && url.startsWith('http')) {
      return OfflineCachedImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 240,
        placeholder: _buildPhotoPlaceholder(),
        errorWidget: _buildPhotoPlaceholder(),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 40, color: DesignTokens.inkMuted),
        const SizedBox(height: 8),
        Text('Add service photo', style: DesignTokens.textBodyBold),
        const SizedBox(height: 4),
        Text('Tap to shoot, choose, or add gallery', style: DesignTokens.textSmall),
      ],
    );
  }

  Widget _buildAddGalleryPrompt() {
    return GestureDetector(
      onTap: _pickGalleryImages,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignTokens.brandPrimary.withValues(alpha: 0.04),
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.collections_outlined,
                color: DesignTokens.brandPrimary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add gallery photos',
                    style: DesignTokens.textBodyBold.copyWith(
                      color: DesignTokens.brandPrimary,
                    ),
                  ),
                  Text(
                    'Show more angles — each photo is cropped',
                    style: DesignTokens.textSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryStrip() {
    final total = _galleryUrls.length + _galleryFiles.length;
    final items = <_GalleryItem>[];
    for (var i = 0; i < _galleryUrls.length; i++) {
      items.add(_GalleryItem.remote(_galleryUrls[i], i));
    }
    for (var i = 0; i < _galleryFiles.length; i++) {
      items.add(_GalleryItem.local(_galleryFiles[i], i));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gallery photos', style: DesignTokens.textSmallBold),
              if (total > 0)
                Text('$total added', style: DesignTokens.textSmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == items.length) {
                return GestureDetector(
                  onTap: _pickGalleryImages,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: DesignTokens.brandPrimary.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: DesignTokens.brandPrimary.withValues(alpha: 0.04),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: DesignTokens.brandPrimary),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: DesignTokens.brandPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = items[i];
              return GestureDetector(
                onTap: () => _showGalleryItemMenu(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.isRemote
                              ? DesignTokens.brandAccent.withValues(alpha: 0.6)
                              : DesignTokens.hairline,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.isRemote
                            ? OfflineCachedImage(
                                imageUrl: item.remoteUrl!,
                                fit: BoxFit.cover,
                                errorWidget: const SizedBox(),
                              )
                            : Image.file(
                                item.localFile!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    if (!item.isRemote)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DesignTokens.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => item.isRemote
                            ? _removeGalleryUrl(item.index)
                            : _removeGalleryFile(item.index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showGalleryItemMenu(_GalleryItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.preview_outlined),
              title: const Text('Preview'),
              onTap: () {
                Navigator.pop(context);
                _previewImage(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined,
                  color: DesignTokens.brandPrimary),
              title: const Text('Set as main photo'),
              onTap: () {
                Navigator.pop(context);
                if (item.isRemote) {
                  _setGalleryUrlAsCover(item.index);
                } else {
                  _setGalleryFileAsCover(item.index);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: DesignTokens.error),
              title: Text('Remove', style: TextStyle(color: DesignTokens.error)),
              onTap: () {
                Navigator.pop(context);
                item.isRemote
                    ? _removeGalleryUrl(item.index)
                    : _removeGalleryFile(item.index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _previewImage(_GalleryItem item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: item.isRemote
                  ? OfflineCachedImage(
                      imageUrl: item.remoteUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Image.file(item.localFile!, fit: BoxFit.contain),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.warning.withValues(alpha: 0.08),
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_outlined, color: DesignTokens.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Awaiting approval', style: DesignTokens.textBodyBold),
                const SizedBox(height: 2),
                Text(
                  'Your service is in the moderation queue. It will appear on the shop once approved.',
                  style: DesignTokens.textSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final hasError = _publishOnline && _categoryId == null;
    final categoriesAsync = ref.watch(serviceCategoriesProvider);

    return GestureDetector(
      onTap: () => _showCategoryPicker(categoriesAsync),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Category',
          prefixIcon: const Icon(Icons.category_outlined),
          errorText: hasError ? 'Required for online listing' : null,
          border: OutlineInputBorder(borderRadius: DesignTokens.borderRadiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _categoryName ?? 'Select category',
                style: DesignTokens.textBody.copyWith(
                  color: _categoryName != null
                      ? DesignTokens.textPrimary
                      : DesignTokens.grayMedium,
                ),
              ),
            ),
            if (categoriesAsync.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, color: DesignTokens.inkMuted),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(AsyncValue<List<ServiceCategoryOption>> categoriesAsync) {
    categoriesAsync.when(
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading categories…')),
        );
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load categories: $e')),
        );
      },
      data: (categories) {
        if (categories.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No categories available yet')),
          );
          return;
        }
        showModalBottomSheet<void>(
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
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DesignTokens.grayLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Select category',
                      style: DesignTokens.textHeadline.copyWith(fontSize: 17),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: categories.length,
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        final selected = cat.id == _categoryId;
                        return ListTile(
                          leading: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.category_outlined,
                            color: selected
                                ? DesignTokens.brandPrimary
                                : DesignTokens.grayMedium,
                          ),
                          title: Text(cat.displayLabel),
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _categoryId = cat.id;
                              _categoryName = cat.displayLabel;
                            });
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
      },
    );
  }

  Widget _buildServiceTypePicker() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Service type',
        prefixIcon: const Icon(Icons.place_outlined),
        border: OutlineInputBorder(borderRadius: DesignTokens.borderRadiusMd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _serviceTypes.containsKey(_serviceType) ? _serviceType : 'virtual',
          items: _serviceTypes.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _serviceType = value);
          },
        ),
      ),
    );
  }

  Widget _buildDeliveryTimeframePicker() {
    final hasError = _publishOnline && _deliveryTimeframe.trim().isEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Delivery timeframe',
        prefixIcon: const Icon(Icons.local_shipping_outlined),
        errorText: hasError ? 'Required for online listing' : null,
        border: OutlineInputBorder(borderRadius: DesignTokens.borderRadiusMd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _deliveryTimeframes.contains(_deliveryTimeframe)
              ? _deliveryTimeframe
              : _deliveryTimeframes[4],
          items: _deliveryTimeframes
              .map(
                (time) => DropdownMenuItem(
                  value: time,
                  child: Text(time),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _deliveryTimeframe = value);
          },
        ),
      ),
    );
  }

  Widget _buildPublishCard() {
    return AnimatedContainer(
      duration: DesignTokens.durationNormal,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _publishOnline
            ? DesignTokens.brandAccentSubtle
            : DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(
          color: _publishOnline
              ? DesignTokens.brandAccent.withValues(alpha: 0.35)
              : DesignTokens.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _publishOnline
                  ? DesignTokens.brandAccent.withValues(alpha: 0.15)
                  : DesignTokens.canvasCloud,
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Icon(
              _publishOnline ? Icons.public_rounded : Icons.store_outlined,
              color: _publishOnline ? DesignTokens.brandAccent : DesignTokens.inkMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Show on online shop', style: DesignTokens.textBodyBold),
                const SizedBox(height: 2),
                Text(
                  _publishOnline
                      ? (_publishChecklistComplete
                          ? 'Customers can find and book this service'
                          : 'Complete the checklist below to go live')
                      : 'Saved on this device only',
                  style: DesignTokens.textSmall,
                ),
                if (_publishOnline) ...[
                  const SizedBox(height: 10),
                  _publishChecklistRow('Category selected', _categoryId != null),
                  _publishChecklistRow(
                    'Summary (10+ chars)',
                    _summaryCtrl.text.trim().length >= 10,
                  ),
                  _publishChecklistRow('Cover photo', _hasCover),
                  _publishChecklistRow(
                    'Description (20+ chars)',
                    _descriptionHtml.plainText.trim().length >= 20,
                  ),
                  _publishChecklistRow(
                    'Delivery timeframe',
                    _deliveryTimeframe.trim().isNotEmpty,
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: _publishOnline,
            activeTrackColor: DesignTokens.brandAccent,
            onChanged: (value) => setState(() {
              _publishOnline = value;
              if (value) {
                _moderationStatus = 'pending';
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _publishChecklistRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: done ? DesignTokens.success : DesignTokens.inkMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: DesignTokens.textSmall.copyWith(
                color: done ? DesignTokens.textPrimary : DesignTokens.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBnplSection(BnplSellerStatus? status) {
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allow BNPL / Pay Later',
                    style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    active
                        ? 'Customers can buy now and pay later for this service'
                        : (disabledHint ?? 'Enable BNPL to use this option'),
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _bnplEnabled,
              onChanged: active
                  ? (value) => setState(() => _bnplEnabled = value)
                  : (_) {},
              activeTrackColor: DesignTokens.brandAccent,
              activeThumbColor: DesignTokens.brandAccent,
            ),
          ],
        ),
        if (!active && disabledHint != null) ...[
          const SizedBox(height: 8),
          Text(
            disabledHint,
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
          ),
        ],
        if (active && _bnplEnabled) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: _bnplMinCtrl,
                  label: 'Min order amount (UGX)',
                  hint: '10,000',
                  prefixIcon: Icons.arrow_downward_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  controller: _bnplMaxCtrl,
                  label: 'Max order amount (UGX)',
                  hint: '500,000',
                  prefixIcon: Icons.arrow_upward_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
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
          ),
        ],
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Text(subtitle, style: DesignTokens.textSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    final hint = _validationHint;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        boxShadow: DesignTokens.shadowBar,
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
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: hint.contains('20 characters')
                          ? DesignTokens.inkMuted
                          : DesignTokens.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: DesignTokens.textSmall.copyWith(
                          color: hint.contains('20 characters')
                              ? DesignTokens.inkMuted
                              : DesignTokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            AppButton(
              label: widget.isEditing ? 'Update Service' : 'Save Service',
              onPressed: _canSave ? _save : null,
              isLoading: _isSaving,
              expand: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

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

Future<bool> _requestImagePermission({required bool camera}) async {
  if (!Platform.isAndroid && !Platform.isIOS) return true;
  final permission = camera ? Permission.camera : Permission.photos;
  final status = await permission.request();
  return status.isGranted || status.isLimited;
}