import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import 'ad_editor_screen.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'business_hub_templates.dart';
import 'studio_design_storage.dart';
import 'studio_product_utils.dart';
import 'studio_recent_designs.dart';
import 'studio_screen.dart';
import 'studio_template_exporter.dart';
import 'studio_theme.dart';
import '../../core/util/haptics.dart';
import 'full_studio_webview_screen.dart';

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
  String productLink = '';
  try {
    productLink = await resolveProductShareLink(
      product: product,
      kit: kit,
      api: ref.read(sellerApiProvider),
    );
  } catch (e, st) {
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(telemetry.recordError(e, st, hint: 'studio_resolve_product_link'));
    }
    // Continue with empty link — editor still works offline.
  }
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

  final telemetry = Telemetry.instance;
  if (telemetry != null) {
    unawaited(telemetry.event('studio_editor_open', props: {
      'template_id': template.id,
      'template_name': template.name,
      'has_product': product != null,
    }));
  }

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

/// Open the native Studio editor for a service and return the exported PNG file.
///
/// The user can edit the design, then tapping Save exports a cover image to a
/// temporary file. If the editor is closed without saving, `null` is returned.
Future<File?> launchStudioForService(
  BuildContext context,
  WidgetRef ref, {
  required Service service,
  AdTemplate? template,
}) async {
  final kit = ref.read(brandKitProvider);
  final baseTemplate = template ??
      templateById('tpl_service_bold') ??
      builtInTemplates.firstWhere(
        (t) => t.category == 'service',
        orElse: () => blankCanvas(adSizes.first),
      );

  final shopUrl = service.remoteId != null
      ? 'https://soko24.co/s/${service.remoteId}'
      : '';

  final applied = baseTemplate.applyService(
    serviceName: service.title,
    priceFormatted: formatUgPrice(service.price),
    imageUrl: service.imageUrl ?? '',
    shopUrl: shopUrl,
    category: service.category,
    whatsappNumber: kit.whatsapp,
    phoneNumber: kit.phone,
    businessName: kit.businessName,
    location: kit.location,
    tagline: kit.tagline,
  );

  File? result;
  if (!context.mounted) return null;
  Haptics.selection();
  await Navigator.of(context).push(
    studioPageRoute(
      AdEditorScreen(
        template: applied,
        onSave: (edited) async {
          Haptics.success();
          ref.read(savedTemplatesProvider.notifier).save(edited);
          await ref.read(recentDesignsProvider.notifier).add(edited);
          await ref.read(yourDesignsProvider.notifier).saveDesign(edited);
          if (!context.mounted) return;
          final file = await exportStudioTemplatePng(
            context,
            template: edited,
            applyWatermark: false,
            pixelRatio: 1.5,
          );
          result = file;
        },
      ),
    ),
  );
  return result;
}

/// Launch the full Soko Studio web editor from the given entity context.
Future<void> launchFullStudioWeb(
  BuildContext context,
  WidgetRef ref, {
  int? productId,
  int? serviceId,
  String? quotationId,
  int? receiptId,
  bool brandKit = false,
  String openPanel = 'templates',
}) async {
  // Pre-flight connectivity check so we fail fast with a helpful message.
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity.contains(ConnectivityResult.none)) {
    if (!context.mounted) return;
    _showStudioError(context, 'No internet connection. Please connect and try again.');
    return;
  }

  try {
    final api = ref.read(sellerApiProvider);
    final res = await api
        .studioWebEntry(
          productId: productId,
          serviceId: serviceId,
          quotationId: quotationId,
          receiptId: receiptId,
          brandKit: brandKit,
          openPanel: openPanel,
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Studio is taking too long to respond. Please try again.',
          ),
        );
    final data = res.data;
    final url = data is Map ? data['url']?.toString() : null;
    if (url == null || url.isEmpty) {
      throw Exception('No studio URL returned');
    }

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event('studio_web_open', props: {
          if (productId != null) 'product_id': productId,
          if (serviceId != null) 'service_id': serviceId,
          if (quotationId != null) 'quotation_id': quotationId,
          if (receiptId != null) 'receipt_id': receiptId,
          'brand_kit': brandKit,
          'open_panel': openPanel,
        }),
      );
    }

    Haptics.selection();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullStudioWebViewScreen(initialUrl: url),
      ),
    );
  } catch (e, st) {
    debugPrint('[launchFullStudioWeb] error: $e\n$st');
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.recordError(e, st, hint: 'launch_full_studio_web'),
      );
    }
    if (!context.mounted) return;
    final message = _userFacingStudioError(e);
    _showStudioError(context, message);
  }
}

