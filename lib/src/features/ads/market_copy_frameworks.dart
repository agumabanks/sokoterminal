// ---------------------------------------------------------------------------
// Market-standard copywriting frameworks for Soko Studio Smart Ads
// ---------------------------------------------------------------------------

/// A copy framework produces headline, subheadline, body, and CTA variants.
class CopyFramework {
  const CopyFramework({
    required this.id,
    required this.name,
    required this.headlines,
    required this.subheadlines,
    required this.bodies,
    required this.ctas,
  });

  final String id;
  final String name;
  final List<String> headlines;
  final List<String> subheadlines;
  final List<String> bodies;
  final List<String> ctas;

  /// Returns a deterministic set of copy based on a seed.
  ({String headline, String sub, String body, String cta}) generate(int seed) {
    final h = headlines[seed % headlines.length];
    final s = subheadlines[seed % subheadlines.length];
    final b = bodies[seed % bodies.length];
    final c = ctas[seed % ctas.length];
    return (headline: h, sub: s, body: b, cta: c);
  }
}

// ---------------------------------------------------------------------------
// AIDA — Attention, Interest, Desire, Action
// ---------------------------------------------------------------------------
const _aida = CopyFramework(
  id: 'aida',
  name: 'AIDA Classic',
  headlines: [
    'Great Finds at Great Prices',
    'Quality You Can Trust',
    'Something Special for You',
    'The Smart Choice',
  ],
  subheadlines: [
    'Discover why thousands in Uganda are switching.',
    'Quality you can trust, prices you\'ll love.',
    'Handpicked just for our loyal customers.',
    'See what makes us different from the rest.',
  ],
  bodies: [
    'We\'ve sourced the best so you don\'t have to compromise. Fast delivery, quality guaranteed.',
    'Every item is checked, packed with care, and delivered to your door. Satisfaction guaranteed.',
    'Join hundreds of happy customers who trust us for quality and speed.',
  ],
  ctas: ['Shop Now', 'Order Today', 'Grab Yours', 'Buy Now'],
);

// ---------------------------------------------------------------------------
// PAS — Problem, Agitate, Solution
// ---------------------------------------------------------------------------
const _pas = CopyFramework(
  id: 'pas',
  name: 'Problem-Agitate-Solution',
  headlines: [
    'Tired of Low Quality?',
    'Still Paying Too Much?',
    'Frustrated with Slow Delivery?',
    'Can\'t Find What You Need?',
  ],
  subheadlines: [
    'You deserve better — and we\'re here to deliver.',
    'Stop settling. Start enjoying premium quality today.',
    'The struggle ends now. Here\'s the solution.',
  ],
  bodies: [
    'We understand the pain of waiting weeks for subpar products. That\'s why we built a better way.',
    'No more disappointment. Every order is quality-checked and delivered fast across Uganda.',
    'Say goodbye to overpriced, low-quality goods. Experience the difference with us.',
  ],
  ctas: ['Fix It Now', 'Get the Solution', 'Shop Smarter', 'Try Us Today'],
);

// ---------------------------------------------------------------------------
// FAB — Features, Advantages, Benefits
// ---------------------------------------------------------------------------
const _fab = CopyFramework(
  id: 'fab',
  name: 'Feature-Advantage-Benefit',
  headlines: [
    'Premium Quality at Local Prices',
    'Built to Last, Priced to Sell',
    'The Smart Choice for Smart Buyers',
    'Why Pay More for Less?',
  ],
  subheadlines: [
    'Here\'s exactly what you get and why it matters.',
    'Every feature designed with you in mind.',
  ],
  bodies: [
    '✓ Top-grade materials → Longer lasting\n✓ Fast local delivery → Save time\n✓ Friendly support → Peace of mind',
    '✓ Carefully selected → No regrets\n✓ Affordable pricing → More value\n✓ Easy ordering → Stress-free shopping',
  ],
  ctas: ['See the Benefits', 'Order Now', 'Shop Smart'],
);

// ---------------------------------------------------------------------------
// Social Proof — only used when the seller has verified review data.
///
/// NOTE: These frameworks are NOT used by default. They are only applied
/// when the seller has actual review data (ratings, review count) from
/// the backend. Using them without verified data would be fabrication.
// ---------------------------------------------------------------------------
const socialProofFramework = CopyFramework(
  id: 'social',
  name: 'Social Proof',
  headlines: [
    'Trusted by Ugandan Buyers',
    'Quality You Can Count On',
    'Your Neighbour\'s Favourite Shop',
    'Join Our Customers',
  ],
  subheadlines: [
    'Real people. Real quality.',
    'See what makes us different.',
  ],
  bodies: [
    'We stand behind every product we sell. Quality checked, carefully packed.',
    'Trusted by families and businesses across Uganda.',
  ],
  ctas: ['Shop With Us', 'See Our Catalog', 'Visit Us'],
);

