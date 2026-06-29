
import 'ad_templates.dart';

// ---------------------------------------------------------------------------
// Modern Element Presets — 40+ design elements for Soko Studio
// ---------------------------------------------------------------------------

class ModernElementPreset {
  const ModernElementPreset({
    required this.id,
    required this.label,
    required this.category,
    required this.element,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final String category;
  final CanvasElement element;
  final bool isPremium;
}

// ---------------------------------------------------------------------------
// Gradient Orbs & Glass Effects
// ---------------------------------------------------------------------------
const _orbElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'orb_green',
    label: 'Green Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_green', type: 'figure',
      width: 400, height: 400,
      fill: '#0EBE7E', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'orb_blue',
    label: 'Blue Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_blue', type: 'figure',
      width: 400, height: 400,
      fill: '#3b82f6', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'orb_pink',
    label: 'Pink Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_pink', type: 'figure',
      width: 400, height: 400,
      fill: '#ec4899', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'orb_purple',
    label: 'Purple Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_purple', type: 'figure',
      width: 400, height: 400,
      fill: '#7c3aed', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'orb_orange',
    label: 'Orange Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_orange', type: 'figure',
      width: 400, height: 400,
      fill: '#f97316', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'orb_gold',
    label: 'Gold Orb',
    category: 'orbs',
    element: CanvasElement(
      id: 'orb_gold', type: 'figure',
      width: 400, height: 400,
      fill: '#d4af37', cornerRadius: 200,
      opacity: 0.25,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Glass Cards
// ---------------------------------------------------------------------------
const _glassElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'glass_card',
    label: 'Glass Card',
    category: 'glass',
    element: CanvasElement(
      id: 'glass_card', type: 'figure',
      width: 600, height: 340,
      fill: '#ffffff', cornerRadius: 24,
      opacity: 0.12,
      strokeColor: '#ffffff',
      strokeWidth: 1.5,
    ),
  ),
  ModernElementPreset(
    id: 'glass_pill',
    label: 'Glass Pill',
    category: 'glass',
    element: CanvasElement(
      id: 'glass_pill', type: 'figure',
      width: 400, height: 80,
      fill: '#ffffff', cornerRadius: 40,
      opacity: 0.15,
      strokeColor: '#ffffff',
      strokeWidth: 1,
    ),
  ),
  ModernElementPreset(
    id: 'glass_circle',
    label: 'Glass Circle',
    category: 'glass',
    element: CanvasElement(
      id: 'glass_circle', type: 'figure',
      width: 300, height: 300,
      fill: '#ffffff', cornerRadius: 150,
      opacity: 0.1,
      strokeColor: '#ffffff',
      strokeWidth: 1.5,
    ),
  ),
  ModernElementPreset(
    id: 'glass_banner',
    label: 'Glass Banner',
    category: 'glass',
    element: CanvasElement(
      id: 'glass_banner', type: 'figure',
      width: 900, height: 120,
      fill: '#ffffff', cornerRadius: 16,
      opacity: 0.1,
      strokeColor: '#ffffff',
      strokeWidth: 1,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Pattern Fills
// ---------------------------------------------------------------------------
const _patternElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'pattern_dots',
    label: 'Dot Pattern',
    category: 'patterns',
    element: CanvasElement(
      id: 'pattern_dots', type: 'figure',
      width: 400, height: 400,
      fill: '#ffffff', cornerRadius: 0,
      opacity: 0.08,
    ),
  ),
  ModernElementPreset(
    id: 'pattern_stripes',
    label: 'Stripe Band',
    category: 'patterns',
    element: CanvasElement(
      id: 'pattern_stripes', type: 'figure',
      width: 1080, height: 60,
      fill: '#ffffff', cornerRadius: 0,
      opacity: 0.1,
    ),
  ),
  ModernElementPreset(
    id: 'pattern_wave',
    label: 'Wave Band',
    category: 'patterns',
    element: CanvasElement(
      id: 'pattern_wave', type: 'figure',
      width: 1080, height: 80,
      fill: '#ffffff', cornerRadius: 0,
      opacity: 0.08,
    ),
  ),
  ModernElementPreset(
    id: 'pattern_grid',
    label: 'Grid Overlay',
    category: 'patterns',
    element: CanvasElement(
      id: 'pattern_grid', type: 'figure',
      width: 600, height: 600,
      fill: '#ffffff', cornerRadius: 0,
      opacity: 0.05,
    ),
  ),
];

// ---------------------------------------------------------------------------
// QR & Social Frames
// ---------------------------------------------------------------------------
const _frameElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'qr_frame',
    label: 'QR Frame',
    category: 'frames',
    element: CanvasElement(
      id: 'qr_frame', type: 'figure',
      width: 320, height: 320,
      fill: '#ffffff', cornerRadius: 20,
      opacity: 1.0,
      strokeColor: '#0F1D40',
      strokeWidth: 4,
    ),
  ),
  ModernElementPreset(
    id: 'social_bar',
    label: '@Handle Bar',
    category: 'frames',
    element: CanvasElement(
      id: 'social_bar', type: 'figure',
      width: 500, height: 60,
      fill: '#0F1D40', cornerRadius: 30,
      opacity: 0.9,
    ),
  ),
  ModernElementPreset(
    id: 'price_strike',
    label: 'Price Strike',
    category: 'frames',
    element: CanvasElement(
      id: 'price_strike', type: 'figure',
      width: 280, height: 60,
      fill: '#dc2626', cornerRadius: 8,
      opacity: 0.9,
    ),
  ),
  ModernElementPreset(
    id: 'play_btn',
    label: 'Play Button',
    category: 'frames',
    element: CanvasElement(
      id: 'play_btn', type: 'figure',
      width: 120, height: 120,
      fill: '#ffffff', cornerRadius: 60,
      opacity: 0.9,
      shadowColor: '#000000',
      shadowBlur: 20,
    ),
  ),
  ModernElementPreset(
    id: 'swipe_arrow',
    label: 'Swipe Arrow',
    category: 'frames',
    element: CanvasElement(
      id: 'swipe_arrow', type: 'figure',
      width: 80, height: 80,
      fill: '#ffffff', cornerRadius: 40,
      opacity: 0.8,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Countdown & Rating
// ---------------------------------------------------------------------------
const _countdownElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'count_box',
    label: 'Countdown Box',
    category: 'countdown',
    element: CanvasElement(
      id: 'count_box', type: 'figure',
      width: 160, height: 160,
      fill: '#ffffff', cornerRadius: 16,
      opacity: 0.15,
      strokeColor: '#ffffff',
      strokeWidth: 2,
    ),
  ),
  ModernElementPreset(
    id: 'count_pill',
    label: 'Countdown Pill',
    category: 'countdown',
    element: CanvasElement(
      id: 'count_pill', type: 'figure',
      width: 300, height: 64,
      fill: '#ffffff', cornerRadius: 32,
      opacity: 0.2,
    ),
  ),
  ModernElementPreset(
    id: 'star_bg',
    label: 'Star Background',
    category: 'countdown',
    element: CanvasElement(
      id: 'star_bg', type: 'figure',
      width: 400, height: 80,
      fill: '#fbbf24', cornerRadius: 16,
      opacity: 0.2,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Map & Location
// ---------------------------------------------------------------------------
const _locationElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'map_frame',
    label: 'Map Frame',
    category: 'location',
    element: CanvasElement(
      id: 'map_frame', type: 'figure',
      width: 600, height: 400,
      fill: '#e5e7eb', cornerRadius: 20,
      opacity: 1.0,
      strokeColor: '#9ca3af',
      strokeWidth: 2,
    ),
  ),
  ModernElementPreset(
    id: 'pin_badge',
    label: 'Pin Badge',
    category: 'location',
    element: CanvasElement(
      id: 'pin_badge', type: 'figure',
      width: 80, height: 80,
      fill: '#ef4444', cornerRadius: 40,
      opacity: 1.0,
      shadowColor: '#000000',
      shadowBlur: 12,
    ),
  ),
  ModernElementPreset(
    id: 'address_card',
    label: 'Address Card',
    category: 'location',
    element: CanvasElement(
      id: 'address_card', type: 'figure',
      width: 560, height: 140,
      fill: '#ffffff', cornerRadius: 16,
      opacity: 0.95,
      shadowColor: '#000000',
      shadowBlur: 8,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Neon & Glow Borders
// ---------------------------------------------------------------------------
const _neonElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'neon_rect',
    label: 'Neon Rectangle',
    category: 'neon',
    element: CanvasElement(
      id: 'neon_rect', type: 'figure',
      width: 500, height: 300,
      fill: '#000000', cornerRadius: 20,
      opacity: 0.6,
      strokeColor: '#22d3ee',
      strokeWidth: 3,
      shadowColor: '#06b6d4',
      shadowBlur: 24,
    ),
    isPremium: true,
  ),
  ModernElementPreset(
    id: 'neon_pill',
    label: 'Neon Pill',
    category: 'neon',
    element: CanvasElement(
      id: 'neon_pill', type: 'figure',
      width: 400, height: 70,
      fill: '#000000', cornerRadius: 35,
      opacity: 0.5,
      strokeColor: '#a855f7',
      strokeWidth: 2,
      shadowColor: '#a855f7',
      shadowBlur: 16,
    ),
    isPremium: true,
  ),
  ModernElementPreset(
    id: 'neon_circle',
    label: 'Neon Circle',
    category: 'neon',
    element: CanvasElement(
      id: 'neon_circle', type: 'figure',
      width: 300, height: 300,
      fill: '#000000', cornerRadius: 150,
      opacity: 0.4,
      strokeColor: '#f472b6',
      strokeWidth: 3,
      shadowColor: '#ec4899',
      shadowBlur: 20,
    ),
    isPremium: true,
  ),
];

// ---------------------------------------------------------------------------
// Dividers & Lines
// ---------------------------------------------------------------------------
const _dividerElements = <ModernElementPreset>[
  ModernElementPreset(
    id: 'line_thin',
    label: 'Thin Line',
    category: 'dividers',
    element: CanvasElement(
      id: 'line_thin', type: 'figure',
      width: 600, height: 2,
      fill: '#ffffff', cornerRadius: 1,
      opacity: 0.3,
    ),
  ),
  ModernElementPreset(
    id: 'line_thick',
    label: 'Thick Line',
    category: 'dividers',
    element: CanvasElement(
      id: 'line_thick', type: 'figure',
      width: 600, height: 6,
      fill: '#ffffff', cornerRadius: 3,
      opacity: 0.4,
    ),
  ),
  ModernElementPreset(
    id: 'line_accent',
    label: 'Accent Line',
    category: 'dividers',
    element: CanvasElement(
      id: 'line_accent', type: 'figure',
      width: 200, height: 4,
      fill: '#0EBE7E', cornerRadius: 2,
      opacity: 1.0,
    ),
  ),
  ModernElementPreset(
    id: 'line_dashed',
    label: 'Dashed Line',
    category: 'dividers',
    element: CanvasElement(
      id: 'line_dashed', type: 'figure',
      width: 600, height: 2,
      fill: '#ffffff', cornerRadius: 1,
      opacity: 0.25,
    ),
  ),
  ModernElementPreset(
    id: 'dot_divider',
    label: 'Dot Divider',
    category: 'dividers',
    element: CanvasElement(
      id: 'dot_divider', type: 'figure',
      width: 40, height: 40,
      fill: '#ffffff', cornerRadius: 20,
      opacity: 0.3,
    ),
  ),
];

// ---------------------------------------------------------------------------
// Combined registry
// ---------------------------------------------------------------------------
List<ModernElementPreset> get allModernElements => [
  ..._orbElements,
  ..._glassElements,
  ..._patternElements,
  ..._frameElements,
  ..._countdownElements,
  ..._locationElements,
  ..._neonElements,
  ..._dividerElements,
];

Map<String, List<ModernElementPreset>> get modernElementsByCategory {
  final map = <String, List<ModernElementPreset>>{};
  for (final el in allModernElements) {
    map.putIfAbsent(el.category, () => []).add(el);
  }
  return map;
}

ModernElementPreset? modernElementById(String id) {
  for (final el in allModernElements) {
    if (el.id == id) return el;
  }
  return null;
}
