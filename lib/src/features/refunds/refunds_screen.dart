import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class RefundRequestDto {
  RefundRequestDto({
    required this.id,
    required this.orderCode,
    required this.productName,
    required this.reason,
    required this.refundStatus,
    required this.refundLabel,
    required this.sellerApproval,
    required this.rejectReason,
    required this.dateLabel,
  });

  final int id;
  final String orderCode;
  final String productName;
  final String reason;
  final int refundStatus;
  final String refundLabel;
  final dynamic sellerApproval;
  final String? rejectReason;
  final String dateLabel;

  factory RefundRequestDto.fromJson(Map<String, dynamic> json) {
    return RefundRequestDto(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      orderCode: (json['order_code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      refundStatus: int.tryParse(json['refund_status']?.toString() ?? '') ?? 0,
      refundLabel: (json['refund_label'] ?? '').toString(),
      sellerApproval: json['seller_approval'],
      rejectReason: json['reject_reason']?.toString(),
      dateLabel: (json['date'] ?? '').toString(),
    );
  }
}

class RefundsState {
  const RefundsState({this.loading = false, this.items = const [], this.error});
  final bool loading;
  final List<RefundRequestDto> items;
  final String? error;

  RefundsState copyWith({
    bool? loading,
    List<RefundRequestDto>? items,
    String? error,
  }) {
    return RefundsState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

final refundsControllerProvider =
    StateNotifierProvider<RefundsController, RefundsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return RefundsController(api)..load();
});

class RefundsController extends StateNotifier<RefundsState> {
  RefundsController(this.api) : super(const RefundsState());
  final SellerApi api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.fetchRefundRequests();
      final data = res.data;
      final list = data is Map<String, dynamic> ? (data['data'] as List? ?? const []) : const [];
      final items = list
          .whereType<Map>()
          .map((e) => RefundRequestDto.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id != 0)
          .toList();
      state = state.copyWith(loading: false, items: items);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> approve(int refundId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await api.approveRefundRequest(refundId: refundId);
      await load();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> reject(int refundId, {String? reason}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await api.rejectRefundRequest(refundId: refundId, reason: reason);
      await load();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundsControllerProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Refund Requests', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(refundsControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(refundsControllerProvider.notifier).load(),
              child: ListView.builder(
                padding: DesignTokens.paddingScreen,
                itemCount: state.items.length + (state.items.isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (state.items.isEmpty) {
                    return _EmptyRefundsState(error: state.error);
                  }
                  final refund = state.items[index];
                  final color = _statusColor(refund.refundStatus);
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceWhite,
                      borderRadius: DesignTokens.borderRadiusMd,
                      boxShadow: DesignTokens.shadowSm,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.12),
                        child: Icon(Icons.assignment_return_outlined, color: color),
                      ),
                      title: Text(
                        refund.orderCode.isEmpty ? 'Refund #${refund.id}' : refund.orderCode,
                        style: DesignTokens.textBodyBold,
                      ),
                      subtitle: Text(
                        refund.productName.isEmpty ? refund.reason : '${refund.productName} • ${refund.reason}',
                        style: DesignTokens.textSmall,
                      ),
                      trailing: Chip(
                        label: Text(refund.refundLabel.toUpperCase()),
                        backgroundColor: color.withOpacity(0.12),
                        labelStyle: TextStyle(color: color),
                      ),
                      onTap: () => _showDecision(context, ref, refund),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showDecision(BuildContext context, WidgetRef ref, RefundRequestDto refund) {
    BottomSheetModal.show(
      context: context,
      title: refund.orderCode.isEmpty ? 'Refund #${refund.id}' : refund.orderCode,
      subtitle: refund.dateLabel.isEmpty ? null : refund.dateLabel,
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
                Text(refund.productName.isEmpty ? 'Refund request' : refund.productName,
                    style: DesignTokens.textBodyBold),
                const SizedBox(height: DesignTokens.spaceXs),
                Text(refund.reason, style: DesignTokens.textBody),
                if (refund.rejectReason != null && refund.rejectReason!.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text('Reject reason: ${refund.rejectReason}', style: DesignTokens.textSmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  onPressed: refund.refundStatus == 1
                      ? null
                      : () async {
                          await ref.read(refundsControllerProvider.notifier).approve(refund.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  onPressed: refund.refundStatus == 2
                      ? null
                      : () async {
                          final reason = await _promptRejectReason(context);
                          if (reason == null) return;
                          await ref
                              .read(refundsControllerProvider.notifier)
                              .reject(refund.id, reason: reason);
                          if (context.mounted) Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _promptRejectReason(BuildContext context) async {
    final ctrl = TextEditingController();
    final res = await BottomSheetModal.show<String>(
      context: context,
      title: 'Reject refund',
      subtitle: 'Add a short reason',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.error),
            onPressed: () {
              final text = ctrl.text.trim();
              Navigator.pop(context, text.isEmpty ? null : text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return res;
  }
}

class _EmptyRefundsState extends StatelessWidget {
  const _EmptyRefundsState({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.assignment_return_outlined, size: 48, color: DesignTokens.grayMedium),
          const SizedBox(height: DesignTokens.spaceMd),
          Text('No refund requests', style: DesignTokens.textBodyBold),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            Text(error!, style: DesignTokens.textSmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

Color _statusColor(int status) {
  if (status == 1) return DesignTokens.success;
  if (status == 2) return DesignTokens.error;
  return DesignTokens.warning;
}

