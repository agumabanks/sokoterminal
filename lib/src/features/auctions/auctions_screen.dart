import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class AuctionProductDto {
  AuctionProductDto({
    required this.id,
    required this.name,
    required this.thumbnailImage,
    required this.mainPriceLabel,
    required this.startDate,
    required this.endDate,
    required this.totalBids,
    required this.canEdit,
  });

  final int id;
  final String name;
  final String thumbnailImage;
  final String mainPriceLabel;
  final String startDate;
  final String endDate;
  final int totalBids;
  final bool canEdit;

  factory AuctionProductDto.fromJson(Map<String, dynamic> json) {
    return AuctionProductDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      thumbnailImage: (json['thumbnail_image'] ?? '').toString(),
      mainPriceLabel: (json['main_price'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      totalBids: int.tryParse(json['total_bids']?.toString() ?? '') ?? 0,
      canEdit: json['can_edit'] == true || json['can_edit']?.toString() == '1',
    );
  }
}

class AuctionBidDto {
  AuctionBidDto({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.amountLabel,
    required this.dateLabel,
  });

  final int id;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String amountLabel;
  final String dateLabel;

  factory AuctionBidDto.fromJson(Map<String, dynamic> json) {
    return AuctionBidDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      customerName: (json['customer_name'] ?? '').toString(),
      customerEmail: (json['customer_email'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      amountLabel: (json['bidded_amout'] ?? '').toString(),
      dateLabel: (json['date'] ?? '').toString(),
    );
  }
}

class AuctionsState {
  const AuctionsState({this.loading = false, this.items = const [], this.error});
  final bool loading;
  final List<AuctionProductDto> items;
  final String? error;

  AuctionsState copyWith({bool? loading, List<AuctionProductDto>? items, String? error}) {
    return AuctionsState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

final auctionsControllerProvider =
    StateNotifierProvider<AuctionsController, AuctionsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return AuctionsController(api)..load();
});

class AuctionsController extends StateNotifier<AuctionsState> {
  AuctionsController(this.api) : super(const AuctionsState());
  final SellerApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchAuctionProducts();
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
      final items = list
          .whereType<Map>()
          .map((e) => AuctionProductDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();
      state = state.copyWith(loading: false, items: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<List<AuctionBidDto>> loadBids(int productId) async {
    final res = await api.fetchAuctionProductBids(productId);
    final data = res.data;
    final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
    return list
        .whereType<Map>()
        .map((e) => AuctionBidDto.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id != 0)
        .toList();
  }

  Future<void> deleteBid(int bidId) async {
    await api.deleteAuctionBid(bidId);
  }
}

class AuctionsScreen extends ConsumerWidget {
  const AuctionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auctionsControllerProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Auctions', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(auctionsControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(auctionsControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: DesignTokens.paddingScreen,
                itemCount: state.items.length + (state.items.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (state.items.isEmpty) {
                    return _EmptyAuctionsState(error: state.error);
                  }
                  final auction = state.items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceWhite,
                      borderRadius: DesignTokens.borderRadiusMd,
                      boxShadow: DesignTokens.shadowSm,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: DesignTokens.warning.withOpacity(0.12),
                        child: const Icon(Icons.gavel_outlined, color: DesignTokens.warning),
                      ),
                      title: Text(auction.name.isEmpty ? 'Auction #${auction.id}' : auction.name,
                          style: DesignTokens.textBodyBold),
                      subtitle: Text(
                        '${auction.mainPriceLabel} • ${auction.totalBids} bids',
                        style: DesignTokens.textSmall,
                      ),
                      trailing: const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
                      onTap: () => _openAuction(context, ref, auction),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openAuction(BuildContext context, WidgetRef ref, AuctionProductDto auction) {
    BottomSheetModal.show(
      context: context,
      title: auction.name.isEmpty ? 'Auction #${auction.id}' : auction.name,
      subtitle: '${auction.mainPriceLabel} • ${auction.totalBids} bids',
      maxHeight: 600,
      child: _AuctionDetailSheet(auction: auction),
    );
  }
}

class _AuctionDetailSheet extends ConsumerStatefulWidget {
  const _AuctionDetailSheet({required this.auction});
  final AuctionProductDto auction;

  @override
  ConsumerState<_AuctionDetailSheet> createState() => _AuctionDetailSheetState();
}

class _AuctionDetailSheetState extends ConsumerState<_AuctionDetailSheet> {
  late Future<List<AuctionBidDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(auctionsControllerProvider.notifier).loadBids(widget.auction.id);
  }

  void _refresh() {
    setState(() {
      _future = ref.read(auctionsControllerProvider.notifier).loadBids(widget.auction.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auction = widget.auction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: DesignTokens.paddingMd,
          decoration: BoxDecoration(
            color: DesignTokens.grayLight.withOpacity(0.25),
            borderRadius: DesignTokens.borderRadiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start: ${auction.startDate}', style: DesignTokens.textSmall),
              Text('End: ${auction.endDate}', style: DesignTokens.textSmall),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Row(
          children: [
            Text('Bids', style: DesignTokens.textBodyBold),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh bids',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<AuctionBidDto>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load bids: ${snapshot.error}', style: DesignTokens.textBody),
                );
              }
              final bids = snapshot.data ?? const [];
              if (bids.isEmpty) {
                return Center(child: Text('No bids yet', style: DesignTokens.textSmall));
              }
              return ListView.builder(
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DesignTokens.brandPrimary.withOpacity(0.08),
                      child: const Icon(Icons.person_outline, color: DesignTokens.brandPrimary),
                    ),
                    title: Text(bid.customerName, style: DesignTokens.textBodyBold),
                    subtitle: Text('${bid.amountLabel} • ${bid.dateLabel}', style: DesignTokens.textSmall),
                    trailing: IconButton(
                      tooltip: 'Delete bid',
                      icon: const Icon(Icons.delete_outline, color: DesignTokens.error),
                      onPressed: () async {
                        await ref.read(auctionsControllerProvider.notifier).deleteBid(bid.id);
                        _refresh();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyAuctionsState extends StatelessWidget {
  const _EmptyAuctionsState({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.gavel_outlined, size: 48, color: DesignTokens.grayMedium),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('No auction products', style: DesignTokens.textBodyBold),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text(error!, style: DesignTokens.textSmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

