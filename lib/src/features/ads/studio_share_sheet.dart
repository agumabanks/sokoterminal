import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../checkout/checkout_screen.dart' show itemsStreamProvider;
import '../contacts/contacts_controller.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'studio_product_utils.dart';
import 'studio_providers.dart';
import 'studio_template_exporter.dart';

// ---------------------------------------------------------------------------
// StudioShareSheet — product-aware share review with social destinations
// ---------------------------------------------------------------------------

class StudioShareSheet extends ConsumerStatefulWidget {
  const StudioShareSheet({
    super.key,
    required this.adFile,
    required this.template,
    required this.kit,
    this.initialProduct,
    this.isService = false,
    this.showWatermarkBadge = false,
    this.exportTitle,
    this.initialCaption,
    this.activeSize,
  });

  final File adFile;
  final AdTemplate template;
  final BrandKit kit;
  final AdSize? activeSize;
  final Item? initialProduct;
  final bool isService;
  final bool showWatermarkBadge;
  /// Overrides [template.name] in captions and preview (e.g. Ad Injector exports).
  final String? exportTitle;
  /// Pre-filled caption (e.g. Today's Ads ready-to-post copy).
  final String? initialCaption;

  @override
  ConsumerState<StudioShareSheet> createState() => _StudioShareSheetState();
}

class _StudioShareSheetState extends ConsumerState<StudioShareSheet> {
  late final TextEditingController _captionCtrl;
  Item? _product;
  StudioShareDetails _details = const StudioShareDetails();
  String? _productLink;
  bool _busy = false;
  bool _saved = false;
  String _q = '';
  String? _panel;

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    _captionCtrl = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _refreshLink();
    if (mounted) {
      final preset = widget.initialCaption?.trim();
      _captionCtrl.text =
          preset != null && preset.isNotEmpty ? preset : _buildCaption();
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshLink() async {
    final link = await resolveProductShareLink(
      product: _product,
      kit: widget.kit,
      api: ref.read(sellerApiProvider),
      isService: widget.isService,
    );
    if (mounted) setState(() => _productLink = link);
  }

  String get _contentTitle => widget.exportTitle ?? widget.template.name;

  String _buildCaption() => buildShareCaption(
        kit: widget.kit,
        templateName: _contentTitle,
        details: _details,
        product: _product,
        productLink: _productLink,
      );

  void _rebuildCaption() {
    _captionCtrl.text = _buildCaption();
  }

  Future<void> _shareViaSystem({String? hint}) async {
    setState(() => _busy = true);
    try {
      var text = _captionCtrl.text;
      if (hint != null && hint.isNotEmpty) {
        text = '$text\n\n$hint';
      }
      await Share.shareXFiles([XFile(widget.adFile.path)], text: text);
      unawaited(ref.read(studioCampaignAnalyticsProvider.notifier).recordShare());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareWhatsApp({String? toNumber}) async {
    setState(() => _busy = true);
    try {
      await Share.shareXFiles(
        [XFile(widget.adFile.path)],
        text: _captionCtrl.text,
      );
      unawaited(ref.read(studioCampaignAnalyticsProvider.notifier).recordShare());
    } catch (_) {
      final encoded = Uri.encodeComponent(_captionCtrl.text);
      final number = (toNumber ?? widget.kit.whatsapp)
          .replaceAll(RegExp(r'[^\d+]'), '');
      final url = number.isEmpty
          ? 'https://wa.me/?text=$encoded'
          : 'https://wa.me/$number?text=$encoded';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDevice() async {
    if (_saved) return;
    setState(() => _busy = true);
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final dest = p.join(
        dir.path,
        'SokoStudio',
        'ad-${widget.template.id}-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await Directory(p.dirname(dest)).create(recursive: true);
      await widget.adFile.copy(dest);
      setState(() => _saved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to SokoStudio folder ✓')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _currentSizeLabel {
    final size = widget.activeSize ??
        findAdSizeFor(widget.template.canvasWidth, widget.template.canvasHeight);
    if (size != null) {
      return '${size.label} ${size.width.toInt()}×${size.height.toInt()}';
    }
    return '${widget.template.canvasWidth.toInt()}×${widget.template.canvasHeight.toInt()}';
  }

  Future<void> _exportMoreSizes() async {
    final selected = await showDialog<List<AdSize>>(
      context: context,
      builder: (ctx) => _SizeSelectorDialog(
        current: widget.activeSize ??
            findAdSizeFor(widget.template.canvasWidth, widget.template.canvasHeight),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final files = await exportStudioTemplatePngForSizes(
        context,
        template: widget.template,
        sizes: selected,
        applyWatermark: widget.showWatermarkBadge,
        pixelRatio: 1.5,
      );
      if (!mounted) return;
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed — no files generated')),
        );
        return;
      }
      await _showMultiExportResult(files);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMultiExportResult(List<File> files) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.brandPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MultiExportResultSheet(
        files: files,
        caption: _captionCtrl.text,
        onShare: _shareFiles,
        onSave: _saveFiles,
      ),
    );
  }

  Future<void> _shareFiles(List<File> files) async {
    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      text: _captionCtrl.text,
    );
  }

  Future<void> _saveFiles(List<File> files) async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'SokoStudio'));
    await folder.create(recursive: true);
    final saved = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = p.extension(file.path);
      final dest = p.join(
        folder.path,
        'ad-${widget.template.id}-${DateTime.now().millisecondsSinceEpoch}_$i$ext',
      );
      await file.copy(dest);
      saved.add(dest);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${saved.length} images to SokoStudio folder ✓')),
      );
    }
  }

