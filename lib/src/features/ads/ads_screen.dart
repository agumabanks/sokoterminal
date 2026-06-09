import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/offline_cached_image.dart';
import '../checkout/checkout_screen.dart';
import 'ai_ads_tab.dart';
import 'studio_screen.dart';
import 'studio_splash.dart';
import 'studio_template_discovery.dart';
import 'studio_todays_ads.dart';

/// Ad template style (legacy local builder)
enum LegacyAdStyle { story, square, banner, minimal }

/// State for the ad builder
class AdBuilderState {
  const AdBuilderState({
    this.template = LegacyAdStyle.story,
    this.showPrice = true,
    this.showQr = true,
    this.showBrand = true,
    this.showStock = false,
    this.customCaption,
    this.discount = 0,
  });

  final LegacyAdStyle template;
  final bool showPrice;
  final bool showQr;
  final bool showBrand;
  final bool showStock;
  final String? customCaption;
  final double discount;

  AdBuilderState copyWith({
    LegacyAdStyle? template,
    bool? showPrice,
    bool? showQr,
    bool? showBrand,
    bool? showStock,
    String? customCaption,
    double? discount,
  }) {
    return AdBuilderState(
      template: template ?? this.template,
      showPrice: showPrice ?? this.showPrice,
      showQr: showQr ?? this.showQr,
      showBrand: showBrand ?? this.showBrand,
      showStock: showStock ?? this.showStock,
      customCaption: customCaption ?? this.customCaption,
      discount: discount ?? this.discount,
    );
  }
}

