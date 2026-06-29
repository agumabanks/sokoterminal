import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import 'ad_templates.dart';
import 'studio_editor_launcher.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class BrandKit {
  const BrandKit({
    this.primaryColor = '#0F1D40',
    this.secondaryColor = '#0EBE7E',
    this.accentColor = '#fbbf24',
    this.font = 'Poppins',
    this.headingFont = 'Montserrat',
    this.businessName = '',
    this.tagline = '',
    this.website = '',
    this.phone = '',
    this.whatsapp = '',
    this.location = '',
    this.logoLocalPath,
    this.logoNetworkUrl,
    this.seededFromShop = false,
  });

  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String font;
  final String headingFont;
  final String businessName;
  final String tagline;
  final String website;
  final String phone;
  final String whatsapp;
  final String location;
  final String? logoLocalPath;
  final String? logoNetworkUrl;
  final bool seededFromShop;

  String get effectiveLogoUrl => logoLocalPath ?? logoNetworkUrl ?? '';
  bool get hasLogo => logoLocalPath != null || logoNetworkUrl != null;

  BrandKit copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? font,
    String? headingFont,
    String? businessName,
    String? tagline,
    String? website,
    String? phone,
    String? whatsapp,
    String? location,
    Object? logoLocalPath = _sentinel,
    Object? logoNetworkUrl = _sentinel,
    bool? seededFromShop,
  }) =>
      BrandKit(
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        accentColor: accentColor ?? this.accentColor,
        font: font ?? this.font,
        headingFont: headingFont ?? this.headingFont,
        businessName: businessName ?? this.businessName,
        tagline: tagline ?? this.tagline,
        website: website ?? this.website,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        location: location ?? this.location,
        logoLocalPath: logoLocalPath == _sentinel
            ? this.logoLocalPath
            : logoLocalPath as String?,
        logoNetworkUrl: logoNetworkUrl == _sentinel
            ? this.logoNetworkUrl
            : logoNetworkUrl as String?,
        seededFromShop: seededFromShop ?? this.seededFromShop,
      );

  Map<String, dynamic> toJson() => {
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'font': font,
        'headingFont': headingFont,
        'businessName': businessName,
        'tagline': tagline,
        'website': website,
        'phone': phone,
        'whatsapp': whatsapp,
        'location': location,
        if (logoLocalPath != null) 'logoLocalPath': logoLocalPath,
        if (logoNetworkUrl != null) 'logoNetworkUrl': logoNetworkUrl,
        'seededFromShop': seededFromShop,
      };

  factory BrandKit.fromJson(Map<String, dynamic> j) => BrandKit(
        primaryColor: j['primaryColor']?.toString() ?? '#0F1D40',
        secondaryColor: j['secondaryColor']?.toString() ?? '#0EBE7E',
        accentColor: j['accentColor']?.toString() ?? '#fbbf24',
        font: j['font']?.toString() ?? 'Poppins',
        headingFont: j['headingFont']?.toString() ?? 'Montserrat',
        businessName: j['businessName']?.toString() ?? '',
        tagline: j['tagline']?.toString() ?? '',
        website: j['website']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        whatsapp: j['whatsapp']?.toString() ?? '',
        location: j['location']?.toString() ?? '',
        logoLocalPath: j['logoLocalPath']?.toString(),
        logoNetworkUrl: j['logoNetworkUrl']?.toString(),
        seededFromShop: j['seededFromShop'] as bool? ?? false,
      );

  factory BrandKit.fromShopProfile(BusinessProfile profile) {
    final phone = profile.shopPhone ?? profile.sellerPhone ?? '';
    return BrandKit(
      businessName: profile.shopName,
      tagline: profile.metaTitle ?? profile.metaDescription ?? '',
      logoNetworkUrl: profile.logoUrl,
      phone: phone,
      whatsapp: phone,
      location: profile.shopAddress ?? '',
      seededFromShop: true,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class _BrandKitNotifier extends StateNotifier<BrandKit> {
  _BrandKitNotifier(this._prefs, this._db, this._api)
      : super(const BrandKit()) {
    _load();
  }

  final SharedPreferences _prefs;
  final AppDatabase _db;
  final SellerApi _api;
  static const _key = 'studio_brand_kit_v2';

  Future<void> _load() async {
    // 1. Try loading from local prefs
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        state = BrandKit.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    // 2. If never seeded from shop, auto-populate from BusinessProfile
    if (!state.seededFromShop) {
      final profile = await _db.getBusinessProfile();
      if (profile != null) {
        final seeded = BrandKit.fromShopProfile(profile);
        state = state.copyWith(
          businessName: state.businessName.isEmpty
              ? seeded.businessName
              : state.businessName,
          tagline:
              state.tagline.isEmpty ? seeded.tagline : state.tagline,
          logoNetworkUrl:
              state.logoNetworkUrl ?? seeded.logoNetworkUrl,
          phone: state.phone.isEmpty ? seeded.phone : state.phone,
          location: state.location.isEmpty ? seeded.location : state.location,
          seededFromShop: true,
        );
        await _persist();
      }
    }

    // 3. Try fetching from backend (silent fail)
    _fetchFromBackend();
  }

  Future<void> _fetchFromBackend() async {
    try {
      final res = await _api.fetchBrandKit();
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] != null) {
        final remote = BrandKit.fromJson(data['data'] as Map<String, dynamic>);
        // Merge: prefer local logo path, remote everything else
        state = remote.copyWith(
          logoLocalPath: state.logoLocalPath,
        );
        await _persist();
      }
    } catch (_) {
      // offline — ignore
    }
  }

  Future<void> update(BrandKit kit) async {
    state = kit;
    await _persist();
    _pushToBackend(kit);
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> _pushToBackend(BrandKit kit) async {
    try {
      await _api.saveBrandKit(kit.toJson());
    } catch (_) {
      // offline — will sync next time
    }
  }

  Future<String?> pickAndSaveLogo() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (xf == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final logoDir = Directory(p.join(dir.path, 'brand_kit'));
    await logoDir.create(recursive: true);
    final dest = p.join(logoDir.path, 'logo.png');
    await File(xf.path).copy(dest);

    String? networkUrl;
    try {
      final res = await _api.uploadSellerFile(File(dest));
      final body = res.data;
      if (body is Map && body['result'] == true) {
        networkUrl = body['url']?.toString();
      }
    } catch (_) {}

    final updated = state.copyWith(
      logoLocalPath: dest,
      logoNetworkUrl: networkUrl ?? state.logoNetworkUrl,
    );
    await update(updated);
    return dest;
  }

  Future<void> removeLogo() async {
    final updated = state.copyWith(
      logoLocalPath: null,
      logoNetworkUrl: null,
    );
    await update(updated);
  }
}

final brandKitProvider =
    StateNotifierProvider<_BrandKitNotifier, BrandKit>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);
  return _BrandKitNotifier(prefs, db, api);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BrandKitScreen extends ConsumerStatefulWidget {
  const BrandKitScreen({super.key});

  @override
  ConsumerState<BrandKitScreen> createState() => _BrandKitScreenState();
}

