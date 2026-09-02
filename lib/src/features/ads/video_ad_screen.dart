import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../checkout/checkout_screen.dart';
import 'video_ad_generator.dart';

/// Video Ad Generator Screen
///
/// CapCut-style video ad creator:
/// 1. Select product
/// 2. Choose style
/// 3. Generate & share
class VideoAdScreen extends ConsumerStatefulWidget {
  const VideoAdScreen({super.key});

  @override
  ConsumerState<VideoAdScreen> createState() => _VideoAdScreenState();
}

class _VideoAdScreenState extends ConsumerState<VideoAdScreen> {
  String? _selectedId;
  bool _selectedIsService = false;
  int _selectedStyle = 0;
  bool _generating = false;
  double _progress = 0;
  String? _outputPath;

  static const _styles = [
    {'id': 'fade', 'name': 'Fade', 'icon': Icons.blur_on},
    {'id': 'slide', 'name': 'Slide', 'icon': Icons.slideshow},
    {'id': 'zoom', 'name': 'Zoom', 'icon': Icons.zoom_in},
  ];

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Video Ad', style: DesignTokens.textTitle),
      ),
      body: itemsAsync.when(
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

          return Column(
            children: [
              // Product selector
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: DesignTokens.paddingHorizontalMd,
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = _selectedId == item.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedId = item.id;
                          _selectedIsService = item.isService;
                          _outputPath = null;
                        });
                        Haptics.selection();
                      },
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignTokens.brandAccent
                              : DesignTokens.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? DesignTokens.brandAccent
                                : DesignTokens.hairline,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Icon(
                                item.isService
                                    ? Icons.room_service_outlined
                                    : Icons.inventory_2_outlined,
                                size: 24,
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.inkMuted,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesignTokens.textCaption.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Style selector
              if (_selectedId != null)
                Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: DesignTokens.paddingHorizontalMd,
                    itemCount: _styles.length,
                    itemBuilder: (context, index) {
                      final style = _styles[index];
                      final isSelected = _selectedStyle == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedStyle = index);
                          Haptics.selection();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? DesignTokens.brandAccent
                                : DesignTokens.canvas,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? DesignTokens.brandAccent
                                  : DesignTokens.hairline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                style['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.ink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                style['name'] as String,
                                style: DesignTokens.textSmall.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : DesignTokens.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Preview area
              if (_selectedId != null && !_generating && _outputPath == null)
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        margin: DesignTokens.paddingScreen,
                        decoration: BoxDecoration(
                          color: DesignTokens.brandPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_outline,
                                size: 64,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '9:16 Video Ad',
                                style: DesignTokens.textTitle.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'WhatsApp Status / Reels',
                                style: DesignTokens.textSmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Progress
              if (_generating)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 8,
                            backgroundColor: DesignTokens.hairline,
                            valueColor: const AlwaysStoppedAnimation(
                              DesignTokens.brandAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: DesignTokens.textTitle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generating video ad...',
                          style: DesignTokens.textSmall,
                        ),
                      ],
                    ),
                  ),
                ),

              // Result
              if (_outputPath != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: DesignTokens.paddingScreen,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: DesignTokens.canvas,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: DesignTokens.hairline),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 64,
                                color: DesignTokens.brandAccent,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Video ad ready!',
                                style: DesignTokens.textTitle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share it on WhatsApp, Instagram, or anywhere',
                                style: DesignTokens.textSmall,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _shareVideo,
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignTokens.brandAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _outputPath = null;
                                  _selectedId = null;
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('New'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Generate button
              if (_selectedId != null && !_generating && _outputPath == null)
                Padding(
                  padding: DesignTokens.paddingScreen,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Generate Video Ad'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.brandAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.borderRadiusFull,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

              // Prompt to select
              if (_selectedId == null)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.videocam_outlined,
                    title: 'Select a product',
                    subtitle: 'Then choose a style and generate a video ad',
                  ),
                ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedId == null) return;

    setState(() {
      _generating = true;
      _progress = 0;
    });

    try {
      final itemsAsync = ref.read(itemsStreamProvider);
      final servicesAsync = ref.read(servicesStreamProvider);

      String productName;
      double price;

      if (_selectedIsService) {
        final services = servicesAsync.valueOrNull ?? [];
        final service = services.firstWhere((s) => s.id == _selectedId);
        productName = service.title;
        price = service.price;
      } else {
        final products = itemsAsync.valueOrNull ?? [];
        final product = products.firstWhere((p) => p.id == _selectedId);
        productName = product.name;
        price = product.price;
      }

      // For demo: create a placeholder image if none exists
      // In production, use actual product images
      final tempDir = await getTemporaryDirectory();
      final imageFile = File('${tempDir.path}/product_$_selectedId.jpg');
      if (!imageFile.existsSync()) {
        // Create a simple colored placeholder image
        // In production, download actual product image
        await imageFile.writeAsBytes([]); // placeholder
      }

      final fontPath = await VideoAdGenerator.extractFont();
      final musicPath = ''; // TODO: Bundle background music
      final outputPath = '${tempDir.path}/video_ad_${_selectedId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Generate video
      final success = await VideoAdGenerator.generate(
        imagePaths: [imageFile.path],
        musicPath: musicPath,
        fontPath: fontPath,
        productName: productName,
        price: price.toUgx(),
        outputPath: outputPath,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) {
        if (success) {
          setState(() {
            _outputPath = outputPath;
            _generating = false;
          });
          Haptics.success();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _shareVideo() {
    if (_outputPath == null) return;
    Share.shareXFiles([XFile(_outputPath!)], text: 'Check out this product!');
  }
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
