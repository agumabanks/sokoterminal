import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../ads/ai_content_report_button.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../checkout/checkout_screen.dart';

class MarketingGeneratorScreen extends ConsumerStatefulWidget {
  const MarketingGeneratorScreen({super.key});

  @override
  ConsumerState<MarketingGeneratorScreen> createState() => _MarketingGeneratorScreenState();
}

class _MarketingGeneratorScreenState extends ConsumerState<MarketingGeneratorScreen> {
  String? _selectedId;
  bool _selectedIsService = false;
  bool _generating = false;
  Map<String, dynamic>? _content;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Marketing', style: DesignTokens.textTitle),
      ),
      body: itemsAsync.when(
        loading: () => const LoadingState(),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load catalog',
        ),
        data: (products) {
          final services = servicesAsync.valueOrNull ?? [];
          final allItems = [
            ...products.map((p) => _CatalogItem(
              id: p.id,
              name: p.name,
              price: p.price,
              imageUrl: p.imageUrl,
              isService: false,
            )),
            ...services.map((s) => _CatalogItem(
              id: s.id,
              name: s.title,
              price: s.price,
              imageUrl: s.imageUrl,
              isService: true,
            )),
          ];

          if (allItems.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              subtitle: 'Add products first to generate marketing content',
            );
          }

          return Column(
            children: [
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: DesignTokens.paddingHorizontalMd,
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final isSelected = _selectedId == item.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedId = item.id;
                          _selectedIsService = item.isService;
                          _content = null;
                        });
                      },
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DesignTokens.brandAccent
                              : DesignTokens.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? DesignTokens.brandAccent
                                : DesignTokens.hairline,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Icon(
                                item.isService
                                    ? Icons.room_service_outlined
                                    : Icons.inventory_2_outlined,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.inkMuted,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesignTokens.textCaption.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : DesignTokens.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_selectedId != null && _content == null)
                Padding(
                  padding: DesignTokens.paddingScreen,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _generating ? 'Generating...' : 'Generate Content',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.brandAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: DesignTokens.borderRadiusFull,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

              if (_content != null)
                Expanded(
                  child: ListView(
                    padding: DesignTokens.paddingScreen,
                    children: [
                      AiContentReportButton(reportToken: _content!['_report_token'] as String?),
                      _ContentCard(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        content: _content!['whatsapp'] ?? '',
                        color: DesignTokens.brandAccent,
                        onCopy: () => _copy(_content!['whatsapp'] ?? ''),
                        onShare: () => _shareWhatsApp(_content!['whatsapp'] ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _ContentCard(
                        icon: Icons.photo_camera,
                        label: 'Instagram',
                        content: _content!['instagram'] ?? '',
                        color: DesignTokens.error,
                        onCopy: () => _copy(_content!['instagram'] ?? ''),
                        onShare: () => _share(_content!['instagram'] ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _ContentCard(
                        icon: Icons.sms_outlined,
                        label: 'SMS',
                        content: _content!['sms'] ?? '',
                        color: DesignTokens.info,
                        onCopy: () => _copy(_content!['sms'] ?? ''),
                        onShare: () => _share(_content!['sms'] ?? ''),
                      ),
                      if (_content!['hashtags'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (_content!['hashtags'] as List)
                                .map<Widget>((tag) => Chip(
                                      label: Text(tag.toString()),
                                      backgroundColor:
                                          DesignTokens.brandAccentSubtle,
                                      labelStyle: DesignTokens.textSmall.copyWith(
                                        color: DesignTokens.brandAccent,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),

              if (_selectedId == null)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.auto_awesome,
                    title: 'Select a product',
                    subtitle: 'Then tap generate to create marketing content',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate() async {
    if (_selectedId == null) return;

    setState(() => _generating = true);

    try {
      final api = ref.read(sellerApiProvider);
      final itemsAsync = ref.read(itemsStreamProvider);
      final servicesAsync = ref.read(servicesStreamProvider);

      Map<String, dynamic> itemData;
      if (_selectedIsService) {
        final services = servicesAsync.valueOrNull ?? [];
        final service = services.firstWhere((s) => s.id == _selectedId);
        itemData = {
          'name': service.title,
          'price': service.price,
          'description': service.description ?? '',
          'type': 'service',
        };
      } else {
        final products = itemsAsync.valueOrNull ?? [];
        final product = products.firstWhere((p) => p.id == _selectedId);
        itemData = {
          'name': product.name,
          'price': product.price,
          'description': product.description ?? '',
          'type': 'product',
        };
      }

      final result = await api.generateMarketingContent(itemData);
      if (mounted) {
        setState(() {
          _content = result;
          _generating = false;
        });
        Haptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Haptics.selection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: DesignTokens.brandAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareWhatsApp(String text) {
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    launchUrl(uri).catchError((_) {
      _share(text);
      return false;
    });
  }

  void _share(String text) {
    Share.share(text);
  }
}

class _CatalogItem {
  const _CatalogItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isService,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isService;
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.icon,
    required this.label,
    required this.content,
    required this.color,
    required this.onCopy,
    required this.onShare,
  });

  final IconData icon;
  final String label;
  final String content;
  final Color color;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: DesignTokens.textBodyBold.copyWith(color: color),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: onCopy,
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 18),
                onPressed: onShare,
                tooltip: 'Share',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: DesignTokens.textBody,
          ),
        ],
      ),
    );
  }
}