class _BrandKitScreenState extends ConsumerState<BrandKitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  late TextEditingController _nameCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    final kit = ref.read(brandKitProvider);
    _nameCtrl = TextEditingController(text: kit.businessName);
    _taglineCtrl = TextEditingController(text: kit.tagline);
    _websiteCtrl = TextEditingController(text: kit.website);
    _phoneCtrl = TextEditingController(text: kit.phone);
    _whatsappCtrl = TextEditingController(text: kit.whatsapp);
    _locationCtrl = TextEditingController(text: kit.location);
  }

  @override
  void dispose() {
    _tc.dispose();
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _websiteCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _sync(BrandKit kit) =>
      ref.read(brandKitProvider.notifier).update(kit);

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(brandKitProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ElevatedButton.icon(
            onPressed: () async {
              await launchFullStudioWebForBrandKit(
                context,
                ref,
                openPanel: 'brand-kit',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.design_services_rounded, size: 18),
            label: const Text(
              'Design in Studio',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        TabBar(
          controller: _tc,
          labelColor: DesignTokens.brandAccent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: DesignTokens.brandAccent,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded, size: 16), text: 'Identity'),
            Tab(icon: Icon(Icons.palette_rounded, size: 16), text: 'Colors'),
            Tab(icon: Icon(Icons.text_fields_rounded, size: 16), text: 'Fonts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _IdentityTab(
                kit: kit,
                nameCtrl: _nameCtrl,
                taglineCtrl: _taglineCtrl,
                websiteCtrl: _websiteCtrl,
                phoneCtrl: _phoneCtrl,
                whatsappCtrl: _whatsappCtrl,
                locationCtrl: _locationCtrl,
                onUpdate: _sync,
                onPickLogo: () => ref.read(brandKitProvider.notifier).pickAndSaveLogo(),
                onRemoveLogo: () => ref.read(brandKitProvider.notifier).removeLogo(),
              ),
              _ColorsTab(kit: kit, onUpdate: _sync),
              _FontsTab(kit: kit, onUpdate: _sync),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Identity tab
// ---------------------------------------------------------------------------

class _IdentityTab extends StatelessWidget {
  const _IdentityTab({
    required this.kit,
    required this.nameCtrl,
    required this.taglineCtrl,
    required this.websiteCtrl,
    required this.phoneCtrl,
    required this.whatsappCtrl,
    required this.locationCtrl,
    required this.onUpdate,
    required this.onPickLogo,
    required this.onRemoveLogo,
  });

  final BrandKit kit;
  final TextEditingController nameCtrl;
  final TextEditingController taglineCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController whatsappCtrl;
  final TextEditingController locationCtrl;
  final ValueChanged<BrandKit> onUpdate;
  final Future<String?> Function() onPickLogo;
  final VoidCallback onRemoveLogo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Brand preview ─────────────────────────────────────────────────
        _BrandPreviewCard(kit: kit),
        const SizedBox(height: 20),

        // ── Logo upload ────────────────────────────────────────────────────
        _Section(label: 'Business Logo', children: [
          Row(
            children: [
              // Logo preview
              GestureDetector(
                onTap: onPickLogo,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kit.hasLogo
                          ? DesignTokens.brandAccent
                          : Colors.white12,
                      width: kit.hasLogo ? 2 : 1,
                    ),
                  ),
                  child: _LogoWidget(kit: kit, size: 80),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onPickLogo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: DesignTokens.brandAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: DesignTokens.brandAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_rounded,
                                color: DesignTokens.brandAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Upload Logo',
                                style: TextStyle(
                                    color: DesignTokens.brandAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    if (kit.hasLogo) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onRemoveLogo,
                        child: const Text('Remove logo',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 11)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      kit.seededFromShop
                          ? 'Auto-filled from your shop profile'
                          : 'PNG or JPG, square preferred',
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]),

        const SizedBox(height: 16),

        // ── Business info ─────────────────────────────────────────────────
        _Section(label: 'Business Name & Tagline', children: [
          _DarkField(
            ctrl: nameCtrl,
            hint: 'e.g. Mama Zawadi Fashion',
            icon: Icons.store_rounded,
            onChanged: (v) => onUpdate(kit.copyWith(businessName: v)),
          ),
          const SizedBox(height: 10),
          _DarkField(
            ctrl: taglineCtrl,
            hint: 'e.g. Style for every occasion',
            icon: Icons.format_quote_rounded,
            onChanged: (v) => onUpdate(kit.copyWith(tagline: v)),
          ),
        ]),

        const SizedBox(height: 16),

        // ── WhatsApp CTA — highlighted as most important ───────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF075E54), Color(0xFF128C7E)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'WhatsApp CTA  ·  {{WHATSAPP}}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This number appears on every ad CTA button automatically — '
                'the most important field in your brand kit.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    height: 1.4),
              ),
              const SizedBox(height: 10),
              _DarkField(
                ctrl: whatsappCtrl,
                hint: 'e.g. 0700 123 456 or +256700123456',
                icon: Icons.chat_rounded,
                onChanged: (v) => onUpdate(kit.copyWith(whatsapp: v)),
              ),
              if (kit.whatsapp.isEmpty) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: DesignTokens.warning, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'Add your WhatsApp to enable CTA on all templates',
                      style: TextStyle(
                          color: DesignTokens.warning, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Other contact details ──────────────────────────────────────────
        _Section(label: 'Additional Contact & Location', children: [
          _DarkField(
            ctrl: phoneCtrl,
            hint: 'Phone number  ·  {{PHONE}}',
            icon: Icons.phone_rounded,
            onChanged: (v) => onUpdate(kit.copyWith(phone: v)),
          ),
          const SizedBox(height: 10),
          _DarkField(
            ctrl: locationCtrl,
            hint: 'Location  ·  {{LOCATION}}  (e.g. Kampala, Nakasero)',
            icon: Icons.location_on_rounded,
            onChanged: (v) => onUpdate(kit.copyWith(location: v)),
          ),
          const SizedBox(height: 10),
          _DarkField(
            ctrl: websiteCtrl,
            hint: 'Website  ·  {{CTA_LINK}}  (e.g. soko24.co/your-shop)',
            icon: Icons.language_rounded,
            onChanged: (v) => onUpdate(kit.copyWith(website: v)),
          ),
        ]),

        const SizedBox(height: 16),

        // ── Variables reference ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TEMPLATE VARIABLES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                ('{{WHATSAPP}}', 'Your WhatsApp CTA number'),
                ('{{PHONE}}', 'Your phone number'),
                ('{{CTA_LINK}}', 'Website or shop URL'),
                ('{{BUSINESS}}', 'Your business name'),
                ('{{LOCATION}}', 'Your location'),
              ].map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: DesignTokens.brandAccent
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: DesignTokens.brandAccent
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            v.$1,
                            style: const TextStyle(
                              color: DesignTokens.brandAccent,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(v.$2,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Auto-apply hint ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DesignTokens.brandAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: DesignTokens.brandAccent.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: DesignTokens.brandAccent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your brand kit is automatically applied to all new ads, '
                  'templates, and the Ad Injector overlays. '
                  'The more complete it is, the better your ads look with zero effort.',
                  style: TextStyle(
                      color: Colors.white60, fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Colors tab
// ---------------------------------------------------------------------------

class _ColorsTab extends StatelessWidget {
  const _ColorsTab({required this.kit, required this.onUpdate});
  final BrandKit kit;
  final ValueChanged<BrandKit> onUpdate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Section(label: 'Brand Colors', children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ColorSlot(
                label: 'Primary',
                hex: kit.primaryColor,
                onSelect: (h) => onUpdate(kit.copyWith(primaryColor: h)),
              ),
              _ColorSlot(
                label: 'Secondary',
                hex: kit.secondaryColor,
                onSelect: (h) => onUpdate(kit.copyWith(secondaryColor: h)),
              ),
              _ColorSlot(
                label: 'Accent',
                hex: kit.accentColor,
                onSelect: (h) => onUpdate(kit.copyWith(accentColor: h)),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        _Section(label: 'Quick Color Presets', children: [
          ..._brandPresets.map((preset) {
            return GestureDetector(
              onTap: () => onUpdate(kit.copyWith(
                primaryColor: preset.$1,
                secondaryColor: preset.$2,
                accentColor: preset.$3,
              )),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    ...[(preset.$1), (preset.$2), (preset.$3)].map((hex) {
                      return Container(
                        width: 28, height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: parseHexColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      preset.$4,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }),
        ]),
      ],
    );
  }
}

// (primary, secondary, accent, label)
const _brandPresets = [
  ('#0F1D40', '#0EBE7E', '#fbbf24', 'Soko Classic'),
  ('#111111', '#ffffff', '#ef4444', 'Nike Black'),
  ('#1e3a5f', '#60a5fa', '#fbbf24', 'Corporate Blue'),
  ('#14532d', '#22c55e', '#ffffff', 'Forest Green'),
  ('#7c3aed', '#c4b5fd', '#ec4899', 'Purple Luxury'),
  ('#7c2d12', '#f97316', '#fef08a', 'Warm Amber'),
  ('#0f172a', '#1d4ed8', '#a78bfa', 'Deep Ocean'),
  ('#78350f', '#d4af37', '#ffffff', 'Gold Premium'),
];

// ---------------------------------------------------------------------------
// Fonts tab
// ---------------------------------------------------------------------------

class _FontsTab extends StatelessWidget {
  const _FontsTab({required this.kit, required this.onUpdate});
  final BrandKit kit;
  final ValueChanged<BrandKit> onUpdate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _Section(label: 'Body Font', children: [
          SizedBox(
            height: 110,
            child: _FontPicker(
              selected: kit.font,
              onSelect: (f) => onUpdate(kit.copyWith(font: f)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _Section(label: 'Heading Font', children: [
          SizedBox(
            height: 110,
            child: _FontPicker(
              selected: kit.headingFont,
              onSelect: (f) => onUpdate(kit.copyWith(headingFont: f)),
            ),
          ),
        ]),
      ],
    );
  }
}

class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: studioFonts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final name = studioFonts.keys.elementAt(i);
        final pkgName = studioFonts.values.elementAt(i);
        final desc = fontDescriptors[name];
        final isSel = selected == name;

        TextStyle style;
        try {
          style = GoogleFonts.getFont(pkgName,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isSel ? DesignTokens.brandAccent : Colors.white);
        } catch (_) {
          style = TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isSel ? DesignTokens.brandAccent : Colors.white);
        }

        return GestureDetector(
          onTap: () => onSelect(name),
          child: Container(
            width: 90,
            decoration: BoxDecoration(
              color: isSel
                  ? DesignTokens.brandAccent.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? DesignTokens.brandAccent : Colors.white10,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(desc?.sample ?? 'Aa', style: style),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                      color: isSel ? DesignTokens.brandAccent : Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (desc != null)
                  Text(desc.vibe,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 7),
                      textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Brand preview card
// ---------------------------------------------------------------------------

class _BrandPreviewCard extends StatelessWidget {
  const _BrandPreviewCard({required this.kit});
  final BrandKit kit;

  @override
  Widget build(BuildContext context) {
    final primary = parseHexColor(kit.primaryColor);
    final secondary = parseHexColor(kit.secondaryColor);
    final accent = parseHexColor(kit.accentColor);

    TextStyle nameStyle = const TextStyle(
        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800);
    TextStyle tagStyle = const TextStyle(color: Colors.white70, fontSize: 12);
    if (studioFonts.containsKey(kit.headingFont)) {
      try {
        nameStyle = GoogleFonts.getFont(studioFonts[kit.headingFont]!,
            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white);
      } catch (_) {}
    }
    if (studioFonts.containsKey(kit.font)) {
      try {
        tagStyle = GoogleFonts.getFont(studioFonts[kit.font]!,
            fontSize: 12, color: Colors.white70);
      } catch (_) {}
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Logo
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: _LogoWidget(kit: kit, size: 64)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kit.businessName.isNotEmpty
                      ? kit.businessName
                      : 'Your Business',
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  kit.tagline.isNotEmpty
                      ? kit.tagline
                      : 'Your tagline here',
                  style: tagStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _Dot(primary),
                  const SizedBox(width: 5),
                  _Dot(secondary),
                  const SizedBox(width: 5),
                  _Dot(accent),
                  const SizedBox(width: 10),
                  Text(kit.font,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 9)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
      );
}

// ---------------------------------------------------------------------------
// Logo widget (handles local file + network url + fallback)
// ---------------------------------------------------------------------------

class _LogoWidget extends StatelessWidget {
  const _LogoWidget({required this.kit, required this.size});
  final BrandKit kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kit.logoLocalPath != null) {
      final file = File(kit.logoLocalPath!);
      if (file.existsSync()) {
        return Image.file(file,
            width: size, height: size, fit: BoxFit.cover);
      }
    }
    if (kit.logoNetworkUrl?.isNotEmpty == true) {
      return Image.network(
        kit.logoNetworkUrl!,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackLogo(kit: kit, size: size),
      );
    }
    return _FallbackLogo(kit: kit, size: size);
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.kit, required this.size});
  final BrandKit kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = kit.businessName.isNotEmpty
        ? kit.businessName[0].toUpperCase()
        : 'S';
    return Container(
      width: size, height: size,
      color: Colors.transparent,
      child: Center(
        child: Icon(
          kit.businessName.isEmpty ? Icons.add_photo_alternate_rounded : null,
          color: Colors.white54,
          size: size * 0.4,
          // Fallback to letter if business name set
        ).apply(
          onNull: Text(
            letter,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

extension on Icon {
  Widget apply({required Widget onNull}) {
    if (icon == null) return onNull;
    return this;
  }
}

// ---------------------------------------------------------------------------
// Color slot
// ---------------------------------------------------------------------------

class _ColorSlot extends StatelessWidget {
  const _ColorSlot({
    required this.label,
    required this.hex,
    required this.onSelect,
  });

  final String label;
  final String hex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: parseHexColor(hex),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                    color: parseHexColor(hex).withValues(alpha: 0.4),
                    blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.colorize_rounded,
                color: Colors.white54, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(hex.toUpperCase(),
              style: const TextStyle(color: Colors.white24, fontSize: 9)),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.brandPrimary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ColorPickerSheet(
          label: label, onSelect: onSelect),
    );
  }
}

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet({required this.label, required this.onSelect});
  final String label;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Pick $label Color',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            children: colorPalette.map((c) {
              return GestureDetector(
                onTap: () {
                  onSelect(colorToHex(c));
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),
          ...children,
        ],
      );
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
    this.icon,
  });

  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.white24, size: 18)
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DesignTokens.brandAccent)),
        ),
      );
}

/// Parse a hex string into a Color.
Color parseKitColor(String hex) {
  try {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return DesignTokens.brandPrimary;
  }
}
