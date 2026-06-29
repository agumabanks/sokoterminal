import '../../core/db/app_database.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'creative_overlay_catalog.dart';

// ---------------------------------------------------------------------------
// Smart overlay picker for Studio ads
//
// Picks a single contextual marketing overlay based on the product/service
// being advertised. The returned elements are styled by the brand kit and
// use the same professional builders as the manual overlay catalog.
// ---------------------------------------------------------------------------

/// Returns a single contextual overlay for the given product/service context.
///
/// Rules (first match wins, only one overlay per ad):
/// 1. Product has a discount > 0 -> "% OFF" badge.
/// 2. Product is new (updated within the last 7 days) -> "NEW" badge.
/// 3. Product stock is tracked and low (<= 5) -> "LIMITED STOCK" banner.
/// 4. Service is present and contact hours/info available -> "NOW OPEN" banner.
/// 5. Fallback -> "VERIFIED" trust badge.
List<CanvasElement> pickOverlayForContext({
  required Item? product,
  required Service? service,
  required BrandKit kit,
  required double canvasWidth,
  required double canvasHeight,
}) {
  String? overlayId;

  if (product != null) {
    final discount = product.discount;
    if (discount != null && discount > 0) {
      overlayId = 'percent_off_badge';
    } else {
      // The local item schema does not store a createdAt timestamp, so we use
      // updatedAt as a proxy for "newly added".
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      if (product.updatedAt.isAfter(sevenDaysAgo)) {
        overlayId = 'new_badge';
      } else if (product.stockEnabled && product.stockQty <= 5) {
        overlayId = 'limited_stock_badge';
      }
    }
  }

  if (overlayId == null && service != null) {
    // Treat available contact info as a proxy for "business hours available".
    final hasContactInfo = kit.phone.isNotEmpty || kit.whatsapp.isNotEmpty;
    overlayId = hasContactInfo ? 'now_open_banner' : 'contact_card';
  }

  overlayId ??= 'verified_badge';

  final overlay = creativeOverlayCatalog.firstWhere(
    (o) => o.id == overlayId,
    orElse: () => creativeOverlayCatalog.first,
  );

  return overlay.build(
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    kit: kit,
    context: null,
    product: product,
  );
}
