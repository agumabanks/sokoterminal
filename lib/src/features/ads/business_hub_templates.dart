import 'package:flutter/material.dart';

import 'ad_templates.dart';
import '../../core/theme/design_tokens.dart';

/// Starter templates for Business Hub document types.
final businessHubTemplates = <AdTemplate>[
  // ── Logo ──────────────────────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_logo_monogram',
    name: 'Monogram Logo',
    category: 'logo',
    canvasWidth: 1080,
    canvasHeight: 1080,
    background: 'gradient:soko',
    previewColors: const [DesignTokens.brandPrimary, DesignTokens.brandAccent],
    elements: [
      CanvasElement(
        id: 'logo_circle', type: 'figure',
        x: 290, y: 290, width: 500, height: 500,
        fill: '#0EBE7E', cornerRadius: 250,
      ),
      CanvasElement(
        id: 'logo_letter', type: 'text', text: '{{BUSINESS}}',
        x: 140, y: 420, width: 800, fontSize: 120,
        fontWeight: '900', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'logo_tag', type: 'text', text: '{{TAGLINE}}',
        x: 140, y: 820, width: 800, fontSize: 28,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.8,
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_logo_wordmark',
    name: 'Wordmark Logo',
    category: 'logo',
    canvasWidth: 1080,
    canvasHeight: 540,
    background: '#0f172a',
    previewColors: const [DesignTokens.brandPrimary, DesignTokens.brandAccent],
    elements: [
      CanvasElement(
        id: 'wm_name', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 140, width: 960, fontSize: 88,
        fontWeight: '800', fontFamily: 'Bebas Neue', fill: '#0EBE7E', align: 'center',
      ),
      CanvasElement(
        id: 'wm_line', type: 'figure',
        x: 420, y: 280, width: 240, height: 4, fill: '#0EBE7E',
      ),
      CanvasElement(
        id: 'wm_tag', type: 'text', text: '{{TAGLINE}}',
        x: 60, y: 320, width: 960, fontSize: 26,
        fontFamily: 'Inter', fill: '#94a3b8', align: 'center', opacity: 0.9,
      ),
      CanvasElement(
        id: 'wm_contact', type: 'text', text: '{{PHONE}} · {{WHATSAPP}}',
        x: 60, y: 420, width: 960, fontSize: 20,
        fontFamily: 'Inter', fill: '#64748b', align: 'center', opacity: 0.75,
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_logo_premium',
    name: 'Premium Seal Logo',
    category: 'logo',
    canvasWidth: 1080,
    canvasHeight: 1080,
    background: '#fafafa',
    previewColors: const [Color(0xFFfafafa), Color(0xFF09090b)],
    elements: [
      CanvasElement(
        id: 'lp_ring', type: 'figure',
        x: 240, y: 240, width: 600, height: 600,
        fill: '#09090b', cornerRadius: 300,
      ),
      CanvasElement(
        id: 'lp_inner', type: 'figure',
        x: 290, y: 290, width: 500, height: 500,
        fill: '#ffffff', cornerRadius: 250,
      ),
      CanvasElement(
        id: 'lp_letter', type: 'text', text: '{{BUSINESS}}',
        x: 140, y: 430, width: 800, fontSize: 64,
        fontWeight: '900', fontFamily: 'Cormorant Garamond', fill: '#09090b', align: 'center',
      ),
      CanvasElement(
        id: 'lp_tag', type: 'text', text: '{{TAGLINE}}',
        x: 140, y: 820, width: 800, fontSize: 22,
        fontFamily: 'Inter', fill: '#71717a', align: 'center', letterSpacing: 3,
      ),
    ],
  ),

  // ── Product collage ───────────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_collage_grid',
    name: 'Product Grid Collage',
    category: 'collage',
    canvasWidth: 1080,
    canvasHeight: 1080,
    background: '#ffffff',
    previewColors: const [DesignTokens.canvas, DesignTokens.brandPrimary],
    elements: [
      for (var i = 0; i < 4; i++)
        CanvasElement(
          id: 'col_slot_$i', type: 'figure',
          x: i % 2 == 0 ? 40 : 550,
          y: i < 2 ? 120 : 560,
          width: 490, height: 420,
          fill: '#e2e8f0', cornerRadius: 16,
        ),
      CanvasElement(
        id: 'col_title', type: 'text', text: '{{BUSINESS}}',
        x: 40, y: 40, width: 1000, fontSize: 36,
        fontWeight: '700', fontFamily: 'Montserrat', fill: '#0f172a', align: 'center',
      ),
      CanvasElement(
        id: 'col_cta', type: 'text', text: 'Shop: {{CTA_LINK}}',
        x: 40, y: 1000, width: 1000, fontSize: 22,
        fontFamily: 'Inter', fill: '#64748b', align: 'center',
      ),
    ],
  ),

  // ── Menu ──────────────────────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_menu_classic',
    name: 'Classic Menu',
    category: 'menu',
    canvasWidth: 1080,
    canvasHeight: 1920,
    background: 'gradient:forest',
    previewColors: const [Color(0xFF14532d), Color(0xFF86efac)],
    elements: [
      CanvasElement(
        id: 'menu_title', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 80, width: 960, fontSize: 56,
        fontWeight: '800', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'menu_sub', type: 'text', text: 'MENU',
        x: 60, y: 160, width: 960, fontSize: 24,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.7,
      ),
      CanvasElement(
        id: 'menu_item1', type: 'text',
        text: '{{PRODUCT}}\n{{PRICE}}',
        x: 80, y: 280, width: 920, fontSize: 32,
        fontFamily: 'Inter', fill: '#ffffff', align: 'left',
      ),
      CanvasElement(
        id: 'menu_contact', type: 'text',
        text: '📞 {{PHONE}}  ·  💬 {{WHATSAPP}}',
        x: 60, y: 1780, width: 960, fontSize: 24,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_menu_modern',
    name: 'Modern Menu Board',
    category: 'menu',
    canvasWidth: 1080,
    canvasHeight: 1920,
    background: '#0f172a',
    previewColors: const [DesignTokens.brandPrimary, DesignTokens.brandAccent],
    elements: [
      CanvasElement(
        id: 'mm_bar', type: 'figure',
        x: 0, y: 0, width: 1080, height: 200, fill: '#0EBE7E',
      ),
      CanvasElement(
        id: 'mm_title', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 60, width: 960, fontSize: 48,
        fontWeight: '800', fontFamily: 'Montserrat', fill: '#0f172a', align: 'center',
      ),
      CanvasElement(
        id: 'mm_items', type: 'text',
        text: 'TODAY\'S SPECIALS\n\n{{PRODUCT}} · {{PRICE}}\n{{PRODUCT}} · {{PRICE}}',
        x: 80, y: 280, width: 920, fontSize: 34,
        fontFamily: 'Inter', fill: '#ffffff', align: 'left', lineHeight: 1.7,
      ),
      CanvasElement(
        id: 'mm_wa', type: 'text', text: 'Order: {{WHATSAPP}}',
        x: 60, y: 1780, width: 960, fontSize: 26,
        fontFamily: 'Inter', fill: '#0EBE7E', align: 'center',
      ),
    ],
  ),

  // ── Brochure / company profile ────────────────────────────────────────────
  AdTemplate(
    id: 'hub_brochure_cover',
    name: 'Brochure Cover',
    category: 'brochure',
    canvasWidth: 1080,
    canvasHeight: 1520,
    background: 'gradient:midnight',
    previewColors: const [DesignTokens.brandPrimary, Color(0xFF38bdf8)],
    elements: [
      CanvasElement(
        id: 'bro_title', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 500, width: 960, fontSize: 64,
        fontWeight: '700', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'bro_tag', type: 'text', text: '{{TAGLINE}}',
        x: 60, y: 620, width: 960, fontSize: 28,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.85,
      ),
      CanvasElement(
        id: 'bro_loc', type: 'text', text: '{{LOCATION}}',
        x: 60, y: 1380, width: 960, fontSize: 22,
        fontFamily: 'Inter', fill: '#94a3b8', align: 'center',
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_company_profile',
    name: 'Company Profile',
    category: 'company_profile',
    canvasWidth: 1080,
    canvasHeight: 1920,
    background: '#ffffff',
    previewColors: const [DesignTokens.canvas, DesignTokens.brandPrimary],
    elements: [
      CanvasElement(
        id: 'cp_head', type: 'figure',
        x: 0, y: 0, width: 1080, height: 320, fill: '#0F1D40',
      ),
      CanvasElement(
        id: 'cp_name', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 100, width: 960, fontSize: 48,
        fontWeight: '800', fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'cp_about', type: 'text',
        text: 'About Us\n\nWe deliver quality products and services across Uganda. Trusted by customers nationwide.',
        x: 80, y: 400, width: 920, fontSize: 26,
        fontFamily: 'Inter', fill: '#334155', align: 'left', lineHeight: 1.5,
      ),
      CanvasElement(
        id: 'cp_contact', type: 'text',
        text: '📞 {{PHONE}}\n💬 {{WHATSAPP}}\n📍 {{LOCATION}}\n🔗 {{CTA_LINK}}',
        x: 80, y: 1500, width: 920, fontSize: 24,
        fontFamily: 'Inter', fill: '#0F1D40', align: 'left', lineHeight: 1.6,
      ),
    ],
  ),

  // ── Invitation ────────────────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_invitation_elegant',
    name: 'Elegant Invitation',
    category: 'invitation',
    canvasWidth: 1080,
    canvasHeight: 1920,
    background: 'gradient:velvet',
    previewColors: const [Color(0xFF4c1d95), Color(0xFFfef08a)],
    elements: [
      CanvasElement(
        id: 'inv_head', type: 'text', text: "You're Invited",
        x: 60, y: 200, width: 960, fontSize: 36,
        fontFamily: 'Cormorant Garamond', fill: '#fef08a', align: 'center',
      ),
      CanvasElement(
        id: 'inv_event', type: 'text', text: 'GRAND OPENING',
        x: 60, y: 320, width: 960, fontSize: 72,
        fontWeight: '800', fontFamily: 'Playfair Display', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'inv_biz', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 480, width: 960, fontSize: 32,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center', opacity: 0.9,
      ),
      CanvasElement(
        id: 'inv_loc', type: 'text', text: '{{LOCATION}}',
        x: 60, y: 1680, width: 960, fontSize: 24,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
    ],
  ),

  // ── Flyers ────────────────────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_event_flyer',
    name: 'Event Flyer',
    category: 'event_flyer',
    canvasWidth: 1080,
    canvasHeight: 1520,
    background: 'gradient:fire',
    previewColors: const [Color(0xFFdc2626), Color(0xFFfef08a)],
    elements: [
      CanvasElement(
        id: 'ef_title', type: 'text', text: 'BIG EVENT',
        x: 60, y: 120, width: 960, fontSize: 80,
        fontWeight: '900', fontFamily: 'Anton', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'ef_sub', type: 'text', text: '{{BUSINESS}} invites you',
        x: 60, y: 260, width: 960, fontSize: 28,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'ef_cta', type: 'text', text: 'RSVP: {{WHATSAPP}}',
        x: 60, y: 1360, width: 960, fontSize: 32,
        fontWeight: '700', fontFamily: 'Montserrat', fill: '#fef08a', align: 'center',
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_service_flyer',
    name: 'Service Flyer',
    category: 'service_flyer',
    canvasWidth: 1080,
    canvasHeight: 1520,
    background: 'gradient:arctic',
    previewColors: const [Color(0xFF0e7490), Color(0xFF99f6e4)],
    elements: [
      CanvasElement(
        id: 'sf_title', type: 'text', text: '{{PRODUCT}}',
        x: 60, y: 200, width: 960, fontSize: 56,
        fontWeight: '800', fontFamily: 'Oswald', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'sf_price', type: 'text', text: 'From {{PRICE}}',
        x: 60, y: 320, width: 960, fontSize: 40,
        fontFamily: 'Inter', fill: '#fef08a', align: 'center',
      ),
      CanvasElement(
        id: 'sf_biz', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 1280, width: 960, fontSize: 28,
        fontFamily: 'Montserrat', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'sf_wa', type: 'text', text: 'Book: {{WHATSAPP}}',
        x: 60, y: 1360, width: 960, fontSize: 26,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_event_neon',
    name: 'Neon Night Event',
    category: 'event_flyer',
    canvasWidth: 1080,
    canvasHeight: 1520,
    background: 'gradient:midnight',
    previewColors: const [DesignTokens.brandPrimary, Color(0xFFa855f7)],
    elements: [
      CanvasElement(
        id: 'ne_title', type: 'text', text: 'LIVE\nTONIGHT',
        x: 60, y: 180, width: 960, fontSize: 96,
        fontWeight: '900', fontFamily: 'Anton', fill: '#a855f7', align: 'center',
      ),
      CanvasElement(
        id: 'ne_biz', type: 'text', text: '@ {{BUSINESS}}',
        x: 60, y: 420, width: 960, fontSize: 32,
        fontFamily: 'Inter', fill: '#ffffff', align: 'center',
      ),
      CanvasElement(
        id: 'ne_loc', type: 'text', text: '{{LOCATION}}',
        x: 60, y: 1320, width: 960, fontSize: 28,
        fontFamily: 'Inter', fill: '#22d3ee', align: 'center',
      ),
    ],
  ),

  // ── Business card (print ratio ~ 1050×600) ────────────────────────────────
  AdTemplate(
    id: 'hub_business_card_luxe',
    name: 'Luxe Business Card',
    category: 'business_card',
    canvasWidth: 1050,
    canvasHeight: 600,
    background: '#fafafa',
    previewColors: const [Color(0xFFfafafa), Color(0xFF09090b)],
    elements: [
      CanvasElement(
        id: 'bcl_bar', type: 'figure',
        x: 0, y: 0, width: 12, height: 600, fill: '#09090b',
      ),
      CanvasElement(
        id: 'bcl_name', type: 'text', text: '{{BUSINESS}}',
        x: 80, y: 140, width: 900, fontSize: 44,
        fontWeight: '700', fontFamily: 'Cormorant Garamond', fill: '#09090b', align: 'left',
      ),
      CanvasElement(
        id: 'bcl_role', type: 'text', text: '{{TAGLINE}}',
        x: 80, y: 210, width: 900, fontSize: 16,
        fontFamily: 'Inter', fill: '#71717a', align: 'left', letterSpacing: 2,
      ),
      CanvasElement(
        id: 'bcl_line', type: 'figure',
        x: 80, y: 280, width: 120, height: 2, fill: '#09090b',
      ),
      CanvasElement(
        id: 'bcl_contact', type: 'text',
        text: '{{PHONE}}\n{{WHATSAPP}}\n{{LOCATION}}',
        x: 80, y: 360, width: 500, fontSize: 17,
        fontFamily: 'Inter', fill: '#3f3f46', align: 'left', lineHeight: 1.6,
      ),
      CanvasElement(
        id: 'bcl_web', type: 'text', text: '{{CTA_LINK}}',
        x: 540, y: 480, width: 450, fontSize: 14,
        fontFamily: 'Inter', fill: '#a1a1aa', align: 'right',
      ),
    ],
  ),
  AdTemplate(
    id: 'hub_business_card',
    name: 'Business Card',
    category: 'business_card',
    canvasWidth: 1050,
    canvasHeight: 600,
    background: '#0F1D40',
    previewColors: const [DesignTokens.brandPrimary, DesignTokens.brandAccent],
    elements: [
      CanvasElement(
        id: 'bc_name', type: 'text', text: '{{BUSINESS}}',
        x: 60, y: 120, width: 930, fontSize: 42,
        fontWeight: '800', fontFamily: 'Montserrat', fill: '#ffffff', align: 'left',
      ),
      CanvasElement(
        id: 'bc_tag', type: 'text', text: '{{TAGLINE}}',
        x: 60, y: 190, width: 930, fontSize: 18,
        fontFamily: 'Inter', fill: '#0EBE7E', align: 'left',
      ),
      CanvasElement(
        id: 'bc_phone', type: 'text', text: '{{PHONE}}',
        x: 60, y: 400, width: 450, fontSize: 20,
        fontFamily: 'Inter', fill: '#ffffff', align: 'left',
      ),
      CanvasElement(
        id: 'bc_wa', type: 'text', text: '{{WHATSAPP}}',
        x: 60, y: 440, width: 450, fontSize: 20,
        fontFamily: 'Inter', fill: '#ffffff', align: 'left',
      ),
      CanvasElement(
        id: 'bc_web', type: 'text', text: '{{CTA_LINK}}',
        x: 540, y: 420, width: 450, fontSize: 18,
        fontFamily: 'Inter', fill: '#94a3b8', align: 'right',
      ),
    ],
  ),

  // ── Invoice (A4 portrait) ─────────────────────────────────────────────────
  AdTemplate(
    id: 'hub_invoice_a4',
    name: 'Invoice A4',
    category: 'invoice',
    canvasWidth: 2480,
    canvasHeight: 3508,
    background: '#ffffff',
    elements: [
      CanvasElement(
        id: 'inv_logo_bar', type: 'figure',
        x: 0, y: 0, width: 2480, height: 200, fill: '#0F1D40',
      ),
      CanvasElement(
        id: 'inv_biz', type: 'text', text: '{{BUSINESS}}',
        x: 120, y: 60, width: 1200, fontSize: 56,
        fontWeight: '800', fontFamily: 'Montserrat', fill: '#ffffff', align: 'left',
      ),
      CanvasElement(
        id: 'inv_title', type: 'text', text: 'INVOICE',
        x: 1600, y: 60, width: 760, fontSize: 56,
        fontWeight: '800', fontFamily: 'Inter', fill: '#0EBE7E', align: 'right',
      ),
      CanvasElement(
        id: 'inv_meta', type: 'text',
        text: 'Date: ___________\nInvoice #: ___________',
        x: 1600, y: 280, width: 760, fontSize: 32,
        fontFamily: 'Inter', fill: '#64748b', align: 'right',
      ),
      CanvasElement(
        id: 'inv_table', type: 'text',
        text: 'Item                          Qty    Price    Total\n'
            '────────────────────────────────────────────────\n'
            '{{PRODUCT}}                    1    {{PRICE}}   {{PRICE}}\n'
            '────────────────────────────────────────────────\n'
            '                                    TOTAL  {{PRICE}}',
        x: 120, y: 500, width: 2240, fontSize: 36,
        fontFamily: 'Inter', fill: '#1e293b', align: 'left', lineHeight: 1.8,
      ),
      CanvasElement(
        id: 'inv_footer', type: 'text',
        text: 'Thank you for your business!\n{{PHONE}} · {{WHATSAPP}} · {{LOCATION}}',
        x: 120, y: 3200, width: 2240, fontSize: 28,
        fontFamily: 'Inter', fill: '#64748b', align: 'center',
      ),
    ],
  ),
];

/// All studio templates: business hub + built-in ads.
List<AdTemplate> get allStudioTemplates => [
      ...businessHubTemplates,
      ...builtInTemplates,
];

/// Lazily-built index for O(1) template lookups.
AdTemplate? templateById(String id) {
  final cache = _templateByIdCache;
  if (cache != null) return cache[id];
  final built = <String, AdTemplate>{};
  for (final t in allStudioTemplates) {
    built[t.id] = t;
  }
  _templateByIdCache = built;
  return built[id];
}

Map<String, AdTemplate>? _templateByIdCache;

/// All hub templates for a document category.
List<AdTemplate> templatesForCategory(String category) =>
    businessHubTemplates.where((t) => t.category == category).toList();