// ---------------------------------------------------------------------------
// Scarcity / Urgency — only used when stock is ACTUALLY low.
///
/// NOTE: These frameworks are NOT used by default. They are only applied
/// when the catalog item has verified low stock (stockEnabled && stockQty <= 5).
// ---------------------------------------------------------------------------
const _scarcity = CopyFramework(
  id: 'scarcity',
  name: 'Scarcity & Urgency',
  headlines: [
    'Limited Availability',
    'While Stocks Last',
    'Quality Finds — Act Today',
    'Don\'t Miss Out',
  ],
  subheadlines: [
    'Genuine stock, limited quantity.',
    'Quality items move fast.',
  ],
  bodies: [
    'Stock is limited. Order now to avoid disappointment.',
    'Popular item — secure yours today.',
  ],
  ctas: ['Order Now', 'Check Availability', 'Shop Today'],
);

// ---------------------------------------------------------------------------
// Storytelling
// ---------------------------------------------------------------------------
const _story = CopyFramework(
  id: 'story',
  name: 'Storytelling',
  headlines: [
    'It All Started With a Simple Idea',
    'From Our Family to Yours',
    'Born in Uganda, Loved by All',
    'A Story of Quality & Trust',
  ],
  subheadlines: [
    'Every product has a journey. Here\'s ours.',
    'We started small, but dreamed big.',
  ],
  bodies: [
    'What began as a passion for quality has grown into a trusted brand. Every item we sell carries that same spirit.',
    'We believe every customer deserves the best. That\'s why we handpick, inspect, and deliver with care.',
  ],
  ctas: ['Be Part of the Story', 'Shop Our Journey', 'Experience It'],
);

// ---------------------------------------------------------------------------
// Business-info specific frameworks
// ---------------------------------------------------------------------------
const welcomeFramework = CopyFramework(
  id: 'welcome',
  name: 'Welcome / About',
  headlines: [
    'Welcome to {{BUSINESS}}',
    'Your New Favourite Shop',
    'Proudly Serving Uganda',
    'Quality Meets Convenience',
  ],
  subheadlines: [
    '{{TAGLINE}}',
    'We\'re here to make your life easier.',
    'Discover what makes us different.',
  ],
  bodies: [
    'At {{BUSINESS}}, we believe in quality, trust, and prompt service.',
    'We\'re here to serve you — quality products, fair prices.',
  ],
  ctas: ['Explore Our Shop', 'See What We Offer', 'Visit Us'],
);

const contactFramework = CopyFramework(
  id: 'contact',
  name: 'Contact / Location',
  headlines: [
    'Find Us / Reach Out',
    'We\'re Just a Message Away',
    'Visit {{BUSINESS}} Today',
    'Let\'s Connect',
  ],
  subheadlines: ['{{LOCATION}}', 'Easy to reach. Always happy to help.'],
  bodies: [
    '📍 {{LOCATION}}\n📞 {{PHONE}}\n💬 {{WHATSAPP}}\n🌐 {{CTA_LINK}}',
    'Have questions? Reach out anytime. We\'re here to help you find exactly what you need.',
  ],
  ctas: ['Call Now', 'WhatsApp Us', 'Get Directions'],
);

const trustFramework = CopyFramework(
  id: 'trust',
  name: 'Trust & Guarantee',
  headlines: [
    'Quality You Can Trust',
    'Why Customers Choose Us',
    'The {{BUSINESS}} Difference',
    'Built on Trust',
  ],
  subheadlines: [
    'We stand behind every product we sell.',
    'Carefully packed, promptly delivered.',
  ],
  bodies: [
    '✓ Every item checked before packing\n✓ Careful packing · Prompt delivery\n✓ Friendly customer support',
  ],
  ctas: ['Shop With Us', 'See Our Shop', 'Visit Us'],
);

const referralFramework = CopyFramework(
  id: 'referral',
  name: 'Referral',
  headlines: [
    'Love Our Products? Tell a Friend',
    'Share with Friends',
    'Spread the Word',
    'Recommend {{BUSINESS}}',
  ],
  subheadlines: [
    'Good things are worth sharing.',
    'Tell friends about us.',
  ],
  bodies: [
    'If you enjoy our products, tell your friends about {{BUSINESS}}.',
  ],
  ctas: ['Share Our Shop', 'Tell a Friend'],
);

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------
const copyFrameworks = <CopyFramework>[
  _aida,
  _pas,
  _fab,
  socialProofFramework,
  _scarcity,
  _story,
];

const businessCopyFrameworks = <CopyFramework>[
  welcomeFramework,
  contactFramework,
  trustFramework,
  referralFramework,
];

/// Get a framework by ID.
CopyFramework? frameworkById(String id) {
  for (final f in [...copyFrameworks, ...businessCopyFrameworks]) {
    if (f.id == id) return f;
  }
  return null;
}

/// Pick a framework deterministically based on seed and category.
CopyFramework pickFramework({required int seed, String category = ''}) {
  final all = [...copyFrameworks, ...businessCopyFrameworks];
  final hash = '${category}_$seed'.hashCode.abs();
  return all[hash % all.length];
}
