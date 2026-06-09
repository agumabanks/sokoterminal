import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import 'ad_editor_screen.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'studio_design_storage.dart';
import 'studio_product_utils.dart';
import 'studio_recent_designs.dart';
import 'studio_screen.dart';
import 'studio_theme.dart';
import '../../core/util/haptics.dart';
/// Starter canvas for photo edit / remove-background flows.
AdTemplate photoEditStarter(String imageSrc) => AdTemplate(
      id: 'photo_edit_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Photo Edit',
      category: 'photo',
      canvasWidth: 1080,
      canvasHeight: 1080,
      background: '#ffffff',
      elements: [
        CanvasElement(
          id: 'photo_main',
          type: 'image',
          src: imageSrc,
          x: 40,
          y: 40,
          width: 1000,
          height: 1000,
          cornerRadius: 8,
        ),
      ],
    );

/// Open the studio editor with full product/brand variable wiring.
Future<void> launchStudioEditor(
  BuildContext context,
  WidgetRef ref, {
  required AdTemplate template,
  Item? product,
  String? initialPanel,
  bool popOnSave = true,
}) async {
  final kit = ref.read(brandKitProvider);
  final productLink = await resolveProductShareLink(
    product: product,
    kit: kit,
    api: ref.read(sellerApiProvider),
  );
  final applied = template.applyProduct(
    productName: product?.name ?? '',
    priceFormatted: product != null ? formatUgPrice(product.price) : '',
    imageUrl: product?.imageUrl ?? '',
    shopUrl: productLink,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
  );

  if (!context.mounted) return;
  Haptics.selection();
  await Navigator.of(context).push(
    studioPageRoute(
      AdEditorScreen(
        template: applied,
        product: product,
        productLink: productLink,
        initialPanel: initialPanel,
        onSave: (edited) async {
          Haptics.success();
          ref.read(savedTemplatesProvider.notifier).save(edited);
          await ref.read(recentDesignsProvider.notifier).add(edited);
          final cloudOk =
              await ref.read(yourDesignsProvider.notifier).saveDesign(edited);
          if (!context.mounted) return;
          if (popOnSave) Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cloudOk
                  ? 'Design saved — device folder & Sanaa Cloud'
                  : 'Design saved locally (cloud sync when online)'),
            ),
          );
        },
      ),
    ),
  );
}