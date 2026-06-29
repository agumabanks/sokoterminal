import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/db/app_database.dart';
import '../../core/media/offline_media_cache.dart';
import '../checkout/checkout_screen.dart' show itemsStreamProvider;
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'overlay_presets.dart';
import 'studio_entitlements.dart';
import 'studio_product_utils.dart';
import 'studio_providers.dart';
import 'studio_share_sheet.dart';
import 'studio_media_picker.dart';
import 'studio_watermark.dart';
import 'studio_watermark_settings.dart';

const _injectorShareTemplate = AdTemplate(
  id: 'ad-injector',
  name: 'Ad Injector',
  category: 'injector',
  canvasWidth: 1080,
  canvasHeight: 1080,
  background: '#000000',
  elements: [],
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _InjectorState {
  const _InjectorState({
    this.mediaFile,
    this.isVideo = false,
    this.videoFrame,
    this.layers = const [],
    this.selectedId,
    this.isBusy = false,
  });

  final File? mediaFile;
  final bool isVideo;
  final Uint8List? videoFrame;   // extracted first-frame bytes for video
  final List<OverlayLayer> layers;
  final String? selectedId;
  final bool isBusy;

  OverlayLayer? get selected =>
      selectedId == null ? null : layers.cast<OverlayLayer?>()
          .firstWhere((l) => l?.id == selectedId, orElse: () => null);

  _InjectorState copyWith({
    File? mediaFile,
    bool? isVideo,
    Uint8List? videoFrame,
    List<OverlayLayer>? layers,
    Object? selectedId = _sentinel,
    bool? isBusy,
  }) =>
      _InjectorState(
        mediaFile: mediaFile ?? this.mediaFile,
        isVideo: isVideo ?? this.isVideo,
        videoFrame: videoFrame ?? this.videoFrame,
        layers: layers ?? this.layers,
        selectedId: selectedId == _sentinel
            ? this.selectedId
            : selectedId as String?,
        isBusy: isBusy ?? this.isBusy,
      );
}

// ignore: avoid_private_typedef_functions
const _sentinel = Object();

class _InjectorNotifier extends StateNotifier<_InjectorState> {
  _InjectorNotifier() : super(const _InjectorState());

  void setMedia({
    required File file,
    required bool isVideo,
    Uint8List? videoFrame,
  }) {
    state = state.copyWith(
      mediaFile: file,
      isVideo: isVideo,
      videoFrame: videoFrame,
      layers: [],
      selectedId: null,
    );
  }

  void addLayer(OverlayLayer layer) {
    state = state.copyWith(
      layers: [...state.layers, layer],
      selectedId: layer.id,
    );
  }

  void addLayers(List<OverlayLayer> layers) {
    if (layers.isEmpty) return;
    state = state.copyWith(
      layers: [...state.layers, ...layers],
      selectedId: layers.last.id,
    );
  }

  void updateLayer(OverlayLayer updated) {
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          if (l.id == updated.id) updated else l,
      ],
    );
  }

  void removeLayer(String id) {
    state = state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
      selectedId: state.selectedId == id ? null : state.selectedId,
    );
  }

  void selectLayer(String? id) {
    // Toggle selection indicator on layers
    state = state.copyWith(
      layers: [
        for (final l in state.layers)
          l.copyWith(isSelected: l.id == id),
      ],
      selectedId: id,
    );
  }

  void setSelectedId(String? id) => selectLayer(id);

  void setBusy(bool v) => state = state.copyWith(isBusy: v);

  void clearMedia() => state = const _InjectorState();
}

