import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/error_page.dart';
import 'quotation_creator.dart';

/// Quotation DTO for list display
class QuotationSummary {
  QuotationSummary({
    required this.id,
    required this.quotationNumber,
    required this.total,
    required this.validityDays,
    this.customerName,
    this.createdAt,
    this.notes,
  });

  final String id;
  final String quotationNumber;
  final double total;
  final int validityDays;
  final String? customerName;
  final DateTime? createdAt;
  final String? notes;

  factory QuotationSummary.fromJson(Map<String, dynamic> json) {
    return QuotationSummary(
      id: json['id']?.toString() ?? '',
      quotationNumber: json['quotation_number']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 30,
      customerName: json['customer']?['name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      notes: json['notes']?.toString(),
    );
  }

  bool get isExpired {
    if (createdAt == null) return false;
    final expiryDate = createdAt!.add(Duration(days: validityDays));
    return DateTime.now().isAfter(expiryDate);
  }
}

/// State for quotations list
class QuotationsState {
  const QuotationsState({
    this.loading = false,
    this.quotations = const [],
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
  });

  final bool loading;
  final List<QuotationSummary> quotations;
  final String? error;
  final int currentPage;
  final bool hasMore;

  QuotationsState copyWith({
    bool? loading,
    List<QuotationSummary>? quotations,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) =>
      QuotationsState(
        loading: loading ?? this.loading,
        quotations: quotations ?? this.quotations,
        error: error,
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
      );
}

final quotationsControllerProvider =
    StateNotifierProvider<QuotationsController, QuotationsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return QuotationsController(api)..load();
});

class QuotationsController extends StateNotifier<QuotationsState> {
  QuotationsController(this._api) : super(const QuotationsState());

  final SellerApi _api;

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      state = const QuotationsState(loading: true);
    } else {
      state = state.copyWith(loading: true, error: null);
    }

    try {
      final res = await _api.fetchQuotations(page: 1);
      final data = res.data;
      final List<dynamic> list = (data is Map && data['data'] != null)
          ? (data['data'] is Map && data['data']['data'] != null)
              ? data['data']['data'] as List
              : data['data'] as List
          : [];
      final quotations = list
          .map((e) => QuotationSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = (data['data']?['next_page_url'] ?? data['next_page_url']) != null;
      state = state.copyWith(
        loading: false,
        quotations: quotations,
        currentPage: 1,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);

    try {
      final nextPage = state.currentPage + 1;
      final res = await _api.fetchQuotations(page: nextPage);
      final data = res.data;
      final List<dynamic> list = (data is Map && data['data'] != null)
          ? (data['data'] is Map && data['data']['data'] != null)
              ? data['data']['data'] as List
              : data['data'] as List
          : [];
      final newQuotations = list
          .map((e) => QuotationSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = (data['data']?['next_page_url'] ?? data['next_page_url']) != null;
      state = state.copyWith(
        loading: false,
        quotations: [...state.quotations, ...newQuotations],
        currentPage: nextPage,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotationsControllerProvider);
    final controller = ref.read(quotationsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createQuotation(context),
          ),
        ],
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    QuotationsState state,
    QuotationsController controller,
  ) {
    if (state.loading && state.quotations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.quotations.isEmpty) {
      return ErrorPage(
        title: 'Failed to Load Quotations',
        message: state.error,
        onRetry: () => controller.load(refresh: true),
      );
    }

    if (state.quotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: DesignTokens.grayMedium),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No quotations yet', style: DesignTokens.textBody),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Create a quotation to send to your customers',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Quotation'),
              onPressed: () => _createQuotation(context),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.load(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: DesignTokens.paddingScreen,
          itemCount: state.quotations.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.quotations.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final quotation = state.quotations[index];
            return _QuotationCard(quotation: quotation);
          },
        ),
      ),
    );
  }

  void _createQuotation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuotationCreator()),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({required this.quotation});

  final QuotationSummary quotation;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${quotation.quotationNumber}',
                  style: DesignTokens.textBodyBold,
                ),
                _StatusBadge(isExpired: quotation.isExpired),
              ],
            ),
            if (quotation.customerName != null) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: DesignTokens.grayMedium),
                  const SizedBox(width: 4),
                  Text(
                    quotation.customerName!,
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DesignTokens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quotation.total.toUgx(),
                  style: DesignTokens.textTitle.copyWith(
                    color: DesignTokens.brandPrimary,
                  ),
                ),
                if (quotation.createdAt != null)
                  Text(
                    dateFormat.format(quotation.createdAt!),
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
              ],
            ),
            if (quotation.notes != null && quotation.notes!.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                quotation.notes!,
                style: DesignTokens.textSmall.copyWith(
                  fontStyle: FontStyle.italic,
                  color: DesignTokens.grayMedium,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isExpired});

  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? DesignTokens.error.withOpacity(0.1)
            : DesignTokens.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        isExpired ? 'EXPIRED' : 'VALID',
        style: DesignTokens.textSmall.copyWith(
          color: isExpired ? DesignTokens.error : DesignTokens.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