final adBuilderStateProvider = StateProvider<AdBuilderState>(
  (ref) => const AdBuilderState(),
);

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});

  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _previewKey = GlobalKey();
  String? _selectedId;
  bool _busy = false;
  late TabController _tabController;

  // Studio splash state
  bool _splashDone = false;
  bool _showStudio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(templateDiscoveryProvider.future);
      ref.read(todaysAdsProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show splash → then the full studio hub
    if (!_splashDone) {
      return StudioSplashScreen(
        onReady: () {
          if (!mounted) return;
          setState(() {
            _splashDone = true;
            _showStudio = true;
          });
        },
      );
    }

    if (_showStudio) {
      return const StudioScreen();
    }

    // Fallback legacy builder (not normally reached)
    final items = ref.watch(itemsStreamProvider);
    final adState = ref.watch(adBuilderStateProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Ads & Creatives', style: DesignTokens.textTitle),
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Ad Settings',
              onPressed: () => _showSettings(context, ref),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'AI Studio'),
            Tab(icon: Icon(Icons.brush, size: 18), text: 'Local Builder'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const AIAdsTab(),
          _buildLocalBuilder(items, adState),
        ],
      ),
    );
  }

  Widget _buildLocalBuilder(AsyncValue<List<Item>> items, AdBuilderState adState) {
    return items.when(
        data: (list) {
          if (list.isEmpty) {
            return _EmptyProductsState();
          }
          if (_selectedId == null || !list.any((e) => e.id == _selectedId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedId = list.first.id);
            });
          }
          final selected = list.firstWhere(
            (e) => e.id == _selectedId,
            orElse: () => list.first,
          );
          final caption = _buildCaption(selected, adState);

          return ListView(
            padding: DesignTokens.paddingScreen,
            children: [
              // Product selector
              _SectionTitle(title: 'Select Product'),
              const SizedBox(height: DesignTokens.spaceSm),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: DesignTokens.spaceSm),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final isSelected = item.id == _selectedId;
                    return _ProductChip(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedId = item.id),
                    );
                  },
                ),
              ),

              const SizedBox(height: DesignTokens.spaceLg),

              // Template selector
              _SectionTitle(title: 'Template Style'),
              const SizedBox(height: DesignTokens.spaceSm),
              _TemplateSelector(
                selected: adState.template,
                onSelect: (t) =>
                    ref.read(adBuilderStateProvider.notifier).state =
                        adState.copyWith(template: t),
              ),

              const SizedBox(height: DesignTokens.spaceLg),

              // Ad Preview
              _SectionTitle(title: 'Preview'),
              const SizedBox(height: DesignTokens.spaceSm),
              RepaintBoundary(
                key: _previewKey,
                child: _AdPreview(
                  item: selected,
                  template: adState.template,
                  showPrice: adState.showPrice,
                  showQr: adState.showQr,
                  showBrand: adState.showBrand,
                  showStock: adState.showStock,
                  discount: adState.discount,
                ),
              ),

              const SizedBox(height: DesignTokens.spaceLg),

              // Caption
              _SectionTitle(title: 'Caption'),
              const SizedBox(height: DesignTokens.spaceXs),
              Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceWhite,
                  borderRadius: DesignTokens.borderRadiusMd,
                  boxShadow: DesignTokens.shadowSm,
                ),
                child: Text(caption, style: DesignTokens.textSmall),
              ),

              const SizedBox(height: DesignTokens.spaceLg),

              // Share buttons
              _SectionTitle(title: 'Share'),
              const SizedBox(height: DesignTokens.spaceSm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: DesignTokens.spaceSm,
                crossAxisSpacing: DesignTokens.spaceSm,
                childAspectRatio: 2.5,
                children: [
                  _ShareButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: DesignTokens.brandPrimary,
                    onPressed: _busy
                        ? null
                        : () => _shareAd(
                            context,
                            selected,
                            caption,
                            _AdImageFormat.png,
                          ),
                  ),
                  _ShareButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onPressed: _busy
                        ? null
                        : () => _shareToWhatsApp(context, selected, caption),
                  ),
                  _ShareButton(
                    icon: Icons.image,
                    label: 'Save PNG',
                    color: DesignTokens.info,
                    onPressed: _busy
                        ? null
                        : () => _saveToGallery(
                            context,
                            selected,
                            _AdImageFormat.png,
                          ),
                  ),
                  _ShareButton(
                    icon: Icons.photo,
                    label: 'Save JPG',
                    color: DesignTokens.brandAccent,
                    onPressed: _busy
                        ? null
                        : () => _saveToGallery(
                            context,
                            selected,
                            _AdImageFormat.jpg,
                          ),
                  ),
                ],
              ),

              const SizedBox(height: DesignTokens.spaceLg),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
  }

  String _buildCaption(Item item, AdBuilderState state) {
    if (state.customCaption != null && state.customCaption!.isNotEmpty) {
      return state.customCaption!;
    }

    final buffer = StringBuffer();
    buffer.write('🛒 ${item.name}');

    if (state.discount > 0) {
      final originalPrice = item.price / (1 - state.discount / 100);
      buffer.write('\n\n💰 Now: UGX ${item.price.toStringAsFixed(0)}');
      buffer.write(
        '\n🏷️ Was: UGX ${originalPrice.toStringAsFixed(0)} (${state.discount.toStringAsFixed(0)}% OFF!)',
      );
    } else {
      buffer.write('\n\n💰 Price: UGX ${item.price.toStringAsFixed(0)}');
    }

    if (state.showStock && item.stockQty > 0) {
      buffer.write('\n📦 In Stock: ${item.stockQty} available');
    }

    buffer.write('\n\n🛍️ Shop Now at Soko 24');
    buffer.write('\n🔗 soko24.co/product/${item.id}');
    buffer.write('\n\n#Soko24 #Shopping #Uganda');

    return buffer.toString();
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    final state = ref.read(adBuilderStateProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Padding(
            padding: DesignTokens.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ad Settings', style: DesignTokens.textTitle),
                const SizedBox(height: DesignTokens.spaceLg),

                SwitchListTile(
                  title: const Text('Show Price'),
                  value: state.showPrice,
                  onChanged: (v) {
                    ref.read(adBuilderStateProvider.notifier).state = state
                        .copyWith(showPrice: v);
                    setLocalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Show QR Code'),
                  value: state.showQr,
                  onChanged: (v) {
                    ref.read(adBuilderStateProvider.notifier).state = state
                        .copyWith(showQr: v);
                    setLocalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Stock Level'),
                  value: state.showStock,
                  onChanged: (v) {
                    ref.read(adBuilderStateProvider.notifier).state = state
                        .copyWith(showStock: v);
                    setLocalState(() {});
                  },
                ),

                const SizedBox(height: DesignTokens.spaceMd),
                Text('Discount (%)', style: DesignTokens.textBodyBold),
                Slider(
                  value: state.discount,
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: '${state.discount.toStringAsFixed(0)}%',
                  onChanged: (v) {
                    ref.read(adBuilderStateProvider.notifier).state = state
                        .copyWith(discount: v);
                    setLocalState(() {});
                  },
                ),

                const SizedBox(height: DesignTokens.spaceLg),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareAd(
    BuildContext context,
    Item item,
    String caption,
    _AdImageFormat format,
  ) async {
    setState(() => _busy = true);
    try {
      final file = await _exportAdFile(item, format);
      await Share.shareXFiles([XFile(file.path)], text: caption);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _shareToWhatsApp(
    BuildContext context,
    Item item,
    String caption,
  ) async {
    setState(() => _busy = true);
    try {
      final file = await _exportAdFile(item, _AdImageFormat.jpg);
      await Share.shareXFiles([XFile(file.path)], text: caption);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('WhatsApp share failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveToGallery(
    BuildContext context,
    Item item,
    _AdImageFormat format,
  ) async {
    setState(() => _busy = true);
    try {
      final file = await _exportAdFile(item, format);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path}'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => Share.shareXFiles([XFile(file.path)]),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<File> _exportAdFile(Item item, _AdImageFormat format) async {
    final boundary =
        _previewKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Preview not ready yet');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Failed to capture ad image');
    }

    final pngBytes = data.buffer.asUint8List();
    Uint8List bytes = pngBytes;
    String extension = 'png';

    if (format == _AdImageFormat.jpg) {
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) {
        throw StateError('Failed to encode JPG');
      }
      bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      extension = 'jpg';
    }

    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'generated_ads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final safeName = item.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final fileName =
        'soko-ad-${safeName.isEmpty ? item.id : safeName}-$stamp.$extension';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    // Best effort: queue upload so generated creatives also reach cloud storage.
    unawaited(
      ref.read(syncServiceProvider).enqueue('ad_media_upload', {
        'file_path': file.path,
        'item_id': item.id,
        'remote_item_id': item.remoteId,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    unawaited(ref.read(syncServiceProvider).syncNow());

    return file;
  }
}

enum _AdImageFormat { png, jpg }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: DesignTokens.textBodyBold);
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final Item item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(DesignTokens.spaceSm),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.brandAccent
              : DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
          border: Border.all(
            color: isSelected ? Colors.transparent : DesignTokens.grayLight,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: DesignTokens.borderRadiusSm,
                child: OfflineCachedImage(
                  imageUrl: item.imageUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: Icon(
                    Icons.image,
                    size: 24,
                    color: isSelected
                        ? Colors.white70
                        : DesignTokens.grayMedium,
                  ),
                ),
              )
            else
              Icon(
                Icons.inventory_2,
                size: 24,
                color: isSelected ? Colors.white70 : DesignTokens.grayMedium,
              ),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: isSelected
                  ? DesignTokens.textSmallLight
                  : DesignTokens.textSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({required this.selected, required this.onSelect});
  final LegacyAdStyle selected;
  final ValueChanged<LegacyAdStyle> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: LegacyAdStyle.values.map((t) {
          final isSelected = t == selected;
          return Padding(
            padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
            child: FilterChip(
              label: Text(_getLabel(t)),
              selected: isSelected,
              onSelected: (_) => onSelect(t),
              selectedColor: DesignTokens.brandPrimary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : DesignTokens.grayDark,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getLabel(LegacyAdStyle t) {
    switch (t) {
      case LegacyAdStyle.story:
        return '📱 Story (9:16)';
      case LegacyAdStyle.square:
        return '📷 Square (1:1)';
      case LegacyAdStyle.banner:
        return '🖼️ Banner (16:9)';
      case LegacyAdStyle.minimal:
        return '✨ Minimal';
    }
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMd,
        ),
      ),
    );
  }
}

class _AdPreview extends StatelessWidget {
  const _AdPreview({
    required this.item,
    required this.template,
    required this.showPrice,
    required this.showQr,
    required this.showBrand,
    required this.showStock,
    required this.discount,
  });

  final Item item;
  final LegacyAdStyle template;
  final bool showPrice;
  final bool showQr;
  final bool showBrand;
  final bool showStock;
  final double discount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _getAspectRatio(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortestSide = constraints.biggest.shortestSide;
          final longestSide = constraints.biggest.longestSide;
          final edgePadding = (shortestSide * 0.08).clamp(12.0, 28.0);
          final imageSize = template == LegacyAdStyle.minimal
              ? 0.0
              : (shortestSide * (template == LegacyAdStyle.story ? 0.46 : 0.34))
                    .clamp(84.0, 168.0);
          final titleSize = (shortestSide *
                  (template == LegacyAdStyle.story ? 0.11 : 0.085))
              .clamp(18.0, template == LegacyAdStyle.story ? 30.0 : 26.0);
          final priceSize = (shortestSide * 0.08).clamp(16.0, 22.0);
          final chipFontSize = (shortestSide * 0.042).clamp(11.0, 14.0);
          final qrSize = (shortestSide * 0.24).clamp(42.0, 76.0);
          final bottomLabelSize = (shortestSide * 0.04).clamp(10.0, 13.0);
          final showQrBlock = showQr && shortestSide >= 180 && longestSide >= 240;

          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: DesignTokens.brandGradient,
              borderRadius: DesignTokens.borderRadiusLg,
              boxShadow: DesignTokens.shadowMd,
            ),
            child: Stack(
              children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: OfflineCachedImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: const SizedBox(),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(edgePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (showBrand)
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: (edgePadding * 0.55).clamp(
                                    6.0,
                                    12.0,
                                  ),
                                  vertical: (edgePadding * 0.28).clamp(
                                    4.0,
                                    8.0,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: DesignTokens.borderRadiusSm,
                                ),
                                child: Text(
                                  'Soko 24',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DesignTokens.textSmallLight.copyWith(
                                    fontSize: chipFontSize,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (discount > 0)
                            Container(
                              margin: EdgeInsets.only(
                                left: showBrand ? 8 : 0,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: (edgePadding * 0.55).clamp(
                                  6.0,
                                  12.0,
                                ),
                                vertical: (edgePadding * 0.28).clamp(
                                  4.0,
                                  8.0,
                                ),
                              ),
                              decoration: BoxDecoration(
                                color: DesignTokens.error,
                                borderRadius: DesignTokens.borderRadiusSm,
                              ),
                              child: Text(
                                '${discount.toStringAsFixed(0)}% OFF',
                                style: DesignTokens.textSmallLight.copyWith(
                                  fontSize: chipFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (imageSize > 0 &&
                                item.imageUrl != null &&
                                item.imageUrl!.isNotEmpty)
                              Container(
                                width: imageSize,
                                height: imageSize,
                                margin: EdgeInsets.only(
                                  bottom: (edgePadding * 0.7).clamp(8.0, 18.0),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: DesignTokens.borderRadiusMd,
                                  boxShadow: DesignTokens.shadowMd,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: OfflineCachedImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: Icon(
                                    Icons.image,
                                    size: (imageSize * 0.4).clamp(28.0, 56.0),
                                    color: DesignTokens.grayMedium,
                                  ),
                                ),
                              ),
                            Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: DesignTokens.textTitleLight.copyWith(
                                fontSize: titleSize,
                                height: 1.05,
                              ),
                              maxLines: template == LegacyAdStyle.story ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: (edgePadding * 0.7).clamp(8.0, 18.0),
                            ),
                            if (showPrice)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: (edgePadding * 0.95).clamp(
                                    12.0,
                                    22.0,
                                  ),
                                  vertical: (edgePadding * 0.55).clamp(
                                    8.0,
                                    14.0,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: DesignTokens.borderRadiusMd,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (discount > 0)
                                      Text(
                                        'UGX ${(item.price / (1 - discount / 100)).toStringAsFixed(0)}',
                                        style: DesignTokens.textSmall.copyWith(
                                          fontSize: chipFontSize,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: DesignTokens.grayMedium,
                                        ),
                                      ),
                                    Text(
                                      'UGX ${item.price.toStringAsFixed(0)}',
                                      style: DesignTokens.textBodyBold.copyWith(
                                        color: DesignTokens.brandPrimary,
                                        fontSize: priceSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (showStock && item.stockQty > 0)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: (edgePadding * 0.45).clamp(6.0, 12.0),
                                ),
                                child: Text(
                                  '${item.stockQty} in stock',
                                  style: DesignTokens.textSmallLight.copyWith(
                                    fontSize: chipFontSize,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (showQrBlock)
                            Container(
                              padding: EdgeInsets.all(
                                (edgePadding * 0.35).clamp(4.0, 8.0),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: DesignTokens.borderRadiusSm,
                              ),
                              child: QrImageView(
                                data: 'https://soko24.co/product/${item.id}',
                                version: QrVersions.auto,
                                size: qrSize,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Expanded(
                            child: Text(
                              'soko24.co',
                              textAlign: TextAlign.end,
                              style: DesignTokens.textSmallLight.copyWith(
                                fontSize: bottomLabelSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _getAspectRatio() {
    switch (template) {
      case LegacyAdStyle.story:
        return 9 / 16;
      case LegacyAdStyle.square:
        return 1;
      case LegacyAdStyle.banner:
        return 16 / 9;
      case LegacyAdStyle.minimal:
        return 1;
    }
  }
}

class _EmptyProductsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: DesignTokens.grayMedium,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No Products Yet', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Add products to your catalog to create beautiful ads',
              style: DesignTokens.textSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
