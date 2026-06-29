
import 'ad_templates.dart';
import 'market_copy_frameworks.dart';

// ---------------------------------------------------------------------------
// Business-info-only ad generator
// ---------------------------------------------------------------------------

/// Generates ads purely from brand kit — no product or service required.
List<AdTemplate> generateBusinessAds({
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  String primaryColor = '#0F1D40',
  String accentColor = '#0EBE7E',
  int seed = 0,
}) {
  if (businessName.isEmpty) return [];
  final out = <AdTemplate>[];
  final hash = seed + businessName.hashCode;

  // 1. Welcome / About Us
  out.add(_buildBusinessAd(
    id: 'biz_welcome_$seed',
    name: 'Welcome · $businessName',
    framework: welcomeFramework,
    seed: hash,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _welcomeLayout,
  ));

  // 2. Contact / Location
  if (location.isNotEmpty || phone.isNotEmpty) {
    out.add(_buildBusinessAd(
      id: 'biz_contact_$seed',
      name: 'Contact · $businessName',
      framework: contactFramework,
      seed: hash + 1,
      businessName: businessName,
      tagline: tagline,
      phone: phone,
      whatsapp: whatsapp,
      location: location,
      website: website,
      primaryColor: primaryColor,
      accentColor: accentColor,
      builder: _contactLayout,
    ));
  }

  // 3. Trust / Guarantee
  out.add(_buildBusinessAd(
    id: 'biz_trust_$seed',
    name: 'Trust · $businessName',
    framework: trustFramework,
    seed: hash + 2,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _trustLayout,
  ));

  // 4. Opening Hours / Availability
  out.add(_buildBusinessAd(
    id: 'biz_hours_$seed',
    name: 'Hours · $businessName',
    framework: welcomeFramework,
    seed: hash + 3,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _hoursLayout,
  ));

  // 5. Follow Us / Social
  out.add(_buildBusinessAd(
    id: 'biz_social_$seed',
    name: 'Follow · $businessName',
    framework: socialProofFramework,
    seed: hash + 4,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _socialLayout,
  ));

  // 6. Referral / Word of Mouth
  out.add(_buildBusinessAd(
    id: 'biz_referral_$seed',
    name: 'Refer · $businessName',
    framework: referralFramework,
    seed: hash + 5,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _referralLayout,
  ));

  // 7. Payment Methods
  out.add(_buildBusinessAd(
    id: 'biz_payment_$seed',
    name: 'Payment · $businessName',
    framework: trustFramework,
    seed: hash + 6,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _paymentLayout,
  ));

  // 8. Delivery Coverage
  out.add(_buildBusinessAd(
    id: 'biz_delivery_$seed',
    name: 'Delivery · $businessName',
    framework: welcomeFramework,
    seed: hash + 7,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
    builder: _deliveryLayout,
  ));

  return out;
}

AdTemplate _buildBusinessAd({
  required String id,
  required String name,
  required CopyFramework framework,
  required int seed,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
  required List<CanvasElement> Function({
    required String headline,
    required String sub,
    required String body,
    required String cta,
    required String businessName,
    required String tagline,
    required String phone,
    required String whatsapp,
    required String location,
    required String website,
    required String primaryColor,
    required String accentColor,
  }) builder,
}) {
  final copy = framework.generate(seed);
  final h = _replaceVars(copy.headline, businessName, tagline, phone, whatsapp, location, website);
  final s = _replaceVars(copy.sub, businessName, tagline, phone, whatsapp, location, website);
  final b = _replaceVars(copy.body, businessName, tagline, phone, whatsapp, location, website);
  final c = _replaceVars(copy.cta, businessName, tagline, phone, whatsapp, location, website);

  final elements = builder(
    headline: h,
    sub: s,
    body: b,
    cta: c,
    businessName: businessName,
    tagline: tagline,
    phone: phone,
    whatsapp: whatsapp,
    location: location,
    website: website,
    primaryColor: primaryColor,
    accentColor: accentColor,
  );

  return AdTemplate(
    id: id,
    name: name,
    category: 'professional',
    canvasWidth: 1080,
    canvasHeight: 1080,
    background: primaryColor,
    previewColors: [parseHexColor(primaryColor), parseHexColor(accentColor)],
    elements: elements,
    industry: 'business',
    complexity: 'starter',
    tags: ['business', 'brand', framework.id],
    marketingGoal: 'awareness',
  );
}