  void _copyCaption() {
    Clipboard.setData(ClipboardData(text: _captionCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied!')),
    );
  }

  Future<void> _pickProduct() async {
    final items = ref.read(itemsStreamProvider).valueOrNull ?? [];
    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add products to your catalog first')),
        );
      }
      return;
    }

    final picked = await showModalBottomSheet<Item>(
      context: context,
      backgroundColor: DesignTokens.brandPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(items: items),
    );

    if (picked != null && mounted) {
      setState(() => _product = picked);
      await _refreshLink();
      _rebuildCaption();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: DesignTokens.brandPrimary,
      body: Column(
        children: [
          _buildTopBar(topPad),
          Expanded(
            child: _panel == 'contacts'
                ? _ContactsPanel(
                    q: _q,
                    onQChanged: (v) => setState(() => _q = v),
                    onWhatsApp: (phone) => _shareWhatsApp(toNumber: phone),
                    onClose: () => setState(() => _panel = null),
                  )
                : _buildMainContent(),
          ),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar(double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
      decoration: const BoxDecoration(
        color: DesignTokens.brandPrimary,
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Pick product details & post anywhere',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _copyCaption,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, color: Colors.white54, size: 14),
                  SizedBox(width: 6),
                  Text('Copy', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdPreviewCard(
            adFile: widget.adFile,
            template: widget.template,
            showWatermarkBadge: widget.showWatermarkBadge,
            displayTitle: _contentTitle,
          ),
          const SizedBox(height: 16),

          // Canvas size + multi-export
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canvas size',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSizeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _busy ? null : _exportMoreSizes,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.aspect_ratio_rounded, color: Colors.white54, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Export more sizes',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Product picker (only allow changing when no product was baked into the image)
          if (widget.initialProduct == null) ...[
            _SectionLabel('Product for this post'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickProduct,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: DesignTokens.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: DesignTokens.brandAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product?.name ?? 'No product selected',
                            style: TextStyle(
                              color: _product != null ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _product != null
                                ? formatUgPrice(_product!.price)
                                : 'Tap to attach product name, price & link',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionLabel('Include in caption'),
          const SizedBox(height: 8),
          _DetailToggles(
            details: _details,
            onChanged: (d) {
              setState(() => _details = d);
              _rebuildCaption();
            },
          ),

          const SizedBox(height: 16),
          _SectionLabel('Caption'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _captionCtrl,
              maxLines: null,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.65),
              decoration: const InputDecoration.collapsed(
                hintText: 'Write your caption…',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (_productLink != null)
            _SmartLinkCard(link: _productLink!, kit: widget.kit),

          const SizedBox(height: 16),
          _SectionLabel('Share to'),
          const SizedBox(height: 10),
          _SocialPlatformRow(
            busy: _busy,
            onWhatsApp: _shareWhatsApp,
            onInstagram: () => _shareViaSystem(
              hint: 'Tip: Post as Story or Feed — image is sized for social.',
            ),
            onFacebook: () => _shareViaSystem(hint: 'Tip: Great for Facebook Page posts.'),
            onTikTok: () => _shareViaSystem(hint: 'Tip: Upload as a TikTok image post.'),
            onTwitter: () => _shareViaSystem(),
            onMore: _shareViaSystem,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
      decoration: const BoxDecoration(
        color: DesignTokens.brandPrimary,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _shareWhatsApp,
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Send on WhatsApp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SecBtn(
                  icon: Icons.ios_share_rounded,
                  label: 'All Apps',
                  onTap: _busy ? null : _shareViaSystem,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecBtn(
                  icon: Icons.contacts_rounded,
                  label: 'Contacts',
                  onTap: () => setState(() => _panel = 'contacts'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecBtn(
                  icon: _saved ? Icons.check_circle_rounded : Icons.download_rounded,
                  label: _saved ? 'Saved!' : 'Save',
                  color: _saved ? DesignTokens.brandAccent : null,
                  onTap: _busy ? null : _saveToDevice,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail toggles
// ---------------------------------------------------------------------------

class _DetailToggles extends StatelessWidget {
  const _DetailToggles({required this.details, required this.onChanged});
  final StudioShareDetails details;
  final ValueChanged<StudioShareDetails> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on, VoidCallback toggle) {
      return FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: on,
        onSelected: (_) => toggle(),
        selectedColor: DesignTokens.brandAccent.withValues(alpha: 0.25),
        checkmarkColor: DesignTokens.brandAccent,
        labelStyle: TextStyle(
          color: on ? Colors.white : Colors.white54,
          fontWeight: on ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Product name', details.includeProductName,
            () => onChanged(details.copyWith(includeProductName: !details.includeProductName))),
        chip('Price', details.includePrice,
            () => onChanged(details.copyWith(includePrice: !details.includePrice))),
        chip('Product link', details.includeProductLink,
            () => onChanged(details.copyWith(includeProductLink: !details.includeProductLink))),
        chip('WhatsApp', details.includeWhatsapp,
            () => onChanged(details.copyWith(includeWhatsapp: !details.includeWhatsapp))),
        chip('Phone', details.includePhone,
            () => onChanged(details.copyWith(includePhone: !details.includePhone))),
        chip('Business', details.includeBusiness,
            () => onChanged(details.copyWith(includeBusiness: !details.includeBusiness))),
        chip('Location', details.includeLocation,
            () => onChanged(details.copyWith(includeLocation: !details.includeLocation))),
        chip('Tagline', details.includeTagline,
            () => onChanged(details.copyWith(includeTagline: !details.includeTagline))),
        chip('Category', details.includeCategory,
            () => onChanged(details.copyWith(includeCategory: !details.includeCategory))),
        chip('Hashtags', details.includeHashtags,
            () => onChanged(details.copyWith(includeHashtags: !details.includeHashtags))),
      ],
    );
  }
}

class _SocialPlatformRow extends StatelessWidget {
  const _SocialPlatformRow({
    required this.busy,
    required this.onWhatsApp,
    required this.onInstagram,
    required this.onFacebook,
    required this.onTikTok,
    required this.onTwitter,
    required this.onMore,
  });

  final bool busy;
  final VoidCallback onWhatsApp;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onTikTok;
  final VoidCallback onTwitter;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            tile(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), onWhatsApp),
            tile(Icons.camera_alt_rounded, 'Instagram', const Color(0xFFE1306C), onInstagram),
            tile(Icons.facebook_rounded, 'Facebook', const Color(0xFF1877F2), onFacebook),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(Icons.music_note_rounded, 'TikTok', Colors.white, onTikTok),
            tile(Icons.alternate_email_rounded, 'X', Colors.white70, onTwitter),
            tile(Icons.apps_rounded, 'More', DesignTokens.brandAccent, onMore),
          ],
        ),
      ],
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.items});
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Attach a product',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: DesignTokens.brandAccent.withValues(alpha: 0.15),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: DesignTokens.brandAccent),
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(formatUgPrice(item.price),
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
// Ad Preview Card
// ---------------------------------------------------------------------------

class _AdPreviewCard extends StatelessWidget {
  const _AdPreviewCard({
    required this.adFile,
    required this.template,
    this.showWatermarkBadge = false,
    this.displayTitle,
  });
  final File adFile;
  final AdTemplate template;
  final bool showWatermarkBadge;
  final String? displayTitle;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width - 32;
    final ar = template.canvasHeight > 0
        ? template.canvasWidth / template.canvasHeight
        : 1.0;
    final h = (sw / ar).clamp(200.0, 520.0);

    return Container(
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: Image.file(adFile, fit: BoxFit.cover)),
          if (showWatermarkBadge)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.water_drop_outlined, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text('Soko24',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayTitle ?? template.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: DesignTokens.brandAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartLinkCard extends StatelessWidget {
  const _SmartLinkCard({required this.link, required this.kit});
  final String link;
  final BrandKit kit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.brandAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: DesignTokens.brandAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Link',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(link,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                if (kit.businessName.isNotEmpty)
                  Text(
                    'Buyers tap → ${kit.businessName} on Soko24',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied!')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DesignTokens.brandAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded, color: DesignTokens.brandAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactsPanel extends ConsumerWidget {
  const _ContactsPanel({
    required this.q,
    required this.onQChanged,
    required this.onWhatsApp,
    required this.onClose,
  });
  final String q;
  final ValueChanged<String> onQChanged;
  final void Function(String phone) onWhatsApp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final contacts = state.contacts
        .where((c) => c.phone != null && c.phone!.isNotEmpty)
        .where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q.toLowerCase()) ||
              (c.phone?.contains(q) ?? false);
        })
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Text(
                'Send to Contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: onQChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (contacts.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No contacts with phone numbers',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: contacts.length,
              itemBuilder: (_, i) {
                final c = contacts[i];
                final initials = c.name
                    .split(' ')
                    .take(2)
                    .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
                    .join();
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: DesignTokens.brandAccent.withValues(alpha: 0.15),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: DesignTokens.brandAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      c.phone ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    trailing: GestureDetector(
                      onTap: () => onWhatsApp(c.phone!),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366), size: 18),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-size export selector
// ---------------------------------------------------------------------------

class _SizeSelectorDialog extends StatefulWidget {
  const _SizeSelectorDialog({this.current});
  final AdSize? current;

  @override
  State<_SizeSelectorDialog> createState() => _SizeSelectorDialogState();
}

class _SizeSelectorDialogState extends State<_SizeSelectorDialog> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final size in adSizes) {
      if (widget.current == null || size.label != widget.current!.label) {
        _selected.add(size.label);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DesignTokens.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Export more sizes',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: adSizes.length,
          itemBuilder: (_, i) {
            final size = adSizes[i];
            final checked = _selected.contains(size.label);
            return CheckboxListTile(
              dense: true,
              value: checked,
              activeColor: DesignTokens.brandAccent,
              side: const BorderSide(color: Colors.white24),
              title: Text(
                size.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                '${size.width.toInt()}×${size.height.toInt()}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onChanged: (_) {
                setState(() {
                  if (checked) {
                    _selected.remove(size.label);
                  } else {
                    _selected.add(size.label);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    adSizes.where((s) => _selected.contains(s.label)).toList(),
                  ),
          child: const Text('Export', style: TextStyle(color: DesignTokens.brandAccent)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-size export result sheet
// ---------------------------------------------------------------------------

class _MultiExportResultSheet extends StatelessWidget {
  const _MultiExportResultSheet({
    required this.files,
    required this.caption,
    required this.onShare,
    required this.onSave,
  });

  final List<File> files;
  final String caption;
  final void Function(List<File>) onShare;
  final void Function(List<File>) onSave;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${files.length} size${files.length == 1 ? '' : 's'} exported',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption.isNotEmpty ? caption : 'Ready to share or save.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final name = p.basename(files[i].path);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded, color: Colors.white38, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecBtn(
                    icon: Icons.ios_share_rounded,
                    label: 'Share all',
                    onTap: () {
                      Navigator.pop(context);
                      onShare(files);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SecBtn(
                    icon: Icons.download_rounded,
                    label: 'Save all',
                    onTap: () {
                      Navigator.pop(context);
                      onSave(files);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}

class _SecBtn extends StatelessWidget {
  const _SecBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}