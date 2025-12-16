import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class CouponDto {
  CouponDto({
    required this.id,
    required this.type,
    required this.code,
    required this.discount,
    required this.discountType,
    required this.startDateLabel,
    required this.endDateLabel,
  });

  final int id;
  final String type;
  final String code;
  final double discount;
  final String discountType;
  final String startDateLabel;
  final String endDateLabel;

  factory CouponDto.fromJson(Map<String, dynamic> json) {
    return CouponDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      type: (json['type'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      discount: double.tryParse(json['discount']?.toString() ?? '') ?? 0,
      discountType: (json['discount_type'] ?? '').toString(),
      startDateLabel: (json['start_date'] ?? '').toString(),
      endDateLabel: (json['end_date'] ?? '').toString(),
    );
  }
}

class CouponsState {
  const CouponsState({this.loading = false, this.items = const [], this.error});
  final bool loading;
  final List<CouponDto> items;
  final String? error;

  CouponsState copyWith({bool? loading, List<CouponDto>? items, String? error}) {
    return CouponsState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

final couponsControllerProvider =
    StateNotifierProvider<CouponsController, CouponsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return CouponsController(api)..load();
});

class CouponsController extends StateNotifier<CouponsState> {
  CouponsController(this.api) : super(const CouponsState());
  final SellerApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchCoupons();
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
      final items = list
          .whereType<Map>()
          .map((e) => CouponDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();
      state = state.copyWith(loading: false, items: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createCartBase({
    required String code,
    required double discount,
    required String discountType,
    required double minBuy,
    required double maxDiscount,
    required DateTimeRange dateRange,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final range = '${_ymd(dateRange.start)} - ${_ymd(dateRange.end)}';
      await api.createCoupon({
        'type': 'cart_base',
        'code': code,
        'discount': discount,
        'discount_type': discountType,
        'min_buy': minBuy,
        'max_discount': maxDiscount,
        'date_range': range,
      });
      await load();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> delete(int couponId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await api.deleteCoupon(couponId);
      await load();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(couponsControllerProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Coupons', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(couponsControllerProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Coupon'),
        backgroundColor: DesignTokens.brandAccent,
      ),
      body: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(couponsControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: DesignTokens.paddingScreen,
                itemCount: state.items.length + (state.items.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (state.items.isEmpty) {
                    return _EmptyCouponsState(error: state.error);
                  }
                  final coupon = state.items[index];
                  final label = coupon.discountType == 'percent'
                      ? '${coupon.discount.toStringAsFixed(0)}% off'
                      : 'UGX ${coupon.discount.toStringAsFixed(0)} off';
                  return _CouponCard(
                    coupon: coupon,
                    label: label,
                    onTap: () => _showDetails(context, ref, coupon),
                  );
                },
              ),
            ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref, CouponDto coupon) {
    final label = coupon.discountType == 'percent'
        ? '${coupon.discount.toStringAsFixed(0)}% off'
        : 'UGX ${coupon.discount.toStringAsFixed(0)} off';
    BottomSheetModal.show(
      context: context,
      title: coupon.code,
      subtitle: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Text('Type: ${coupon.type}', style: DesignTokens.textSmallBold),
                const SizedBox(height: DesignTokens.spaceXs),
                Text('Valid: ${coupon.startDateLabel} → ${coupon.endDateLabel}', style: DesignTokens.textSmall),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(couponsControllerProvider.notifier).delete(coupon.id);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DesignTokens.error,
              side: const BorderSide(color: DesignTokens.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final minBuyCtrl = TextEditingController(text: '0');
    final maxDiscountCtrl = TextEditingController(text: '0');
    String discountType = 'percent';
    DateTimeRange? range;

    await BottomSheetModal.show<void>(
      context: context,
      title: 'Create Coupon',
      subtitle: 'Cart discount (cart_base)',
      child: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Discount',
                        prefixIcon: Icon(Icons.percent),
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: discountType,
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('Percent')),
                        DropdownMenuItem(value: 'amount', child: Text('Amount')),
                      ],
                      onChanged: (v) => setState(() => discountType = v ?? discountType),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minBuyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Min buy (UGX)',
                        prefixIcon: Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: TextField(
                      controller: maxDiscountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Max discount (UGX)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => range = picked);
                },
                icon: const Icon(Icons.date_range),
                label: Text(range == null ? 'Pick date range' : '${_ymd(range!.start)} → ${_ymd(range!.end)}'),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: () async {
                  final code = codeCtrl.text.trim().toUpperCase();
                  final discount = double.tryParse(discountCtrl.text.trim()) ?? 0;
                  final minBuy = double.tryParse(minBuyCtrl.text.trim()) ?? 0;
                  final maxDiscount = double.tryParse(maxDiscountCtrl.text.trim()) ?? 0;
                  if (code.isEmpty || discount <= 0 || range == null) return;
                  await ref.read(couponsControllerProvider.notifier).createCartBase(
                        code: code,
                        discount: discount,
                        discountType: discountType,
                        minBuy: minBuy,
                        maxDiscount: maxDiscount,
                        dateRange: range!,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.label, required this.onTap});
  final CouponDto coupon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
          border: Border.all(color: DesignTokens.grayLight.withOpacity(0.8)),
        ),
        child: Row(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: DesignTokens.brandAccent.withOpacity(0.12),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: const Icon(Icons.confirmation_number_outlined, color: DesignTokens.brandAccent),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.code, style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(label, style: DesignTokens.textSmall),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    '${coupon.startDateLabel} → ${coupon.endDateLabel}',
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
          ],
        ),
      ),
    );
  }
}

class _EmptyCouponsState extends StatelessWidget {
  const _EmptyCouponsState({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.confirmation_number_outlined, size: 48, color: DesignTokens.grayMedium),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('No coupons yet', style: DesignTokens.textBodyBold),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text(error!, style: DesignTokens.textSmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

String _ymd(DateTime dt) {
  final d = dt.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

