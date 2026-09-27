import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../core/media/offline_media_cache.dart';
import '../checkout/checkout_screen.dart' show itemsStreamProvider, servicesStreamProvider;
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/offline_cached_image.dart';
import 'video_ad_spec.dart';
import 'ffmpeg_plan_builder.dart';
import 'music_library.dart';

/// Video Ad Generator Screen — WhatsApp-first, offline-capable.
///
/// Uses the unified [VideoAdSpec] + [FfmpegPlanBuilder] pipeline.
class VideoAdScreen extends ConsumerStatefulWidget {
  const VideoAdScreen({super.key});

  @override
  ConsumerState<VideoAdScreen> createState() => _VideoAdScreenState();
}

class _VideoAdScreenState extends ConsumerState<VideoAdScreen>
    with TickerProviderStateMixin {
  String? _selectedId;
  AdFormat _selectedFormat = AdFormat.status9x16;
  final RenderQuality _selectedQuality = RenderQuality.standard720;
  final AdColorGrade _selectedGrade = AdColorGrade.none;
  bool _generating = false;
  double _progress = 0;
  String _renderStage = '';

  late AnimationController _previewAnimController;
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();
    _previewAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();
    });
  }

  @override
  void dispose() {
    _previewAnimController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const LoadingState(),
          error: (_, __) => const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load catalog',
          ),
          data: (products) {
            final services = servicesAsync.valueOrNull ?? [];
            final allItems = [
              ...products.map((p) => _VideoItem(
                    id: p.id,
                    name: p.name,
                    price: p.price,
                    imageUrl: p.imageUrl,
                    isService: false,
                  )),
              ...services.map((s) => _VideoItem(
                    id: s.id,
                    name: s.title,
                    price: s.price,
                    imageUrl: s.imageUrl,
                    isService: true,
                  )),
            ];

            if (allItems.isEmpty) {
              return const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                subtitle: 'Add products first to create video ads',
              );
            }

            return FadeTransition(
              opacity: _entryAnimation,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildPreviewCanvas(allItems)),
                  _buildFormatSelector(),
                  _buildBottomControls(allItems),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Video Ad',
              style: DesignTokens.textTitle.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas(List<_VideoItem> allItems) {
    final selectedItem = _selectedId != null
        ? allItems.firstWhere((i) => i.id == _selectedId,
            orElse: () => allItems.first)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: _selectedFormat.width / _selectedFormat.height,
          child: Container(
            color: Colors.black,
            child: selectedItem == null
                ? _buildEmptyPreview()
                : _buildAnimatedPreview(selectedItem),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.videocam_outlined, size: 36, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose a product',
            style: DesignTokens.textTitle.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a product to preview your video ad',
            style: DesignTokens.textSmall.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPreview(_VideoItem item) {
    return AnimatedBuilder(
      animation: _previewAnimController,
      builder: (context, child) {
        final value = _previewAnimController.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl != null)
              Transform.scale(
                scale: 1.0 + (value * 0.1),
                child: OfflineCachedImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: Container(color: Colors.grey[900]),
                  errorWidget: Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.image, color: Colors.white38, size: 48),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: Opacity(
                      opacity: value,
                      child: Text(
                        item.price.toUgx(),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedFormat.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: AdFormat.values.map((format) {
          final isActive = _selectedFormat == format;
          return GestureDetector(
            onTap: () {
              Haptics.selection();
              setState(() => _selectedFormat = format);
            },
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? DesignTokens.brandAccent : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                format.displayName,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls(List<_VideoItem> allItems) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: DesignTokens.hairline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showProductPicker(allItems),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: DesignTokens.canvasCloud,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.hairline),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedId != null
                                ? allItems.firstWhere((i) => i.id == _selectedId).name
                                : 'Select product',
                            style: DesignTokens.textSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DesignTokens.canvasCloud,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignTokens.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.high_quality_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(_selectedQuality.label, style: DesignTokens.textSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _generating
                ? _buildProgressPill()
                : FilledButton.icon(
                    onPressed: _selectedId != null
                        ? () => _generateVideo(allItems)
                        : null,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Generate Video Ad'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.brandAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.brandAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.brandAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(DesignTokens.brandAccent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _renderStage.isEmpty ? 'Generating...' : _renderStage,
              style: DesignTokens.textSmall.copyWith(
                color: DesignTokens.brandAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(_progress * 100).toInt()}%',
            style: DesignTokens.textCaption.copyWith(color: DesignTokens.brandAccent),
          ),
        ],
      ),
    );
  }

  void _showProductPicker(List<_VideoItem> allItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: DesignTokens.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                    color: DesignTokens.hairline,
                    borderRadius: BorderRadius.circular(99)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select Product', style: DesignTokens.textTitle),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = _selectedId == item.id;
                    return GestureDetector(
                      onTap: () {
                        Haptics.selection();
                        setState(() {
                          _selectedId = item.id;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignTokens.brandAccentSubtle
                              : DesignTokens.canvasCloud,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected
                                  ? DesignTokens.brandAccent
                                  : DesignTokens.hairline),
                        ),
                        child: Row(
                          children: [
                            if (item.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: OfflineCachedImage(
                                  imageUrl: item.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: DesignTokens.canvasCloud,
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: DesignTokens.textBodyBold),
                                  Text(item.price.toUgx(),
                                      style: DesignTokens.textSmall.copyWith(
                                          color: DesignTokens.brandAccent)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: DesignTokens.brandAccent),
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
      ),
    );
  }

  Future<void> _generateVideo(List<_VideoItem> allItems) async {
    if (_selectedId == null) return;

    setState(() {
      _generating = true;
      _progress = 0;
      _renderStage = 'Preparing assets...';
    });

    try {
      final selectedItem =
          allItems.firstWhere((i) => i.id == _selectedId);
      final tempDir = await getTemporaryDirectory();
      final imageFile = File('${tempDir.path}/product_$_selectedId.jpg');

      // Download the actual image using offline cache
      if (selectedItem.imageUrl != null) {
        try {
          final cachedFile =
              await OfflineMediaCache.instance.resolve(selectedItem.imageUrl!);
          if (cachedFile != null && cachedFile.existsSync()) {
            await cachedFile.copy(imageFile.path);
          }
        } catch (_) {}
      }

      if (!imageFile.existsSync() || imageFile.lengthSync() == 0) {
        // Create a colored placeholder if no image
        final placeholderBytes =
            await _generatePlaceholderImage(selectedItem.name, selectedItem.price.toUgx());
        await imageFile.writeAsBytes(placeholderBytes);
      }

      // Resolve music track (FIX: was empty string before)
      setState(() => _renderStage = 'Loading music...');
      final musicPath = await MusicLibrary.instance.resolveTrack(_selectedGenre);
      final fontPath = await MusicLibrary.instance.extractFont();

      final outputPath =
          '${tempDir.path}/video_ad_${_selectedId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Build the unified spec
      final spec = VideoAdSpec.quickAd(
        imagePath: imageFile.path,
        productName: selectedItem.name,
        price: selectedItem.price.toUgx(),
        format: _selectedFormat,
        quality: _selectedQuality,
        grade: _selectedGrade,
        music: musicPath != null
            ? AdMusicTrack(assetName: musicPath, genre: _selectedGenre)
            : null,
      );

      final assets = RenderAssets(
        fontPath: fontPath,
        musicPath: musicPath,
      );

      final builder = FfmpegPlanBuilder();
      final plan = spec.scenes.length == 1
          ? builder.buildSimple(
              spec: spec,
              assets: assets,
              outputPath: outputPath,
            )
          : builder.build(
              spec: spec,
              assets: assets,
              outputPath: outputPath,
            );

      setState(() => _renderStage = 'Rendering video...');

      final session = await FFmpegKit.executeAsync(
        plan.command,
        null,
        null,
        (stats) {
          final progress =
              (stats.getTime() / plan.targetDurationMs).clamp(0.0, 1.0);
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.3) {
                _renderStage = 'Composing frames...';
              } else if (progress < 0.6) {
                _renderStage = 'Adding effects...';
              } else if (progress < 0.85) {
                _renderStage = 'Adding text...';
              } else {
                _renderStage = 'Finalizing...';
              }
            });
          }
        },
      );

      final returnCode = await session.getReturnCode();
      final success = ReturnCode.isSuccess(returnCode);

      if (mounted) {
        if (success) {
          Haptics.success();
          setState(() {
            _generating = false;
          });
          _showVideoResult(outputPath);
        } else {
          setState(() => _generating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video generation failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showVideoResult(String outputPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: DesignTokens.hairline,
                  borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.check_circle,
                size: 64, color: DesignTokens.brandAccent),
            const SizedBox(height: 16),
            Text('Video ad ready!', style: DesignTokens.textTitle),
            const SizedBox(height: 8),
            Text('Share it on WhatsApp Status, Instagram Reels, or anywhere',
                style: DesignTokens.textSmall),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(outputPath)],
                      text: 'Check out this product!');
                },
                icon: const Icon(Icons.chat),
                label: const Text('Share to WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(outputPath)]);
                },
                icon: const Icon(Icons.share),
                label: const Text('Share elsewhere'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Selected music genre (default: afrobeats for East African sellers).
  AdMusicGenre get _selectedGenre => AdMusicGenre.afrobeats;
}

class _VideoItem {
  const _VideoItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isService,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isService;
}

/// Generate a colored placeholder image with product info
Future<Uint8List> _generatePlaceholderImage(String name, String price) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = const Size(1080, 1920);

  final gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.grey[900]!, Colors.black],
  );
  canvas.drawRect(Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size));

  final textPainter = TextPainter(
    text: TextSpan(
      text: name,
      style: const TextStyle(
          color: Colors.white, fontSize: 72, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout(maxWidth: size.width - 100);
  textPainter.paint(canvas, Offset(50, size.height - 400));

  final pricePainter = TextPainter(
    text: TextSpan(
      text: price,
      style: const TextStyle(
          color: Color(0xFFFFD700), fontSize: 96, fontWeight: FontWeight.w900),
    ),
    textDirection: TextDirection.ltr,
  );
  pricePainter.layout(maxWidth: size.width - 100);
  pricePainter.paint(canvas, Offset(50, size.height - 300));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
