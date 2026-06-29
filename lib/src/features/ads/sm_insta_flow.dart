import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import 'ad_caption_generator.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_hub_templates.dart';
import 'studio_design_storage.dart';
import 'studio_entitlements.dart';
import 'studio_overlay_helper.dart';
import 'studio_product_utils.dart';
import 'studio_providers.dart';
import 'studio_recent_designs.dart';
import 'studio_share_sheet.dart';
import 'studio_template_exporter.dart';

// ---------------------------------------------------------------------------
// SM Insta — camera to ad in seconds
// ---------------------------------------------------------------------------

/// Run the full SM Insta flow: camera → auto-styled ad → share sheet.
Future<void> runSmInstaFlow(BuildContext context, WidgetRef ref) async {
  final telemetry = Telemetry.instance;
  telemetry?.event('sm_insta_start');

  final permission = await _ensureCameraPermission(context);
  if (!permission) return;
  if (!context.mounted) return;

  final picker = ImagePicker();
  final xf = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1536,
    imageQuality: 92,
  );
  if (xf == null || !context.mounted) return;

  Haptics.impact();
  telemetry?.event('sm_insta_capture');

  final options = await showModalBottomSheet<_SmInstaOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.brandPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SmInstaOptionsSheet(),
  );
  if (options == null || !context.mounted) return;

  final product = ref.read(studioProductProvider);
  final kit = ref.read(brandKitProvider);

  String shopUrl = '';
  try {
    shopUrl = await resolveProductShareLink(
      product: product,
      kit: kit,
      api: ref.read(sellerApiProvider),
    );
  } catch (e, st) {
    telemetry?.recordError(e, st, hint: 'sm_insta_resolve_link');
  }

  if (!context.mounted) return;

  File? flippedFile;
  try {
    flippedFile = await prepareSmInstaPhoto(
      xf.path,
      flip: options.flip,
    );
  } catch (e, st) {
    telemetry?.recordError(e, st, hint: 'sm_insta_prepare_photo');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not prepare photo — try again')),
      );
    }
    return;
  }

  final photoSrc = 'file://${flippedFile.path}';

  final template = buildSmInstaTemplate(
    photoSrc: photoSrc,
    style: options.style,
    kit: kit,
    product: product,
    shopUrl: shopUrl,
  );

  if (!context.mounted) return;

  File? adFile;
  final entitlements = await ref.read(studioEntitlementsProvider.future);

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ExportingDialog(),
  );
  if (!context.mounted) return;

  try {
    adFile = await exportStudioTemplatePng(
      context,
      template: template,
      applyWatermark: entitlements.needsSokoWatermark,
      pixelRatio: 2.0,
    );

    if (adFile != null) {
      unawaited(ref.read(studioCampaignAnalyticsProvider.notifier).recordExport());
      ref.read(recentDesignsProvider.notifier).add(template);
      await ref.read(yourDesignsProvider.notifier).saveDesign(template);
    }
  } catch (e, st) {
    telemetry?.recordError(e, st, hint: 'sm_insta_export');
  } finally {
    if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (adFile == null || !context.mounted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create ad — try again')),
      );
    }
    return;
  }

  final shareFile = adFile;

  Haptics.success();
  telemetry?.event('sm_insta_export', props: {
    'style': options.style.name,
    'flip': options.flip,
    'has_product': product != null,
  });

  final productName = product?.name ?? kit.businessName;
  final price = product != null ? formatUgPrice(product.price) : '';
  final caption = generateCaption(
    platform: CaptionPlatform.instagram,
    productName: productName.isNotEmpty ? productName : 'Check this out',
    price: price.isNotEmpty ? price : '',
    businessName: kit.businessName.isNotEmpty ? kit.businessName : 'Soko24',
    shopUrl: shopUrl.isNotEmpty ? shopUrl : 'soko24.co',
    whatsapp: kit.whatsapp,
    phone: kit.phone,
    location: kit.location,
    tagline: kit.tagline,
  ).fullText;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StudioShareSheet(
        adFile: shareFile,
        template: template,
        kit: kit,
        initialProduct: product,
        initialCaption: caption,
        showWatermarkBadge: entitlements.needsSokoWatermark,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Permission
// ---------------------------------------------------------------------------

Future<bool> _ensureCameraPermission(BuildContext context) async {
  final status = await Permission.camera.status;
  if (status.isGranted || status.isLimited) return true;

  final requested = await Permission.camera.request();
  if (requested.isGranted || requested.isLimited) return true;
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DesignTokens.brandPrimary,
      title: const Text(
        'Camera access needed',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'SM Insta uses your camera to turn a product photo into an ad instantly.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  return false;
}

// ---------------------------------------------------------------------------
// Photo preparation
// ---------------------------------------------------------------------------

Future<File> prepareSmInstaPhoto(
  String originalPath, {
  required bool flip,
  Directory? outputDir,
}) async {
  if (!flip) return File(originalPath);

  final file = File(originalPath);
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Could not decode camera image');

  final mirrored = img.copyFlip(decoded, direction: img.FlipDirection.horizontal);
  final dir = outputDir ?? await getTemporaryDirectory();
  final out = File(p.join(
    dir.path,
    'sminsta_flipped_${DateTime.now().millisecondsSinceEpoch}.png',
  ));
  await out.writeAsBytes(img.encodePng(mirrored));
  return out;
}

// ---------------------------------------------------------------------------
// Template builder
// ---------------------------------------------------------------------------

enum SmInstaStyle {
  smart,
  sale,
  newArrival,
  minimal,
  whatsApp,
}

extension SmInstaStyleX on SmInstaStyle {
  String get label => switch (this) {
        SmInstaStyle.smart => 'Smart',
        SmInstaStyle.sale => 'Sale',
        SmInstaStyle.newArrival => 'New',
        SmInstaStyle.minimal => 'Minimal',
        SmInstaStyle.whatsApp => 'WhatsApp',
      };

  IconData get icon => switch (this) {
        SmInstaStyle.smart => Icons.auto_awesome_rounded,
        SmInstaStyle.sale => Icons.local_offer_rounded,
        SmInstaStyle.newArrival => Icons.star_rounded,
        SmInstaStyle.minimal => Icons.crop_rounded,
        SmInstaStyle.whatsApp => Icons.chat_rounded,
      };
}

AdTemplate buildSmInstaTemplate({
  required String photoSrc,
  required SmInstaStyle style,
  required BrandKit kit,
  Item? product,
  String shopUrl = '',
}) {
  final base = _baseTemplateForStyle(style);

  var template = base.applyProduct(
    productName: product?.name ?? kit.businessName,
    priceFormatted: product != null ? formatUgPrice(product.price) : '',
    imageUrl: photoSrc,
    shopUrl: shopUrl,
    category: product?.categoryName,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
  );

  final overlay = pickOverlayForContext(
    product: product,
    service: null,
    kit: kit,
    canvasWidth: template.canvasWidth,
    canvasHeight: template.canvasHeight,
  );

  if (overlay.isNotEmpty) {
    template = AdTemplate(
      id: '${template.id}_overlay',
      name: template.name,
      category: template.category,
      canvasWidth: template.canvasWidth,
      canvasHeight: template.canvasHeight,
      background: template.background,
      elements: [...template.elements, ...overlay],
      previewColors: template.previewColors,
      tags: template.tags,
      industry: template.industry,
      season: template.season,
      complexity: template.complexity,
      suggestedCaption: template.suggestedCaption,
      marketingGoal: template.marketingGoal,
    );
  }

  return template;
}

AdTemplate _baseTemplateForStyle(SmInstaStyle style) {
  switch (style) {
    case SmInstaStyle.sale:
      return templateById('tpl_sale_bold') ?? _fallbackSmInstaTemplate();
    case SmInstaStyle.newArrival:
      return templateById('tpl_new_arrival') ?? _fallbackSmInstaTemplate();
    case SmInstaStyle.minimal:
      return templateById('tpl_minimal') ?? _fallbackSmInstaTemplate();
    case SmInstaStyle.whatsApp:
      return templateById('tpl_whatsapp') ?? _fallbackSmInstaTemplate();
    case SmInstaStyle.smart:
      return _fallbackSmInstaTemplate();
  }
}

AdTemplate _fallbackSmInstaTemplate() =>
    templateById('tpl_sminsta') ??
    AdTemplate(
      id: 'tpl_sminsta_fallback',
      name: 'SM Insta',
      category: 'camera',
      canvasWidth: 1080,
      canvasHeight: 1350,
      background: '#000000',
      elements: const [
        CanvasElement(
          id: 'photo',
          type: 'image',
          src: '',
          x: 0,
          y: 0,
          width: 1080,
          height: 1080,
          imageFit: 'cover',
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Options sheet
// ---------------------------------------------------------------------------

class _SmInstaOptions {
  const _SmInstaOptions({required this.style, required this.flip});
  final SmInstaStyle style;
  final bool flip;
}

class _SmInstaOptionsSheet extends StatefulWidget {
  const _SmInstaOptionsSheet();

  @override
  State<_SmInstaOptionsSheet> createState() => _SmInstaOptionsSheetState();
}

class _SmInstaOptionsSheetState extends State<_SmInstaOptionsSheet> {
  SmInstaStyle _style = SmInstaStyle.smart;
  bool _flip = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Flip what you see',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a style, then share in seconds.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: SmInstaStyle.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final style = SmInstaStyle.values[i];
                final selected = _style == style;
                return GestureDetector(
                  onTap: () {
                    Haptics.selection();
                    setState(() => _style = style);
                  },
                  child: Container(
                    width: 74,
                    decoration: BoxDecoration(
                      color: selected
                          ? DesignTokens.brandAccent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? DesignTokens.brandAccent
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(style.icon,
                            color: selected
                                ? DesignTokens.brandAccent
                                : Colors.white54,
                            size: 24),
                        const SizedBox(height: 8),
                        Text(
                          style.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            value: _flip,
            onChanged: (v) {
              Haptics.selection();
              setState(() => _flip = v);
            },
            activeThumbColor: DesignTokens.brandAccent,
            title: const Text(
              'Mirror flip',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Flip the photo horizontally',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Haptics.impact();
                Navigator.pop(
                  context,
                  _SmInstaOptions(style: _style, flip: _flip),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text(
                'Create ad',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exporting dialog
// ---------------------------------------------------------------------------

class _ExportingDialog extends StatelessWidget {
  const _ExportingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: Colors.transparent,
      child: Card(
        color: DesignTokens.brandPrimary,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Creating your ad…', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