String _userFacingStudioError(Object error) {
  final message = error.toString().toLowerCase();
  if (error is TimeoutException || message.contains('timeout')) {
    return 'Studio is taking too long to respond. Please try again.';
  }
  if (message.contains('socket') ||
      message.contains('network') ||
      message.contains('connection')) {
    return 'Network error. Please check your connection and try again.';
  }
  if (message.contains('401') || message.contains('403')) {
    return 'Session expired. Please log in again and retry.';
  }
  return 'Could not open Studio. Please try again.';
}

void _showStudioError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: DesignTokens.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'DISMISS',
        textColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

void _showStudioSyncNeeded(BuildContext context, String entityLabel) {
  _showStudioError(
    context,
    '$entityLabel must sync with the server before opening in Studio.',
  );
}

void _logStudioEntityResolve({
  required String entityType,
  required bool success,
  String? entityId,
}) {
  final telemetry = Telemetry.instance;
  if (telemetry == null) return;
  unawaited(
    telemetry.event(
      success ? 'studio_entity_resolve_success' : 'studio_entity_resolve_fail',
      props: {
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
      },
    ),
  );
}

/// Open Studio for a product using its backend id.
Future<void> launchFullStudioWebForProduct(
  BuildContext context,
  WidgetRef ref,
  Item item, {
  String openPanel = 'smart-ads',
}) async {
  final remoteId = item.remoteId;
  if (remoteId == null) {
    _logStudioEntityResolve(
      entityType: 'product',
      success: false,
      entityId: item.id,
    );
    if (context.mounted) _showStudioSyncNeeded(context, 'Product');
    return;
  }
  _logStudioEntityResolve(
    entityType: 'product',
    success: true,
    entityId: remoteId.toString(),
  );
  await launchFullStudioWeb(
    context,
    ref,
    productId: remoteId,
    openPanel: openPanel,
  );
}

/// Open Studio for a service using its backend id.
Future<void> launchFullStudioWebForService(
  BuildContext context,
  WidgetRef ref,
  Service service, {
  String openPanel = 'smart-ads',
}) async {
  final remoteId = service.remoteId;
  if (remoteId == null) {
    _logStudioEntityResolve(
      entityType: 'service',
      success: false,
      entityId: service.id,
    );
    if (context.mounted) _showStudioSyncNeeded(context, 'Service');
    return;
  }
  _logStudioEntityResolve(
    entityType: 'service',
    success: true,
    entityId: remoteId.toString(),
  );
  await launchFullStudioWeb(
    context,
    ref,
    serviceId: remoteId,
    openPanel: openPanel,
  );
}

/// Open Studio for a quotation using its backend id.
Future<void> launchFullStudioWebForQuotation(
  BuildContext context,
  WidgetRef ref,
  Quotation quotation, {
  String openPanel = 'business-branding',
}) async {
  final remoteId = quotation.remoteId;
  if (remoteId == null || remoteId.isEmpty) {
    _logStudioEntityResolve(
      entityType: 'quotation',
      success: false,
      entityId: quotation.id,
    );
    if (context.mounted) _showStudioSyncNeeded(context, 'Quotation');
    return;
  }
  _logStudioEntityResolve(
    entityType: 'quotation',
    success: true,
    entityId: remoteId,
  );
  await launchFullStudioWeb(
    context,
    ref,
    quotationId: remoteId,
    openPanel: openPanel,
  );
}

/// Open Studio for a receipt/ledger entry using its backend id.
Future<void> launchFullStudioWebForReceipt(
  BuildContext context,
  WidgetRef ref,
  LedgerEntry entry, {
  String openPanel = 'business-branding',
}) async {
  final remoteId = entry.remoteId;
  if (remoteId == null || remoteId.isEmpty) {
    _logStudioEntityResolve(
      entityType: 'receipt',
      success: false,
      entityId: entry.id,
    );
    if (context.mounted) _showStudioSyncNeeded(context, 'Receipt');
    return;
  }
  final receiptId = int.tryParse(remoteId);
  if (receiptId == null) {
    _logStudioEntityResolve(
      entityType: 'receipt',
      success: false,
      entityId: entry.id,
    );
    if (context.mounted) _showStudioError(context, 'Invalid receipt id.');
    return;
  }
  _logStudioEntityResolve(
    entityType: 'receipt',
    success: true,
    entityId: remoteId,
  );
  await launchFullStudioWeb(
    context,
    ref,
    receiptId: receiptId,
    openPanel: openPanel,
  );
}

/// Open Studio directly to the brand kit panel.
Future<void> launchFullStudioWebForBrandKit(
  BuildContext context,
  WidgetRef ref, {
  String openPanel = 'brand-kit',
}) async {
  _logStudioEntityResolve(entityType: 'brand_kit', success: true);
  await launchFullStudioWeb(
    context,
    ref,
    brandKit: true,
    openPanel: openPanel,
  );
}