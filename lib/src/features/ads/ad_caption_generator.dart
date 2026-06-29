// ---------------------------------------------------------------------------
// Platform-optimized caption generator for Soko Studio ads
// ---------------------------------------------------------------------------

enum CaptionPlatform {
  whatsapp,
  instagram,
  facebook,
  x,
}

extension CaptionPlatformX on CaptionPlatform {
  String get label => switch (this) {
    CaptionPlatform.whatsapp => 'WhatsApp',
    CaptionPlatform.instagram => 'Instagram',
    CaptionPlatform.facebook => 'Facebook',
    CaptionPlatform.x => 'X / Twitter',
  };

  int get maxLength => switch (this) {
    CaptionPlatform.whatsapp => 2000,
    CaptionPlatform.instagram => 2200,
    CaptionPlatform.facebook => 5000,
    CaptionPlatform.x => 280,
  };

  String get emojiStyle => switch (this) {
    CaptionPlatform.whatsapp => 'moderate',
    CaptionPlatform.instagram => 'heavy',
    CaptionPlatform.facebook => 'moderate',
    CaptionPlatform.x => 'minimal',
  };
}

class GeneratedCaption {
  const GeneratedCaption({
    required this.platform,
    required this.text,
    required this.hashtags,
  });

  final CaptionPlatform platform;
  final String text;
  final List<String> hashtags;

  String get fullText => '$text\n\n${hashtags.join(' ')}';
}

/// Generates platform-optimized captions for an ad.
GeneratedCaption generateCaption({
  required CaptionPlatform platform,
  required String productName,
  required String price,
  required String businessName,
  String? description,
  String? shopUrl,
  String? whatsapp,
  String? phone,
  String? location,
  String? tagline,
  List<String> extraHashtags = const [],
  int seed = 0,
}) {
  final desc = description ?? '';
  final url = shopUrl?.isNotEmpty == true ? shopUrl! : 'soko24.co';
  final contact = whatsapp?.isNotEmpty == true
      ? 'WhatsApp: $whatsapp'
      : phone?.isNotEmpty == true
          ? 'Call: $phone'
          : '';
  final loc = location?.isNotEmpty == true ? '📍 $location' : '';

  final hash = seed + platform.name.hashCode + productName.hashCode;

  String text;
  List<String> hashtags;

  switch (platform) {
    case CaptionPlatform.whatsapp:
      text = _whatsappCaption(
        productName: productName,
        price: price,
        businessName: businessName,
        desc: desc,
        url: url,
        contact: contact,
        loc: loc,
        tagline: tagline,
        hash: hash,
      );
      hashtags = [...extraHashtags];

    case CaptionPlatform.instagram:
      text = _instagramCaption(
        productName: productName,
        price: price,
        businessName: businessName,
        desc: desc,
        url: url,
        contact: contact,
        loc: loc,
        tagline: tagline,
        hash: hash,
      );
      hashtags = [
        '#ShopLocal',
        '#Uganda',
        '#Kampala',
        '#SupportLocal',
        '#SmallBusiness',
        ...extraHashtags,
      ];

    case CaptionPlatform.facebook:
      text = _facebookCaption(
        productName: productName,
        price: price,
        businessName: businessName,
        desc: desc,
        url: url,
        contact: contact,
        loc: loc,
        tagline: tagline,
        hash: hash,
      );
      hashtags = [
        '#ShopLocal',
        '#UgandaBusiness',
        ...extraHashtags,
      ];

    case CaptionPlatform.x:
      text = _xCaption(
        productName: productName,
        price: price,
        businessName: businessName,
        desc: desc,
        url: url,
        contact: contact,
        loc: loc,
        tagline: tagline,
        hash: hash,
      );
      hashtags = extraHashtags.take(2).toList();
  }

  // Trim to platform max length
  if (text.length > platform.maxLength - 50) {
    text = '${text.substring(0, platform.maxLength - 53)}...';
  }

  return GeneratedCaption(
    platform: platform,
    text: text,
    hashtags: hashtags,
  );
}

String _whatsappCaption({
  required String productName,
  required String price,
  required String businessName,
  required String desc,
  required String url,
  required String contact,
  required String loc,
  required String? tagline,
  required int hash,
}) {
  final lines = <String>[
    '✨ *$productName*',
    '',
    '💰 *$price*',
    if (desc.isNotEmpty) '',
    if (desc.isNotEmpty) desc,
    if (tagline?.isNotEmpty == true) '',
    if (tagline?.isNotEmpty == true) '_${tagline!}_',
    '',
    '🛒 Order: $url',
    if (contact.isNotEmpty) contact,
    if (loc.isNotEmpty) loc,
    '',
    '— $businessName',
  ];
  return lines.join('\n');
}

String _instagramCaption({
  required String productName,
  required String price,
  required String businessName,
  required String desc,
  required String url,
  required String contact,
  required String loc,
  required String? tagline,
  required int hash,
}) {
  final hooks = [
    'New drop alert 🚨',
    'You need this in your life ✨',
    'This just landed 🔥',
    'Obsessed with this 😍',
    'Your cart is calling 🛒',
  ];
  final hook = hooks[hash % hooks.length];

  final lines = <String>[
    hook,
    '',
    productName,
    if (desc.isNotEmpty) '',
    if (desc.isNotEmpty) desc,
    '',
    '💰 $price',
    if (tagline?.isNotEmpty == true) '',
    if (tagline?.isNotEmpty == true) tagline!,
    '',
    '🛒 Tap the link in bio to shop',
    if (contact.isNotEmpty) 'Or $contact',
    if (loc.isNotEmpty) loc,
    '',
    '— $businessName',
  ];
  return lines.join('\n');
}

String _facebookCaption({
  required String productName,
  required String price,
  required String businessName,
  required String desc,
  required String url,
  required String contact,
  required String loc,
  required String? tagline,
  required int hash,
}) {
  final lines = <String>[
    'Check out $productName from $businessName!',
    '',
    if (desc.isNotEmpty) desc,
    if (desc.isNotEmpty) '',
    'Price: $price',
    if (tagline?.isNotEmpty == true) '',
    if (tagline?.isNotEmpty == true) tagline!,
    '',
    'Shop now: $url',
    if (contact.isNotEmpty) contact,
    if (loc.isNotEmpty) loc,
  ];
  return lines.join('\n');
}

String _xCaption({
  required String productName,
  required String price,
  required String businessName,
  required String desc,
  required String url,
  required String contact,
  required String loc,
  required String? tagline,
  required int hash,
}) {
  final phrases = [
    '$productName — $price. Shop $businessName: $url',
    'Just dropped: $productName at $price. $url',
    '$businessName has $productName for $price. Check it out! $url',
  ];
  return phrases[hash % phrases.length];
}

/// Generates all platform captions at once.
Map<CaptionPlatform, GeneratedCaption> generateAllCaptions({
  required String productName,
  required String price,
  required String businessName,
  String? description,
  String? shopUrl,
  String? whatsapp,
  String? phone,
  String? location,
  String? tagline,
  List<String> extraHashtags = const [],
  int seed = 0,
}) {
  final result = <CaptionPlatform, GeneratedCaption>{};
  for (final platform in CaptionPlatform.values) {
    result[platform] = generateCaption(
      platform: platform,
      productName: productName,
      price: price,
      businessName: businessName,
      description: description,
      shopUrl: shopUrl,
      whatsapp: whatsapp,
      phone: phone,
      location: location,
      tagline: tagline,
      extraHashtags: extraHashtags,
      seed: seed + platform.index,
    );
  }
  return result;
}