final _injectorProvider =
    StateNotifierProvider.autoDispose<_InjectorNotifier, _InjectorState>(
  (_) => _InjectorNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdInjectorScreen extends ConsumerStatefulWidget {
  const AdInjectorScreen({super.key});

  @override
  ConsumerState<AdInjectorScreen> createState() => _AdInjectorScreenState();
}

class _AdInjectorScreenState extends ConsumerState<AdInjectorScreen>
    with SingleTickerProviderStateMixin {
  final _compositeKey = GlobalKey();
  final _picker = ImagePicker();
  VideoPlayerController? _videoCtrl;
  late AnimationController _pulseCtrl;
  String? _activePanel; // 'overlays' | 'edit' | null

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }



  @override
  void dispose() {
    _videoCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Media picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final xf = await _picker.pickImage(source: ImageSource.gallery);
    if (xf == null || !mounted) return;
    final file = File(xf.path);
    ref.read(_injectorProvider.notifier).setMedia(file: file, isVideo: false);
    setState(() => _activePanel = 'overlays');
  }

  Future<void> _pickStudioMedia() async {
    final pick = await showStudioMediaPicker(
      context,
      ref: ref,
      title: 'Choose photo for injector',
    );
    if (pick == null || !mounted) return;

    File? file;
    if (pick.src.startsWith('file://')) {
      file = File(pick.src.substring(7));
    } else {
      file = await OfflineMediaCache.instance.resolve(pick.src);
    }

    if (file == null || !file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load that image')),
      );
      return;
    }

    ref.read(_injectorProvider.notifier).setMedia(file: file, isVideo: false);
    setState(() => _activePanel = 'overlays');
  }

  Future<void> _pickVideo() async {
    final xf = await _picker.pickVideo(source: ImageSource.gallery);
    if (xf == null || !mounted) return;
    final file = File(xf.path);

    // Extract first frame as preview image
    final frame = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.PNG,
      maxWidth: 1080,
      quality: 95,
    );

    if (!mounted) return;
    ref.read(_injectorProvider.notifier).setMedia(
      file: file,
      isVideo: true,
      videoFrame: frame,
    );

    // Set up VideoPlayerController for playback preview
    _videoCtrl?.dispose();
    _videoCtrl = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });

    setState(() => _activePanel = 'overlays');
  }

  OverlayBrandContext _overlayContext(BrandKit kit, Item? product) =>
      overlayContextFrom(kit: kit, product: product);

  Future<File?> _capturePng() async {
    final notifier = ref.read(_injectorProvider.notifier);
    notifier.selectLayer(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final boundary = _compositeKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Compositor not ready');

    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('Failed to capture image');

    var bytes = data.buffer.asUint8List();
    final entitlements = await ref.read(studioEntitlementsProvider.future);
    final watermarkSettings = ref.read(watermarkSettingsProvider);
    final kit = ref.read(brandKitProvider);
    if (entitlements.needsSokoWatermark) {
      bytes = await applySokoWatermark(
        bytes,
        settings: watermarkSettings,
        brandKit: kit,
      );
    }

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'soko-injected-$ts.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _loadProductPhoto(Item product) async {
    final url = (product.thumbnailUrl ?? product.imageUrl ?? '').trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product has no photo yet')),
      );
      return;
    }

    final notifier = ref.read(_injectorProvider.notifier);
    notifier.setBusy(true);
    try {
      final file = await OfflineMediaCache.instance.resolve(url);
      if (file == null || !file.existsSync()) {
        throw Exception('Could not load product image');
      }
      if (!mounted) return;
      notifier.setMedia(file: file, isVideo: false);
      setState(() => _activePanel = 'overlays');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product photo failed: $e')),
      );
    } finally {
      notifier.setBusy(false);
    }
  }

  void _applyCombo(String comboId, BrandKit kit, Item? product) {
    final layers = buildComboLayers(
      comboId: comboId,
      ctx: _overlayContext(kit, product),
    );
    ref.read(_injectorProvider.notifier).addLayers(layers);
    setState(() => _activePanel = 'edit');
  }

  void _addOverlay(OverlayType type, BrandKit kit, Item? product) {
    final layer = buildPreset(
      type: type,
      ctx: _overlayContext(kit, product),
    );
    ref.read(_injectorProvider.notifier).addLayer(layer);
    setState(() => _activePanel = 'edit');
  }

  Future<void> _pickProduct() async {
    final items = ref.read(itemsStreamProvider).valueOrNull ?? [];
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products to your catalog first')),
      );
      return;
    }

    final picked = await showModalBottomSheet<Item>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InjectorProductSheet(items: items),
    );

    if (picked != null && mounted) {
      ref.read(studioProductProvider.notifier).state = picked;
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _export({bool share = false}) async {
    final notifier = ref.read(_injectorProvider.notifier);
    notifier.setBusy(true);

    try {
      final file = await _capturePng();
      if (file == null || !mounted) return;

      if (share) {
        final kit = ref.read(brandKitProvider);
        final product = ref.read(studioProductProvider);
        final entitlements = await ref.read(studioEntitlementsProvider.future);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => StudioShareSheet(
              adFile: file,
              template: _injectorShareTemplate,
              kit: kit,
              initialProduct: product,
              exportTitle: 'Ad Injector · ${product?.name ?? kit.businessName}',
              showWatermarkBadge: entitlements.needsSokoWatermark,
            ),
          ),
        );
      } else {
        final savePath = p.join(
          (await getApplicationDocumentsDirectory()).path,
          'soko_ads',
        );
        await Directory(savePath).create(recursive: true);
        final saved = await file.copy(p.join(savePath, p.basename(file.path)));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${p.basename(saved.path)}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _export(share: true),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      notifier.setBusy(false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_injectorProvider);
    final kit = ref.watch(brandKitProvider);
    final product = ref.watch(studioProductProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080E1C),
      body: Column(
        children: [
          _TopBar(
            hasMedia: state.mediaFile != null,
            isBusy: state.isBusy,
            hasLayers: state.layers.isNotEmpty,
            onBack: () {
              if (state.mediaFile != null) {
                ref.read(_injectorProvider.notifier).clearMedia();
                _videoCtrl?.dispose();
                _videoCtrl = null;
                setState(() => _activePanel = null);
              } else {
                Navigator.of(context).maybePop();
              }
            },
            onSave: () => _export(share: false),
            onShare: () => _export(share: true),
          ),

          if (state.mediaFile == null)
            _ProductQuickBar(
              product: product,
              kit: kit,
              onPickProduct: _pickProduct,
              onUseProductPhoto: product != null
                  ? () => _loadProductPhoto(product)
                  : null,
            ),

          Expanded(
            child: state.mediaFile == null
                ? _LandingPicker(
                    onPickImage: _pickImage,
                    onPickCatalog: _pickStudioMedia,
                    onPickVideo: _pickVideo,
                    pulse: _pulseCtrl,
                    product: product,
                    kit: kit,
                    onApplyCombo: (id) {
                      final url = (product?.thumbnailUrl ?? product?.imageUrl ?? '').trim();
                      if (product != null && url.isNotEmpty) {
                        _loadProductPhoto(product).then((_) {
                          if (mounted) _applyCombo(id, kit, product);
                        });
                      } else if (product != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pick a photo first — product has no image'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select a product for one-tap promo packs'),
                          ),
                        );
                      }
                    },
                  )
                : _Compositor(
                    compositeKey: _compositeKey,
                    state: state,
                    videoCtrl: _videoCtrl,
                    onLayerTap: (id) {
                      ref.read(_injectorProvider.notifier).selectLayer(id);
                      setState(() => _activePanel = 'edit');
                    },
                  ),
          ),

          // ── Bottom panel ────────────────────────────────────────────────
          if (state.mediaFile != null) ...[
            _ActiveLayerBar(
              state: state,
              onRemove: (id) =>
                  ref.read(_injectorProvider.notifier).removeLayer(id),
              onSelect: (id) {
                ref.read(_injectorProvider.notifier).selectLayer(id);
                setState(() => _activePanel = 'edit');
              },
            ),

            // Panel: overlay picker or layer editor
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _activePanel == 'overlays'
                  ? _OverlayPicker(
                      onAdd: (type) => _addOverlay(type, kit, product),
                      onApplyCombo: (id) => _applyCombo(id, kit, product),
                    )
                  : _activePanel == 'edit' && state.selected != null
                      ? _LayerEditor(
                          layer: state.selected!,
                          onUpdate: (l) =>
                              ref.read(_injectorProvider.notifier).updateLayer(l),
                          onDelete: () {
                            ref
                                .read(_injectorProvider.notifier)
                                .removeLayer(state.selected!.id);
                            setState(() => _activePanel =
                                state.layers.length > 1 ? 'edit' : 'overlays');
                          },
                        )
                      : const SizedBox.shrink(),
            ),

            _BottomToolbar(
              activePanel: _activePanel,
              hasVideo: state.isVideo,
              videoCtrl: _videoCtrl,
              onOverlays: () =>
                  setState(() => _activePanel = 'overlays'),
              onEdit: state.selected != null
                  ? () => setState(() => _activePanel = 'edit')
                  : null,
              onPickNew: _pickImage,
              onPickVideo: _pickVideo,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.hasMedia,
    required this.isBusy,
    required this.hasLayers,
    required this.onBack,
    required this.onSave,
    required this.onShare,
  });

  final bool hasMedia;
  final bool isBusy;
  final bool hasLayers;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: const Color(0xFF0F1D40),
      padding: EdgeInsets.fromLTRB(4, topPad + 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              hasMedia ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20,
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          // Logo + title
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EBE7E), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_fix_high_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AD INJECTOR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Overlay your brand on any photo or video',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (hasMedia && hasLayers) ...[
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0EBE7E)),
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.ios_share_rounded,
                    color: Colors.white70, size: 20),
                onPressed: onShare,
                tooltip: 'Share',
              ),
              GestureDetector(
                onTap: onSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EBE7E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Landing picker
// ---------------------------------------------------------------------------

class _LandingPicker extends StatelessWidget {
  const _LandingPicker({
    required this.onPickImage,
    required this.onPickCatalog,
    required this.onPickVideo,
    required this.pulse,
    this.product,
    this.kit,
    this.onApplyCombo,
  });

  final VoidCallback onPickImage;
  final VoidCallback onPickCatalog;
  final VoidCallback onPickVideo;
  final AnimationController pulse;
  final Item? product;
  final BrandKit? kit;
  final ValueChanged<String>? onApplyCombo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, child) => child!,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0EBE7E), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EBE7E).withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_fix_high_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 28),

          const Text(
            'Ad Injector',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick any photo or video from your gallery.\nOverlay your brand in seconds.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Picker buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PickerCard(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                subtitle: 'Device photos',
                gradient: const [Color(0xFF0EBE7E), Color(0xFF059669)],
                onTap: onPickImage,
              ),
              const SizedBox(width: 12),
              _PickerCard(
                icon: Icons.folder_special_rounded,
                label: 'Catalog',
                subtitle: 'Products & uploads',
                gradient: const [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
                onTap: onPickCatalog,
              ),
              const SizedBox(width: 12),
              _PickerCard(
                icon: Icons.videocam_rounded,
                label: 'Video',
                subtitle: 'MP4 · MOV',
                gradient: const [Color(0xFF0F1D40), Color(0xFF1e3a5f)],
                onTap: onPickVideo,
              ),
            ],
          ),

          if (product != null && onApplyCombo != null) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    'Ready-made for ${product!.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: overlayComboCatalogue.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final combo = overlayComboCatalogue[i];
                        return GestureDetector(
                          onTap: () => onApplyCombo!(combo.id),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EBE7E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF0EBE7E).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(combo.emoji, style: const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(
                                  combo.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeaturePill('16 overlays'),
              _FeaturePill('6 combo packs'),
              _FeaturePill('Product-aware'),
              _FeaturePill('Share + caption'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compositor
// ---------------------------------------------------------------------------

class _Compositor extends StatelessWidget {
  const _Compositor({
    required this.compositeKey,
    required this.state,
    required this.videoCtrl,
    required this.onLayerTap,
  });

  final GlobalKey compositeKey;
  final _InjectorState state;
  final VideoPlayerController? videoCtrl;
  final ValueChanged<String> onLayerTap;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final mediaH = MediaQuery.of(context).size.height * 0.45;

    return Center(
      child: Container(
        width: screenW,
        height: mediaH,
        color: Colors.black,
        child: RepaintBoundary(
          key: compositeKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compositorSize = constraints.biggest;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Base media ─────────────────────────────────────────
                  if (state.isVideo && state.videoFrame != null)
                    Image.memory(
                      state.videoFrame!,
                      fit: BoxFit.cover,
                      width: compositorSize.width,
                      height: compositorSize.height,
                    )
                  else if (!state.isVideo && state.mediaFile != null)
                    Image.file(
                      state.mediaFile!,
                      fit: BoxFit.cover,
                      width: compositorSize.width,
                      height: compositorSize.height,
                    )
                  else
                    Container(color: Colors.black),

                  // ── Overlay layers ─────────────────────────────────────
                  ...state.layers.map((layer) => OverlayRenderer(
                    layer: layer,
                    compositorSize: compositorSize,
                    onTap: () => onLayerTap(layer.id),
                  )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active layer bar (horizontal scroll of active overlays)
// ---------------------------------------------------------------------------

class _ActiveLayerBar extends StatelessWidget {
  const _ActiveLayerBar({
    required this.state,
    required this.onRemove,
    required this.onSelect,
  });

  final _InjectorState state;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (state.layers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      color: const Color(0xFF0A1220),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: state.layers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final l = state.layers[i];
          final isSel = l.id == state.selectedId;
          return GestureDetector(
            onTap: () => onSelect(l.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSel
                    ? const Color(0xFF0EBE7E).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSel ? const Color(0xFF0EBE7E) : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _emoji(l.type),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _label(l.type),
                    style: TextStyle(
                      color: isSel ? const Color(0xFF0EBE7E) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onRemove(l.id),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isSel
                          ? const Color(0xFF0EBE7E)
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _emoji(OverlayType t) =>
      overlayPresetCatalogue
          .firstWhere((p) => p.type == t,
              orElse: () => overlayPresetCatalogue.first)
          .emoji;

  String _label(OverlayType t) =>
      overlayPresetCatalogue
          .firstWhere((p) => p.type == t,
              orElse: () => overlayPresetCatalogue.first)
          .label;
}

// ---------------------------------------------------------------------------
// Overlay picker panel
// ---------------------------------------------------------------------------

class _OverlayPicker extends StatefulWidget {
  const _OverlayPicker({
    required this.onAdd,
    required this.onApplyCombo,
  });

  final ValueChanged<OverlayType> onAdd;
  final ValueChanged<String> onApplyCombo;

  @override
  State<_OverlayPicker> createState() => _OverlayPickerState();
}

class _OverlayPickerState extends State<_OverlayPicker> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1525),
      constraints: const BoxConstraints(maxHeight: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                _PickerTab(
                  label: 'Combos',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                _PickerTab(
                  label: 'Overlays',
                  active: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const Spacer(),
                Text(
                  _tab == 0
                      ? '${overlayComboCatalogue.length} packs'
                      : '${overlayPresetCatalogue.length} presets',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: overlayComboCatalogue.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final combo = overlayComboCatalogue[i];
                      return GestureDetector(
                        onTap: () => widget.onApplyCombo(combo.id),
                        child: Container(
                          width: 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF0EBE7E).withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF0EBE7E).withValues(alpha: 0.35),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(combo.emoji,
                                  style: const TextStyle(fontSize: 24)),
                              const Spacer(),
                              Text(
                                combo.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                combo.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 8,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: overlayPresetCatalogue.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final preset = overlayPresetCatalogue[i];
                      return GestureDetector(
                        onTap: () => widget.onAdd(preset.type),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(preset.emoji,
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                preset.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickerTab extends StatelessWidget {
  const _PickerTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF0EBE7E).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFF0EBE7E) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF0EBE7E) : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductQuickBar extends StatelessWidget {
  const _ProductQuickBar({
    required this.product,
    required this.kit,
    required this.onPickProduct,
    this.onUseProductPhoto,
  });

  final Item? product;
  final BrandKit kit;
  final VoidCallback onPickProduct;
  final VoidCallback? onUseProductPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1220),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onPickProduct,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(
                      product != null
                          ? Icons.inventory_2_rounded
                          : Icons.add_shopping_cart_rounded,
                      color: const Color(0xFF0EBE7E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product?.name ?? 'Select product for auto-fill',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: product != null ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 18),
                  ],
                ),
              ),
            ),
          ),
          if (onUseProductPhoto != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUseProductPhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EBE7E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Use photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InjectorProductSheet extends StatefulWidget {
  const _InjectorProductSheet({required this.items});
  final List<Item> items;

  @override
  State<_InjectorProductSheet> createState() => _InjectorProductSheetState();
}

class _InjectorProductSheetState extends State<_InjectorProductSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items
            .where((i) => i.name.toLowerCase().contains(q))
            .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Product for overlays & share',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search catalog…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                return ListTile(
                  title: Text(item.name,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    formatUgPrice(item.price),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer editor panel
// ---------------------------------------------------------------------------

class _LayerEditor extends StatefulWidget {
  const _LayerEditor({
    required this.layer,
    required this.onUpdate,
    required this.onDelete,
  });

  final OverlayLayer layer;
  final ValueChanged<OverlayLayer> onUpdate;
  final VoidCallback onDelete;

  @override
  State<_LayerEditor> createState() => _LayerEditorState();
}

class _LayerEditorState extends State<_LayerEditor>
    with SingleTickerProviderStateMixin {
  late TextEditingController _primary;
  late TextEditingController _secondary;
  late TextEditingController _tertiary;
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _reset();
  }

  void _reset() {
    _primary = TextEditingController(text: widget.layer.primaryText);
    _secondary = TextEditingController(text: widget.layer.secondaryText);
    _tertiary = TextEditingController(text: widget.layer.tertiaryText);
  }

  @override
  void didUpdateWidget(_LayerEditor old) {
    super.didUpdateWidget(old);
    if (old.layer.id != widget.layer.id) {
      _primary.dispose();
      _secondary.dispose();
      _tertiary.dispose();
      _reset();
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    _primary.dispose();
    _secondary.dispose();
    _tertiary.dispose();
    super.dispose();
  }

  void _up(OverlayLayer l) => widget.onUpdate(l);

  @override
  Widget build(BuildContext context) {
    final l = widget.layer;
    return Container(
      color: const Color(0xFF0D1525),
      constraints: const BoxConstraints(maxHeight: 220),
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tc,
            labelColor: const Color(0xFF0EBE7E),
            unselectedLabelColor: Colors.white38,
            indicatorColor: const Color(0xFF0EBE7E),
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(text: 'Text'),
              Tab(text: 'Colors'),
              Tab(text: 'Position'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                // ── Text tab ─────────────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      _Field(
                        ctrl: _primary,
                        hint: 'Primary text (headline)',
                        onChanged: (v) => _up(l.copyWith(primaryText: v)),
                      ),
                      const SizedBox(height: 8),
                      _Field(
                        ctrl: _secondary,
                        hint: 'Secondary text (body)',
                        onChanged: (v) => _up(l.copyWith(secondaryText: v)),
                      ),
                      const SizedBox(height: 8),
                      _Field(
                        ctrl: _tertiary,
                        hint: 'Tertiary text (footer / url)',
                        onChanged: (v) => _up(l.copyWith(tertiaryText: v)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Opacity',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Slider(
                              value: l.opacity,
                              min: 0.1, max: 1.0,
                              activeColor: const Color(0xFF0EBE7E),
                              inactiveColor: Colors.white12,
                              onChanged: (v) => _up(l.copyWith(opacity: v)),
                            ),
                          ),
                          Text(
                            '${(l.opacity * 100).toInt()}%',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      // Delete button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 16),
                          label: const Text('Remove overlay',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Colors tab ────────────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _colorRow('Background', l.bgColor, (c) => _up(l.copyWith(bgColor: c))),
                      const SizedBox(height: 8),
                      _colorRow('Accent', l.accentColor, (c) => _up(l.copyWith(accentColor: c))),
                      const SizedBox(height: 8),
                      _colorRow('Text', l.textColor, (c) => _up(l.copyWith(textColor: c))),
                    ],
                  ),
                ),

                // ── Position tab ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _PositionGrid(
                    current: l.anchor,
                    onSelect: (a) => _up(l.copyWith(anchor: a)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, Color current, ValueChanged<Color> onPick) {
    final swatches = <Color>[
      Colors.white, Colors.black, const Color(0xFF0F1D40),
      const Color(0xFF0EBE7E), const Color(0xFFdc2626), const Color(0xFFf59e0b),
      const Color(0xFF6366f1), const Color(0xFFec4899), const Color(0xFF3b82f6),
      const Color(0xFFd4af37), Colors.transparent,
    ];
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        ...swatches.map((c) {
          final sel = current == c;
          return GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: c == Colors.transparent ? null : c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? const Color(0xFF0EBE7E) : Colors.white12,
                  width: sel ? 2 : 1,
                ),
              ),
              child: c == Colors.transparent
                  ? const Icon(Icons.format_color_reset_rounded,
                      color: Colors.white38, size: 12)
                  : sel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12)
                      : null,
            ),
          );
        }),
      ],
    );
  }
}

// ── Position grid ─────────────────────────────────────────────────────────────

class _PositionGrid extends StatelessWidget {
  const _PositionGrid({required this.current, required this.onSelect});
  final OverlayAnchor current;
  final ValueChanged<OverlayAnchor> onSelect;

  static const _positions = <OverlayAnchor>[
    OverlayAnchor.topLeft,    OverlayAnchor.topCenter,    OverlayAnchor.topRight,
    OverlayAnchor.center,     OverlayAnchor.fullBottom,   OverlayAnchor.bottomLeft,
    OverlayAnchor.bottomCenter, OverlayAnchor.bottomRight, OverlayAnchor.fullTop,
  ];

  static const _icons = <OverlayAnchor, IconData>{
    OverlayAnchor.topLeft:      Icons.north_west_rounded,
    OverlayAnchor.topCenter:    Icons.north_rounded,
    OverlayAnchor.topRight:     Icons.north_east_rounded,
    OverlayAnchor.center:       Icons.center_focus_strong_rounded,
    OverlayAnchor.fullBottom:   Icons.vertical_align_bottom_rounded,
    OverlayAnchor.bottomLeft:   Icons.south_west_rounded,
    OverlayAnchor.bottomCenter: Icons.south_rounded,
    OverlayAnchor.bottomRight:  Icons.south_east_rounded,
    OverlayAnchor.fullTop:      Icons.vertical_align_top_rounded,
  };

  static const _labels = <OverlayAnchor, String>{
    OverlayAnchor.topLeft:      'Top Left',
    OverlayAnchor.topCenter:    'Top',
    OverlayAnchor.topRight:     'Top Right',
    OverlayAnchor.center:       'Centre',
    OverlayAnchor.fullBottom:   'Full Bottom',
    OverlayAnchor.bottomLeft:   'Bot Left',
    OverlayAnchor.bottomCenter: 'Bottom',
    OverlayAnchor.bottomRight:  'Bot Right',
    OverlayAnchor.fullTop:      'Full Top',
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: _positions.map((pos) {
        final sel = current == pos;
        return GestureDetector(
          onTap: () => onSelect(pos),
          child: Container(
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF0EBE7E).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? const Color(0xFF0EBE7E) : Colors.white10,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icons[pos]!,
                    color: sel ? const Color(0xFF0EBE7E) : Colors.white38,
                    size: 16),
                const SizedBox(height: 2),
                Text(
                  _labels[pos]!,
                  style: TextStyle(
                    color: sel ? const Color(0xFF0EBE7E) : Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom toolbar
// ---------------------------------------------------------------------------

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.activePanel,
    required this.hasVideo,
    required this.videoCtrl,
    required this.onOverlays,
    required this.onEdit,
    required this.onPickNew,
    required this.onPickVideo,
  });

  final String? activePanel;
  final bool hasVideo;
  final VideoPlayerController? videoCtrl;
  final VoidCallback onOverlays;
  final VoidCallback? onEdit;
  final VoidCallback onPickNew;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF0F1D40),
      padding: EdgeInsets.fromLTRB(0, 6, 0, 6 + bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Btn(
            icon: Icons.add_circle_rounded,
            label: 'Overlays',
            active: activePanel == 'overlays',
            onTap: onOverlays,
          ),
          if (onEdit != null)
            _Btn(
              icon: Icons.edit_rounded,
              label: 'Edit',
              active: activePanel == 'edit',
              onTap: onEdit!,
            ),
          if (hasVideo && videoCtrl != null)
            _Btn(
              icon: videoCtrl!.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              label: videoCtrl!.value.isPlaying ? 'Pause' : 'Play',
              active: false,
              onTap: () {
                if (videoCtrl!.value.isPlaying) {
                  videoCtrl!.pause();
                } else {
                  videoCtrl!.play();
                }
              },
            ),
          _Btn(
            icon: Icons.photo_library_rounded,
            label: 'New Photo',
            active: false,
            onTap: onPickNew,
          ),
          _Btn(
            icon: Icons.videocam_rounded,
            label: 'New Video',
            active: false,
            onTap: onPickVideo,
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: active ? const Color(0xFF0EBE7E) : Colors.white38),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF0EBE7E) : Colors.white38,
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0EBE7E)),
        ),
      ),
    );
  }
}


