import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';

class WholesaleProductDto {
  WholesaleProductDto({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.stockQty,
    required this.status,
  });

  final int id;
  final String name;
  final String priceLabel;
  final int stockQty;
  final bool status;

  factory WholesaleProductDto.fromJson(Map<String, dynamic> json) {
    return WholesaleProductDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      priceLabel: (json['price'] ?? '').toString(),
      stockQty: int.tryParse(json['current_stock']?.toString() ?? '') ?? 0,
      status: json['status'] == true || json['status']?.toString() == '1',
    );
  }
}

class DigitalProductDto {
  DigitalProductDto({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.status,
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final bool status;

  factory DigitalProductDto.fromJson(Map<String, dynamic> json) {
    final priceRaw = json['price'] ?? json['price\t'] ?? json['price\t '] ?? json['price '];
    return DigitalProductDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      price: double.tryParse(priceRaw?.toString() ?? '') ?? 0,
      status: json['status'] == true || json['status']?.toString() == '1',
    );
  }
}

class WholesaleState {
  const WholesaleState({
    this.loading = false,
    this.wholesale = const [],
    this.digital = const [],
    this.error,
  });

  final bool loading;
  final List<WholesaleProductDto> wholesale;
  final List<DigitalProductDto> digital;
  final String? error;

  WholesaleState copyWith({
    bool? loading,
    List<WholesaleProductDto>? wholesale,
    List<DigitalProductDto>? digital,
    String? error,
  }) {
    return WholesaleState(
      loading: loading ?? this.loading,
      wholesale: wholesale ?? this.wholesale,
      digital: digital ?? this.digital,
      error: error,
    );
  }
}

final wholesaleControllerProvider =
    StateNotifierProvider<WholesaleController, WholesaleState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return WholesaleController(api)..load();
});

class WholesaleController extends StateNotifier<WholesaleState> {
  WholesaleController(this.api) : super(const WholesaleState());
  final SellerApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final wholesaleRes = await api.fetchWholesaleProducts();
      final digitalRes = await api.fetchDigitalProducts();

      final wholesaleData = wholesaleRes.data;
      final wholesaleList =
          wholesaleData is Map<String, dynamic> ? (wholesaleData['data'] as List? ?? const []) : const [];
      final wholesale = wholesaleList
          .whereType<Map>()
          .map((e) => WholesaleProductDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();

      final digitalData = digitalRes.data;
      final digitalList =
          digitalData is Map<String, dynamic> ? (digitalData['data'] as List? ?? const []) : const [];
      final digital = digitalList
          .whereType<Map>()
          .map((e) => DigitalProductDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();

      state = state.copyWith(loading: false, wholesale: wholesale, digital: digital);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class WholesaleScreen extends ConsumerWidget {
  const WholesaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wholesaleControllerProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Wholesale & Digital', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(wholesaleControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: state.loading && state.wholesale.isEmpty && state.digital.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(wholesaleControllerProvider.notifier).load(),
              child: ListView(
                padding: DesignTokens.paddingScreen,
                children: [
                  Text('Wholesale products', style: DesignTokens.textTitleMedium),
                  const SizedBox(height: DesignTokens.spaceSm),
                  if (state.wholesale.isEmpty)
                    _EmptySection(text: state.error ?? 'No wholesale products')
                  else
                    ...state.wholesale.map(
                      (p) => _RowCard(
                        icon: Icons.warehouse_outlined,
                        title: p.name.isEmpty ? 'Product #${p.id}' : p.name,
                        subtitle: '${p.priceLabel} • Stock ${p.stockQty}',
                        badge: p.status ? 'Published' : 'Draft',
                        badgeColor: p.status ? DesignTokens.success : DesignTokens.warning,
                      ),
                    ),
                  const SizedBox(height: DesignTokens.spaceLg),
                  Text('Digital products', style: DesignTokens.textTitleMedium),
                  const SizedBox(height: DesignTokens.spaceSm),
                  if (state.digital.isEmpty)
                    _EmptySection(text: state.error ?? 'No digital products')
                  else
                    ...state.digital.map(
                      (p) => _RowCard(
                        icon: Icons.cloud_download_outlined,
                        title: p.name.isEmpty ? 'Digital #${p.id}' : p.name,
                        subtitle: '${p.category.isEmpty ? 'Digital' : p.category} • UGX ${p.price.toStringAsFixed(0)}',
                        badge: p.status ? 'Published' : 'Draft',
                        badgeColor: p.status ? DesignTokens.success : DesignTokens.warning,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          child: Icon(icon, color: badgeColor),
        ),
        title: Text(title, style: DesignTokens.textBodyBold),
        subtitle: Text(subtitle, style: DesignTokens.textSmall),
        trailing: Chip(
          label: Text(badge),
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          labelStyle: TextStyle(color: badgeColor),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
      child: Text(text, style: DesignTokens.textSmall),
    );
  }
}

