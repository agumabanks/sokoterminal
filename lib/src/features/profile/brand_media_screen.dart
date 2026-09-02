import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/offline_cached_image.dart';

enum _BrandMediaKind { logo, profile, banner }

class BrandMediaScreen extends ConsumerStatefulWidget {
  const BrandMediaScreen({super.key});

  @override
  ConsumerState<BrandMediaScreen> createState() => _BrandMediaScreenState();
}

class _BrandMediaScreenState extends ConsumerState<BrandMediaScreen> {
  bool _loading = true;
  _BrandMediaKind? _uploading;
  String? _logoUrl;
  String? _profileUrl;
  List<String> _bannerUrls = [];
  List<int> _bannerIds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(sellerApiProvider);
      final results = await Future.wait([
        api.fetchShopInfo(),
        api.fetchSellerProfile(),
      ]);
      final shopBody = results[0].data;
      final shop = shopBody is Map && shopBody['data'] is Map
          ? Map<String, dynamic>.from(shopBody['data'] as Map)
          : <String, dynamic>{};
      final sellerBody = results[1].data;
      final seller = sellerBody is Map
          ? Map<String, dynamic>.from(sellerBody)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _logoUrl = shop['logo']?.toString();
        _profileUrl = seller['avatar_original']?.toString();
        _bannerUrls = (shop['sliders'] as List? ?? const [])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList();
        final rawIds = shop['sliders_id'];
        _bannerIds = rawIds is List
            ? rawIds
                  .map((value) => int.tryParse('$value'))
                  .whereType<int>()
                  .toList()
            : '$rawIds'
                  .split(',')
                  .map((value) => int.tryParse(value.trim()))
                  .whereType<int>()
                  .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(_BrandMediaKind kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kind == _BrandMediaKind.banner ? 1920 : 800,
      maxHeight: kind == _BrandMediaKind.banner ? 900 : 800,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() => _uploading = kind);
    try {
      final api = ref.read(sellerApiProvider);
      final upload = await api.uploadSellerFile(File(picked.path));
      final body = upload.data is Map
          ? Map<String, dynamic>.from(upload.data as Map)
          : <String, dynamic>{};
      final id = int.tryParse('${body['id']}');
      final url = body['url']?.toString();
      if (id == null || url == null || url.isEmpty) {
        throw StateError('Upload completed without an image URL');
      }

      if (kind == _BrandMediaKind.logo) {
        await api.updatePosBusinessProfile(
          {'logo': id},
          idempotencyKey: 'brand-logo-${DateTime.now().microsecondsSinceEpoch}',
        );
        _logoUrl = url;
      } else if (kind == _BrandMediaKind.profile) {
        await api.updateSellerAvatar(id);
        _profileUrl = url;
      } else {
        final nextIds = [..._bannerIds, id].take(5).toList();
        await api.updateShopInfo({'sliders': nextIds.join(',')});
        _bannerIds = nextIds;
        _bannerUrls = [..._bannerUrls, url].take(5).toList();
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updated on your Soko24 web shop'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(title: const Text('Shop appearance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                Text('One brand, everywhere', style: DesignTokens.textHeadline),
                const SizedBox(height: 4),
                Text(
                  'Changes here update the same profile used by your web shop and buyer app.',
                  style: DesignTokens.textBody.copyWith(
                    color: DesignTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MediaTile(
                        title: 'Profile photo',
                        subtitle: 'Your seller identity',
                        imageUrl: _profileUrl,
                        round: true,
                        busy: _uploading == _BrandMediaKind.profile,
                        onTap: () => _pick(_BrandMediaKind.profile),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MediaTile(
                        title: 'Shop logo',
                        subtitle: 'Receipts, ads & shop',
                        imageUrl: _logoUrl,
                        busy: _uploading == _BrandMediaKind.logo,
                        onTap: () => _pick(_BrandMediaKind.logo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Storefront banners',
                        style: DesignTokens.textTitle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _uploading == null
                          ? () => _pick(_BrandMediaKind.banner)
                          : null,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add banner'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_bannerUrls.isEmpty)
                  _BannerPlaceholder(onTap: () => _pick(_BrandMediaKind.banner))
                else
                  ..._bannerUrls.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: DesignTokens.borderRadiusLg,
                        child: AspectRatio(
                          aspectRatio: 2.25,
                          child: OfflineCachedImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.busy,
    required this.onTap,
    this.round = false,
  });

  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool busy;
  final VoidCallback onTap;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surfaceRaised,
      borderRadius: DesignTokens.borderRadiusLg,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: DesignTokens.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipOval(
                clipBehavior: round ? Clip.antiAlias : Clip.none,
                child: ClipRRect(
                  borderRadius: round
                      ? BorderRadius.zero
                      : BorderRadius.circular(18),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: busy
                        ? const Center(child: CircularProgressIndicator())
                        : (imageUrl ?? '').isNotEmpty
                        ? OfflineCachedImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const ColoredBox(
                            color: DesignTokens.brandAccentLight,
                            child: Icon(Icons.add_a_photo_outlined),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: DesignTokens.textBodyBold),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: DesignTokens.textCaption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.25,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add your first storefront banner'),
      ),
    );
  }
}
