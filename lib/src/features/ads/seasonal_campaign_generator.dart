
import 'ad_templates.dart';

// ---------------------------------------------------------------------------
// Seasonal campaign detection and generation
// ---------------------------------------------------------------------------

class SeasonalContext {
  const SeasonalContext({
    required this.id,
    required this.name,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.category,
    required this.primaryColor,
    required this.accentColor,
    required this.suggestedHashtags,
  });

  final String id;
  final String name;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;
  final String category;
  final String primaryColor;
  final String accentColor;
  final List<String> suggestedHashtags;

  bool contains(DateTime d) {
    final start = DateTime(d.year, startMonth, startDay);
    var end = DateTime(d.year, endMonth, endDay);
    if (end.isBefore(start)) end = DateTime(d.year + 1, endMonth, endDay);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

/// East African seasonal calendar
const _seasons = <SeasonalContext>[
  // Ramadan (approximate — shifts with Islamic calendar, but we use a fixed window for promos)
  SeasonalContext(
    id: 'ramadan',
    name: 'Ramadan Kareem',
    startMonth: 3, startDay: 1,
    endMonth: 4, endDay: 10,
    category: 'promo',
    primaryColor: '#1e3a5f',
    accentColor: '#fbbf24',
    suggestedHashtags: ['#RamadanKareem', '#IftarDeals', '#RamadanOffers'],
  ),
  // Eid
  SeasonalContext(
    id: 'eid',
    name: 'Eid Mubarak',
    startMonth: 4, startDay: 8,
    endMonth: 4, endDay: 18,
    category: 'event',
    primaryColor: '#14532d',
    accentColor: '#86efac',
    suggestedHashtags: ['#EidMubarak', '#EidOffers', '#EidShopping'],
  ),
  // Easter
  SeasonalContext(
    id: 'easter',
    name: 'Easter Celebrations',
    startMonth: 3, startDay: 25,
    endMonth: 4, endDay: 5,
    category: 'event',
    primaryColor: '#7c3aed',
    accentColor: '#f9a8d4',
    suggestedHashtags: ['#EasterDeals', '#EasterSale', '#HappyEaster'],
  ),
  // Mother\'s Day (second Sunday in May — approximate)
  SeasonalContext(
    id: 'mothers',
    name: "Mother's Day",
    startMonth: 5, startDay: 1,
    endMonth: 5, endDay: 15,
    category: 'promo',
    primaryColor: '#9d174d',
    accentColor: '#fbcfe8',
    suggestedHashtags: ['#MothersDay', '#GiftForMom', '#MothersDaySpecial'],
  ),
  // Father\'s Day (third Sunday in June — approximate)
  SeasonalContext(
    id: 'fathers',
    name: "Father's Day",
    startMonth: 6, startDay: 10,
    endMonth: 6, endDay: 25,
    category: 'promo',
    primaryColor: '#1e3a8a',
    accentColor: '#93c5fd',
    suggestedHashtags: ['#FathersDay', '#GiftForDad', '#FathersDaySpecial'],
  ),
  // Valentine\'s Day
  SeasonalContext(
    id: 'valentine',
    name: 'Valentine\'s Offer',
    startMonth: 2, startDay: 1,
    endMonth: 2, endDay: 16,
    category: 'promo',
    primaryColor: '#be185d',
    accentColor: '#fda4af',
    suggestedHashtags: ['#ValentinesDay', '#LoveDeals', '#ValentineOffer'],
  ),
  // Back to School (January for Uganda)
  SeasonalContext(
    id: 'back_to_school',
    name: 'Back to School',
    startMonth: 1, startDay: 1,
    endMonth: 2, endDay: 15,
    category: 'promo',
    primaryColor: '#1e293b',
    accentColor: '#38bdf8',
    suggestedHashtags: ['#BackToSchool', '#SchoolSupplies', '#BTSDeals'],
  ),
  // Independence Day (Uganda — 9 Oct)
  SeasonalContext(
    id: 'independence',
    name: 'Independence Day',
    startMonth: 10, startDay: 1,
    endMonth: 10, endDay: 12,
    category: 'event',
    primaryColor: '#000000',
    accentColor: '#facc15',
    suggestedHashtags: ['#UgandaAtIndependence', '#IndependenceDay', '#Uganda'],
  ),
  // Black Friday
  SeasonalContext(
    id: 'black_friday',
    name: 'Black Friday',
    startMonth: 11, startDay: 15,
    endMonth: 11, endDay: 30,
    category: 'sale',
    primaryColor: '#09090b',
    accentColor: '#facc15',
    suggestedHashtags: ['#BlackFriday', '#BlackFridayDeals', '#MegaSale'],
  ),
  // Christmas
  SeasonalContext(
    id: 'christmas',
    name: 'Christmas Sale',
    startMonth: 12, startDay: 1,
    endMonth: 12, endDay: 26,
    category: 'sale',
    primaryColor: '#7f1d1d',
    accentColor: '#f87171',
    suggestedHashtags: ['#ChristmasSale', '#HolidayDeals', '#MerryChristmas'],
  ),
  // New Year
  SeasonalContext(
    id: 'new_year',
    name: 'New Year',
    startMonth: 12, startDay: 27,
    endMonth: 1, endDay: 10,
    category: 'event',
    primaryColor: '#09090b',
    accentColor: '#facc15',
    suggestedHashtags: ['#NewYear', '#NewYearSale', '#HappyNewYear'],
  ),
  // Women\'s Day (8 March)
  SeasonalContext(
    id: 'womens_day',
    name: "Women's Day",
    startMonth: 3, startDay: 1,
    endMonth: 3, endDay: 10,
    category: 'promo',
    primaryColor: '#831843',
    accentColor: '#fbcfe8',
    suggestedHashtags: ['#WomensDay', '#IWD', '#WomenInBusiness'],
  ),
  // Youth Day (12 August)
  SeasonalContext(
    id: 'youth_day',
    name: 'Youth Day',
    startMonth: 8, startDay: 1,
    endMonth: 8, endDay: 15,
    category: 'event',
    primaryColor: '#0e7490',
    accentColor: '#99f6e4',
    suggestedHashtags: ['#YouthDay', '#YouthEmpowerment', '#YoungEntrepreneurs'],
  ),
];

/// Returns the currently active seasonal contexts.
List<SeasonalContext> currentSeasons([DateTime? date]) {
  final d = date ?? DateTime.now();
  return _seasons.where((s) => s.contains(d)).toList();
}

/// Returns upcoming seasons within the next 30 days.
List<SeasonalContext> upcomingSeasons([DateTime? date]) {
  final d = date ?? DateTime.now();
  final upcoming = <SeasonalContext>[];
  for (final s in _seasons) {
    final start = DateTime(d.year, s.startMonth, s.startDay);
    final diff = start.difference(d).inDays;
    if (diff > 0 && diff <= 30) upcoming.add(s);
  }
  return upcoming;
}

/// Generates a seasonal campaign pack for a given season.
List<AdTemplate> generateSeasonalCampaign({
  required SeasonalContext season,
  required String businessName,
  String primaryColor = '',
  String accentColor = '',
  int seed = 0,
}) {
  final out = <AdTemplate>[];
  final bg = primaryColor.isNotEmpty ? primaryColor : season.primaryColor;
  final ac = accentColor.isNotEmpty ? accentColor : season.accentColor;
  final textColor = contrastText(bg);
  final accentText = contrastText(ac);
  final hash = seed + season.id.hashCode;

  // Ad 1: Main seasonal promo
  out.add(_seasonalTemplate(
    id: 'season_${season.id}_main_$seed',
    name: '${season.name} · Main',
    headline: '${season.name} Special',
    sub: 'Exclusive offers for a limited time',
    body: 'Celebrate ${season.name} with amazing deals from $businessName.',
    cta: 'Shop Now',
    bg: bg,
    ac: ac,
    textColor: textColor,
    accentText: accentText,
    businessName: businessName,
    seed: hash,
  ));

  // Ad 2: Discount announcement
  out.add(_seasonalTemplate(
    id: 'season_${season.id}_discount_$seed',
    name: '${season.name} · Discount',
    headline: 'Up to 30% Off',
    sub: season.name,
    body: 'Don\'t miss our biggest ${season.name} sale of the year.',
    cta: 'Save Now',
    bg: bg,
    ac: ac,
    textColor: textColor,
    accentText: accentText,
    businessName: businessName,
    seed: hash + 1,
  ));

  // Ad 3: Gift idea
  out.add(_seasonalTemplate(
    id: 'season_${season.id}_gift_$seed',
    name: '${season.name} · Gift',
    headline: 'Perfect Gifts Inside',
    sub: 'For ${season.name}',
    body: 'Find the perfect gift at $businessName. Quality guaranteed.',
    cta: 'Browse Gifts',
    bg: bg,
    ac: ac,
    textColor: textColor,
    accentText: accentText,
    businessName: businessName,
    seed: hash + 2,
  ));

  // Ad 4: Last chance / urgency
  out.add(_seasonalTemplate(
    id: 'season_${season.id}_urgent_$seed',
    name: '${season.name} · Last Chance',
    headline: 'Last Chance!',
    sub: '${season.name} ends soon',
    body: 'Hurry — these deals won\'t last forever. Shop $businessName today.',
    cta: 'Order Now',
    bg: bg,
    ac: ac,
    textColor: textColor,
    accentText: accentText,
    businessName: businessName,
    seed: hash + 3,
  ));

  // Ad 5: Story/gratitude
  out.add(_seasonalTemplate(
    id: 'season_${season.id}_story_$seed',
    name: '${season.name} · Thank You',
    headline: 'Thank You for Your Support',
    sub: season.name,
    body: 'This ${season.name}, we\'re grateful for customers like you.',
    cta: 'Celebrate With Us',
    bg: bg,
    ac: ac,
    textColor: textColor,
    accentText: accentText,
    businessName: businessName,
    seed: hash + 4,
  ));

  return out;
}

AdTemplate _seasonalTemplate({
  required String id,
  required String name,
  required String headline,
  required String sub,
  required String body,
  required String cta,
  required String bg,
  required String ac,
  required String textColor,
  required String accentText,
  required String businessName,
  required int seed,
}) {
  final elements = <CanvasElement>[
    CanvasElement(id: 'bg', type: 'figure', x: 0, y: 0, width: 1080, height: 1080, fill: bg),
    // Decorative accent circles
    CanvasElement(id: 'accent_circle', type: 'figure', x: 820, y: -60, width: 320, height: 320, fill: ac, cornerRadius: 160, opacity: 0.12),
    CanvasElement(id: 'accent_circle2', type: 'figure', x: -80, y: 800, width: 260, height: 260, fill: ac, cornerRadius: 130, opacity: 0.10),
    // Top accent bar
    CanvasElement(id: 'top_bar', type: 'figure', x: 340, y: 70, width: 400, height: 6, fill: ac, cornerRadius: 3, opacity: 0.7),
    CanvasElement(id: 'headline', type: 'text', text: headline, x: 80, y: 110, width: 920, fontSize: 60, fontWeight: 'bold', fontFamily: 'Montserrat', fill: textColor, align: 'center'),
    CanvasElement(id: 'sub', type: 'text', text: sub, x: 120, y: 200, width: 840, fontSize: 28, fontFamily: 'Inter', fill: ac, align: 'center'),
    // Hero product image
    CanvasElement(id: 'image', type: 'image', src: '', x: 180, y: 280, width: 720, height: 420, cornerRadius: 28, shadowColor: '#000000', shadowDx: 0, shadowDy: 14, shadowBlur: 32, opacity: 1.0),
    CanvasElement(id: 'body', type: 'text', text: body, x: 120, y: 730, width: 840, fontSize: 26, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.92, lineHeight: 1.5),
    // CTA with shadow
    CanvasElement(id: 'cta_shadow', type: 'figure', x: 340, y: 830, width: 400, height: 72, fill: '#000000', cornerRadius: 36, shadowColor: '#000000', shadowDx: 0, shadowDy: 8, shadowBlur: 20, opacity: 0.15),
    CanvasElement(id: 'cta_bg', type: 'figure', x: 340, y: 830, width: 400, height: 72, fill: ac, cornerRadius: 36),
    CanvasElement(id: 'cta_text', type: 'text', text: cta, x: 340, y: 848, width: 400, fontSize: 26, fontWeight: 'bold', fontFamily: 'Inter', fill: accentText, align: 'center'),
    CanvasElement(id: 'footer', type: 'text', text: businessName, x: 80, y: 960, width: 920, fontSize: 20, fontFamily: 'Inter', fill: textColor, align: 'center', opacity: 0.55),
  ];

  return AdTemplate(
    id: id,
    name: name,
    category: 'event',
    canvasWidth: 1080,
    canvasHeight: 1080,
    background: bg,
    previewColors: [parseHexColor(bg), parseHexColor(ac)],
    elements: elements,
    season: name.toLowerCase().replaceAll(' ', '_'),
    complexity: 'starter',
    tags: ['seasonal', 'campaign', 'auto-generated'],
    suggestedCaption: '$headline\n\n$body\n\nShop now: $businessName',
    marketingGoal: 'conversion',
  );
}