String _replaceVars(
  String text,
  String businessName,
  String tagline,
  String phone,
  String whatsapp,
  String location,
  String website,
) {
  return text
      .replaceAll('{{BUSINESS}}', businessName)
      .replaceAll('{{TAGLINE}}', tagline.isNotEmpty ? tagline : 'Quality you can trust')
      .replaceAll('{{PHONE}}', phone.isNotEmpty ? phone : 'Call us')
      .replaceAll('{{WHATSAPP}}', whatsapp.isNotEmpty ? whatsapp : 'Message us')
      .replaceAll('{{LOCATION}}', location.isNotEmpty ? location : 'Kampala, Uganda')
      .replaceAll('{{CTA_LINK}}', website.isNotEmpty ? website : 'soko24.co');
}

// ---------------------------------------------------------------------------
// Layout builders for business ads
// ---------------------------------------------------------------------------

List<CanvasElement> _welcomeLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Subtle top accent bar
    CanvasElement(id: 'accent_bar', type: 'figure', x: 390, y: 70, width: 300, height: 6, fill: accentColor, cornerRadius: 3),
    CanvasElement(id: 'headline', type: 'text', text: headline, x: 80, y: 110, width: 920, fontSize: 60, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 200, width: 840, fontSize: 28, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Logo circle with soft shadow
    CanvasElement(id: 'logo_shadow', type: 'figure', x: 390, y: 290, width: 300, height: 300, fill: '#000000', cornerRadius: 150, shadowColor: '#000000', shadowDx: 0, shadowDy: 16, shadowBlur: 36, opacity: 0.15),
    CanvasElement(id: 'logo_placeholder', type: 'figure', x: 390, y: 290, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.18),
    CanvasElement(id: 'logo_text', type: 'text', text: businessName[0], x: 390, y: 360, width: 300, fontSize: 130, fontWeight: 'bold', fontFamily: 'Montserrat', fill: accentColor, align: 'center'),
    CanvasElement(id: 'body', type: 'text', text: body, x: 120, y: 640, width: 840, fontSize: 26, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.9, lineHeight: 1.6),
    // Rounded CTA with shadow
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 820, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 820, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: cta, x: 340, y: 838, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: website.isNotEmpty ? website : 'soko24.co', x: 80, y: 960, width: 920, fontSize: 20, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _contactLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Modern card with border
    CanvasElement(id: 'card', type: 'figure', x: 70, y: 70, width: 940, height: 940, fill: '#ffffff', cornerRadius: 32, opacity: 0.07),
    CanvasElement(id: 'card_border', type: 'figure', x: 70, y: 70, width: 940, height: 940, fill: 'transparent', strokeColor: accentColor, strokeWidth: 1.5, cornerRadius: 32, opacity: 0.4),
    CanvasElement(id: 'headline', type: 'text', text: headline, x: 120, y: 130, width: 840, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 210, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Contact rows with accent dots
    CanvasElement(id: 'pin_dot', type: 'figure', x: 150, y: 330, width: 16, height: 16, fill: accentColor, cornerRadius: 8),
    CanvasElement(id: 'loc', type: 'text', text: location.isNotEmpty ? location : 'Kampala, Uganda', x: 190, y: 320, width: 760, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'phone_dot', type: 'figure', x: 150, y: 410, width: 16, height: 16, fill: accentColor, cornerRadius: 8),
    CanvasElement(id: 'phone', type: 'text', text: phone.isNotEmpty ? phone : 'Call us today', x: 190, y: 400, width: 760, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'wa_dot', type: 'figure', x: 150, y: 490, width: 16, height: 16, fill: accentColor, cornerRadius: 8),
    CanvasElement(id: 'wa', type: 'text', text: whatsapp.isNotEmpty ? whatsapp : 'WhatsApp us', x: 190, y: 480, width: 760, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'web_dot', type: 'figure', x: 150, y: 570, width: 16, height: 16, fill: accentColor, cornerRadius: 8),
    CanvasElement(id: 'web', type: 'text', text: website.isNotEmpty ? website : 'soko24.co', x: 190, y: 560, width: 760, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    // CTA
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 760, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 760, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: cta, x: 340, y: 778, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: businessName, x: 120, y: 900, width: 840, fontSize: 22, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _trustLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Top accent ring
    CanvasElement(id: 'shield_ring', type: 'figure', x: 390, y: 60, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'shield', type: 'text', text: '🛡️', x: 440, y: 100, width: 200, fontSize: 110, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: headline, x: 80, y: 240, width: 920, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 320, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    CanvasElement(id: 'body', type: 'text', text: body, x: 140, y: 400, width: 800, fontSize: 26, fontFamily: 'Inter', fill: textColor, align: 'center', lineHeight: 1.6),
    // Trust badges as rounded pills
    CanvasElement(id: 'badge1', type: 'figure', x: 120, y: 640, width: 260, height: 80, fill: accentColor, cornerRadius: 40, opacity: 0.90),
    CanvasElement(id: 'badge1_text', type: 'text', text: '✓ Quality', x: 120, y: 660, width: 260, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'badge2', type: 'figure', x: 410, y: 640, width: 260, height: 80, fill: accentColor, cornerRadius: 40, opacity: 0.90),
    CanvasElement(id: 'badge2_text', type: 'text', text: '✓ Fast', x: 410, y: 660, width: 260, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'badge3', type: 'figure', x: 700, y: 640, width: 260, height: 80, fill: accentColor, cornerRadius: 40, opacity: 0.90),
    CanvasElement(id: 'badge3_text', type: 'text', text: '✓ Trusted', x: 700, y: 660, width: 260, fontSize: 22, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 820, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 820, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: cta, x: 340, y: 838, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: businessName, x: 80, y: 960, width: 920, fontSize: 20, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _hoursLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Clock on soft circle
    CanvasElement(id: 'clock_ring', type: 'figure', x: 390, y: 70, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'clock', type: 'text', text: '🕐', x: 440, y: 120, width: 200, fontSize: 100, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: 'We\'re Open', x: 80, y: 250, width: 920, fontSize: 54, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 330, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Hours card
    CanvasElement(id: 'hours_card', type: 'figure', x: 140, y: 400, width: 800, height: 190, fill: '#ffffff', cornerRadius: 24, opacity: 0.08),
    CanvasElement(id: 'day1', type: 'text', text: 'Mon – Fri     8:00 AM – 6:00 PM', x: 200, y: 430, width: 680, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'day2', type: 'text', text: 'Saturday      9:00 AM – 4:00 PM', x: 200, y: 490, width: 680, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'day3', type: 'text', text: 'Sunday        Closed', x: 200, y: 550, width: 680, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'divider', type: 'figure', x: 340, y: 620, width: 400, height: 2, fill: accentColor, cornerRadius: 1, opacity: 0.4),
    CanvasElement(id: 'call_text', type: 'text', text: 'Call ahead: ${phone.isNotEmpty ? phone : whatsapp}', x: 120, y: 660, width: 840, fontSize: 24, fontFamily: 'Inter', fill: textColor, align: 'center'),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 780, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 780, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: 'Visit Us Today', x: 340, y: 798, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: location.isNotEmpty ? location : 'Kampala, Uganda', x: 80, y: 920, width: 920, fontSize: 22, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.6),
  ];
}

List<CanvasElement> _socialLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Heart on soft circle
    CanvasElement(id: 'heart_ring', type: 'figure', x: 390, y: 70, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'heart', type: 'text', text: '❤️', x: 440, y: 120, width: 200, fontSize: 100, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: 'Follow $businessName', x: 80, y: 250, width: 920, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 330, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Handle pill
    CanvasElement(id: 'handle_pill', type: 'figure', x: 290, y: 400, width: 500, height: 60, fill: accentColor, cornerRadius: 30, opacity: 0.15),
    CanvasElement(id: 'handle', type: 'text', text: '@${businessName.toLowerCase().replaceAll(' ', '')}', x: 290, y: 410, width: 500, fontSize: 36, fontWeight: 'bold', fontFamily: 'Inter', fill: accentColor, align: 'center'),
    CanvasElement(id: 'body', type: 'text', text: body, x: 140, y: 500, width: 800, fontSize: 26, fontFamily: 'Inter', fill: textColor, align: 'center', lineHeight: 1.55),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 720, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 720, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: 'Follow Us', x: 340, y: 738, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: website.isNotEmpty ? website : 'soko24.co', x: 80, y: 860, width: 920, fontSize: 22, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _referralLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Gift on soft circle
    CanvasElement(id: 'gift_ring', type: 'figure', x: 390, y: 70, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'gift', type: 'text', text: '🎁', x: 440, y: 120, width: 200, fontSize: 100, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: headline, x: 80, y: 250, width: 920, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 330, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    CanvasElement(id: 'body', type: 'text', text: body, x: 140, y: 400, width: 800, fontSize: 26, fontFamily: 'Inter', fill: textColor, align: 'center', lineHeight: 1.55),
    // Step circles with connector lines
    CanvasElement(id: 'conn1', type: 'figure', x: 220, y: 615, width: 280, height: 4, fill: accentColor, cornerRadius: 2, opacity: 0.4),
    CanvasElement(id: 'conn2', type: 'figure', x: 580, y: 615, width: 280, height: 4, fill: accentColor, cornerRadius: 2, opacity: 0.4),
    CanvasElement(id: 'step1', type: 'figure', x: 140, y: 580, width: 80, height: 80, fill: accentColor, cornerRadius: 40),
    CanvasElement(id: 'step1_text', type: 'text', text: '1', x: 140, y: 595, width: 80, fontSize: 34, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'step1_label', type: 'text', text: 'Share', x: 120, y: 680, width: 120, fontSize: 22, fontWeight: '600', fontFamily: 'Inter', fill: textColor, align: 'center'),
    CanvasElement(id: 'step2', type: 'figure', x: 500, y: 580, width: 80, height: 80, fill: accentColor, cornerRadius: 40),
    CanvasElement(id: 'step2_text', type: 'text', text: '2', x: 500, y: 595, width: 80, fontSize: 34, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'step2_label', type: 'text', text: 'They Buy', x: 460, y: 680, width: 160, fontSize: 22, fontWeight: '600', fontFamily: 'Inter', fill: textColor, align: 'center'),
    CanvasElement(id: 'step3', type: 'figure', x: 860, y: 580, width: 80, height: 80, fill: accentColor, cornerRadius: 40),
    CanvasElement(id: 'step3_text', type: 'text', text: '3', x: 860, y: 595, width: 80, fontSize: 34, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'step3_label', type: 'text', text: 'You Win', x: 840, y: 680, width: 120, fontSize: 22, fontWeight: '600', fontFamily: 'Inter', fill: textColor, align: 'center'),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 780, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 780, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: cta, x: 340, y: 798, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: businessName, x: 80, y: 920, width: 920, fontSize: 20, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _paymentLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Icon on soft circle
    CanvasElement(id: 'money_ring', type: 'figure', x: 390, y: 70, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'money', type: 'text', text: '💳', x: 440, y: 120, width: 200, fontSize: 100, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: 'Easy Payments', x: 80, y: 250, width: 920, fontSize: 52, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: 'Multiple ways to pay. Your convenience matters.', x: 120, y: 330, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Payment options card
    CanvasElement(id: 'options_card', type: 'figure', x: 140, y: 400, width: 800, height: 230, fill: '#ffffff', cornerRadius: 24, opacity: 0.08),
    CanvasElement(id: 'm1_dot', type: 'figure', x: 180, y: 430, width: 14, height: 14, fill: accentColor, cornerRadius: 7),
    CanvasElement(id: 'm1', type: 'text', text: 'Cash on Delivery', x: 220, y: 420, width: 660, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'm2_dot', type: 'figure', x: 180, y: 485, width: 14, height: 14, fill: accentColor, cornerRadius: 7),
    CanvasElement(id: 'm2', type: 'text', text: 'Mobile Money', x: 220, y: 475, width: 660, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'm3_dot', type: 'figure', x: 180, y: 540, width: 14, height: 14, fill: accentColor, cornerRadius: 7),
    CanvasElement(id: 'm3', type: 'text', text: 'Bank Transfer', x: 220, y: 530, width: 660, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'm4_dot', type: 'figure', x: 180, y: 595, width: 14, height: 14, fill: accentColor, cornerRadius: 7),
    CanvasElement(id: 'm4', type: 'text', text: 'Card Payment', x: 220, y: 585, width: 660, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 720, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 720, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: 'Shop Now', x: 340, y: 738, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: businessName, x: 80, y: 860, width: 920, fontSize: 20, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];
}

List<CanvasElement> _deliveryLayout({
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String businessName,
  required String tagline,
  required String phone,
  required String whatsapp,
  required String location,
  required String website,
  required String primaryColor,
  required String accentColor,
}) {
  final textColor = contrastText(primaryColor);
  final accentText = contrastText(accentColor);
  return [
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: primaryColor),
    // Truck on soft circle
    CanvasElement(id: 'truck_ring', type: 'figure', x: 390, y: 70, width: 300, height: 300, fill: accentColor, cornerRadius: 150, opacity: 0.12),
    CanvasElement(id: 'truck', type: 'text', text: '🚚', x: 440, y: 120, width: 200, fontSize: 100, align: 'center'),
    CanvasElement(id: 'headline', type: 'text', text: 'We Deliver!', x: 80, y: 250, width: 920, fontSize: 54, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: 'Fast, reliable delivery across Uganda.', x: 120, y: 330, width: 840, fontSize: 26, fontFamily: 'Inter', fill: accentColor, align: 'center'),
    // Areas card
    CanvasElement(id: 'areas_card', type: 'figure', x: 140, y: 400, width: 800, height: 180, fill: '#ffffff', cornerRadius: 24, opacity: 0.08),
    CanvasElement(id: 'area1', type: 'text', text: '📍 Kampala', x: 190, y: 430, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'area2', type: 'text', text: '📍 Entebbe', x: 590, y: 430, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'area3', type: 'text', text: '📍 Jinja', x: 190, y: 485, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'area4', type: 'text', text: '📍 Mbarara', x: 590, y: 485, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'area5', type: 'text', text: '📍 Gulu', x: 190, y: 540, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'area6', type: 'text', text: '📍 & More', x: 590, y: 540, width: 300, fontSize: 30, fontFamily: 'Inter', fill: textColor, align: 'left'),
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 680, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 680, width: 400, height: 72, fill: accentColor, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: 'Order Now', x: 340, y: 698, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: whatsapp.isNotEmpty ? 'WhatsApp: $whatsapp' : phone, x: 80, y: 820, width: 920, fontSize: 22, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.6),
  ];
}
