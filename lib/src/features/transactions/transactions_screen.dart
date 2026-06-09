import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../invoices/invoice_providers.dart';
import '../orders/marketplace_order.dart';
import '../orders/order_details_screen.dart';
import '../receipts/receipt_providers.dart';
import '../receipts/receipt_details_sheet.dart';
import '../orders/orders_controller.dart';
import '../refunds/pos_refund_screen.dart';

/// Date filter options for transactions
enum DateFilter { today, week, month, all, custom }

/// Source filter for which transactions to show
enum TransactionSource { pos, online, all }

/// Provider for POS ledger entries with date filtering
final filteredLedgerProvider =
    StreamProvider.family<List<LedgerEntry>, DateFilter>((ref, filter) {
      final db = ref.watch(appDatabaseProvider);
      final now = DateTime.now();
      DateTime? since;

      switch (filter) {
        case DateFilter.today:
          since = DateTime(now.year, now.month, now.day);
          break;
        case DateFilter.week:
          since = now.subtract(const Duration(days: 7));
          break;
        case DateFilter.month:
          since = DateTime(now.year, now.month, 1);
          break;
        case DateFilter.all:
        case DateFilter.custom:
          since = null;
          break;
      }

      return db.watchLedgerEntriesSince(since);
    });

/// State for the transactions screen
class TransactionsScreenState {
  const TransactionsScreenState({
    this.dateFilter = DateFilter.today,
    this.source = TransactionSource.all,
    this.customStart,
    this.customEnd,
    this.onlineQuery = '',
    this.onlineDeliveryStatus = '',
    this.onlinePaymentStatus = '',
    this.loading = false,
    this.syncing = false,
  });

  final DateFilter dateFilter;
  final TransactionSource source;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String onlineQuery;
  final String onlineDeliveryStatus;
  final String onlinePaymentStatus;
  final bool loading;
  final bool syncing;

  TransactionsScreenState copyWith({
    DateFilter? dateFilter,
    TransactionSource? source,
    DateTime? customStart,
    DateTime? customEnd,
    String? onlineQuery,
    String? onlineDeliveryStatus,
    String? onlinePaymentStatus,
    bool? loading,
    bool? syncing,
  }) => TransactionsScreenState(
    dateFilter: dateFilter ?? this.dateFilter,
    source: source ?? this.source,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    onlineQuery: onlineQuery ?? this.onlineQuery,
    onlineDeliveryStatus: onlineDeliveryStatus ?? this.onlineDeliveryStatus,
    onlinePaymentStatus: onlinePaymentStatus ?? this.onlinePaymentStatus,
    loading: loading ?? this.loading,
    syncing: syncing ?? this.syncing,
  );
}

final transactionsScreenProvider =
    StateNotifierProvider<
      TransactionsScreenController,
      TransactionsScreenState
    >((ref) {
      return TransactionsScreenController(ref);
    });

class TransactionsScreenController
    extends StateNotifier<TransactionsScreenState> {
  TransactionsScreenController(this.ref)
    : super(const TransactionsScreenState());
  final Ref ref;

  void setDateFilter(DateFilter filter) {
    state = state.copyWith(dateFilter: filter);
  }

  void setSource(TransactionSource source) {
    state = state.copyWith(source: source);
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      dateFilter: DateFilter.custom,
      customStart: start,
      customEnd: end,
    );
  }

  void setOnlineQuery(String value) {
    state = state.copyWith(onlineQuery: value);
  }

  void setOnlineDeliveryStatus(String? value) {
    state = state.copyWith(onlineDeliveryStatus: value ?? '');
  }

  void setOnlinePaymentStatus(String? value) {
    state = state.copyWith(onlinePaymentStatus: value ?? '');
  }

  Future<void> syncAll() async {
    state = state.copyWith(syncing: true);
    try {
      // Sync POS transactions
      await ref.read(syncServiceProvider).syncNow();
      // Refresh online orders
      await ref.read(ordersControllerProvider.notifier).load();
    } finally {
      state = state.copyWith(syncing: false);
    }
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load online orders on init
    Future.microtask(() => ref.read(ordersControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(transactionsScreenProvider);
    final screenController = ref.read(transactionsScreenProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Transactions', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_return_outlined),
            tooltip: 'Process POS refund',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PosRefundScreen()),
              );
            },
          ),
          if (screenState.syncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync all transactions',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing transactions…')),
                );
                await screenController.syncAll();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Sync complete'),
                    backgroundColor: DesignTokens.brandAccent,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              // Date filter chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceMd,
                  ),
                  children: DateFilter.values
                      .where(
                        (f) =>
                            f != DateFilter.custom ||
                            screenState.dateFilter == DateFilter.custom,
                      )
                      .map((filter) {
                        final isSelected = screenState.dateFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: DesignTokens.spaceXs,
                          ),
                          child: FilterChip(
                            label: Text(_dateFilterLabel(filter, screenState)),
                            selected: isSelected,
                            onSelected: (_) {
                              if (filter == DateFilter.custom) {
                                _pickCustomRange(context, screenController);
                              } else {
                                screenController.setDateFilter(filter);
                              }
                            },
                            selectedColor: DesignTokens.brandAccent.withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: DesignTokens.brandAccent,
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    text: 'POS Sales',
                    icon: Icon(Icons.point_of_sale, size: 18),
                  ),
                  Tab(
                    text: 'Online Orders',
                    icon: Icon(Icons.shopping_bag_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _POSTransactionsList(
            dateFilter: screenState.dateFilter,
            customStart: screenState.customStart,
            customEnd: screenState.customEnd,
          ),
          _OnlineOrdersList(
            dateFilter: screenState.dateFilter,
            customStart: screenState.customStart,
            customEnd: screenState.customEnd,
          ),
        ],
      ),
    );
  }

  String _dateFilterLabel(DateFilter filter, TransactionsScreenState state) {
    switch (filter) {
      case DateFilter.today:
        return 'Today';
      case DateFilter.week:
        return 'This Week';
      case DateFilter.month:
        return 'This Month';
      case DateFilter.all:
        return 'All Time';
      case DateFilter.custom:
        if (state.customStart != null && state.customEnd != null) {
          final fmt = DateFormat('MMM d');
          return '${fmt.format(state.customStart!)} - ${fmt.format(state.customEnd!)}';
        }
        return 'Custom';
    }
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    TransactionsScreenController controller,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );
    if (range != null) {
      controller.setCustomRange(range.start, range.end);
    }
  }

  void _showFilterSheet(BuildContext context) {
    final controller = ref.read(transactionsScreenProvider.notifier);
    final state = ref.read(transactionsScreenProvider);

    BottomSheetModal.show(
      context: context,
      title: 'Filter Transactions',
      subtitle: 'Choose time period',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...DateFilter.values.map(
            (filter) => RadioListTile<DateFilter>(
              title: Text(_dateFilterLabel(filter, state)),
              value: filter,
              groupValue: state.dateFilter,
              onChanged: (v) {
                if (v == null) return;
                if (v == DateFilter.custom) {
                  Navigator.pop(context);
                  _pickCustomRange(context, controller);
                  return;
                }
                controller.setDateFilter(v);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
        ],
      ),
    );
  }
}

/// POS Transactions List (from local ledger)
class _POSTransactionsList extends ConsumerWidget {
  const _POSTransactionsList({
    required this.dateFilter,
    this.customStart,
    this.customEnd,
  });

  final DateFilter dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(filteredLedgerProvider(dateFilter));

    return entriesAsync.when(
      data: (allEntries) {
        // Apply custom date filter if needed
        var entries = allEntries;
        if (dateFilter == DateFilter.custom &&
            customStart != null &&
            customEnd != null) {
          entries = allEntries.where((e) {
            return !e.createdAt.isBefore(customStart!) &&
                e.createdAt.isBefore(customEnd!.add(const Duration(days: 1)));
          }).toList();
        }

        if (entries.isEmpty) {
          return _EmptyState(
            icon: Icons.point_of_sale_outlined,
            title: 'No POS transactions',
            subtitle: 'Make a sale from the Checkout tab',
          );
        }

        // Group by date
        final grouped = _groupByDate(entries);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceSm,
          ),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final group = grouped[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        group.label,
                        style: DesignTokens.textSmallBold.copyWith(
                          color: DesignTokens.grayMedium,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${group.entries.length} txn • ${group.total.toUgx()}',
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.grayMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                ...group.entries.map(
                  (entry) => _POSTransactionTile(entry: entry),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  List<_DateGroup<LedgerEntry>> _groupByDate(List<LedgerEntry> entries) {
    final groups = <String, List<LedgerEntry>>{};
    for (final entry in entries) {
      final key = DateFormat('yyyy-MM-dd').format(entry.createdAt.toLocal());
      groups.putIfAbsent(key, () => []).add(entry);
    }

    return groups.entries.map((e) {
      final date = DateTime.parse(e.key);
      final label = _formatDateLabel(date);
      final total = e.value.fold<double>(
        0,
        (sum, entry) =>
            sum +
            ((entry.type == 'refund' || entry.type == 'void')
                ? -entry.total
                : entry.total),
      );
      return _DateGroup(label: label, entries: e.value, total: total);
    }).toList();
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }
}

class _DateGroup<T> {
  const _DateGroup({
    required this.label,
    required this.entries,
    required this.total,
  });
  final String label;
  final List<T> entries;
  final double total;
}

/// Single POS transaction tile
class _POSTransactionTile extends ConsumerWidget {
  const _POSTransactionTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefund = entry.type == 'refund';
    final isVoid = entry.type == 'void';
    final isReversal = isRefund || isVoid;
    final icon = isRefund
        ? Icons.assignment_return_outlined
        : isVoid
        ? Icons.block_outlined
        : Icons.point_of_sale;
    final tone = isReversal ? DesignTokens.error : DesignTokens.brandAccent;
    final sign = isReversal ? '-' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        leading: Container(
          padding: DesignTokens.paddingSm,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          child: Icon(icon, color: tone),
        ),
        title: Text(
          '$sign${entry.total.toUgx()}',
          style: DesignTokens.textBodyBold.copyWith(
            color: isReversal ? DesignTokens.error : DesignTokens.grayDark,
          ),
        ),
        subtitle: Text(
          '${entry.type.toUpperCase()} • ${entry.createdAt.toRelativeLabel()}',
          style: DesignTokens.textSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print, size: 20),
              tooltip: 'Print',
              onPressed: () => _printReceipt(context, ref, entry.id),
            ),
            entry.synced
                ? const Icon(Icons.cloud_done, color: Colors.green, size: 18)
                : const Icon(
                    Icons.cloud_upload,
                    color: Colors.orange,
                    size: 18,
                  ),
          ],
        ),
        onTap: () => _showEntryDetails(context, ref, entry.id),
      ),
    );
  }

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final printer = ref.read(printQueueServiceProvider);
    if (!printer.printerEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printing is disabled in Settings')),
      );
      return;
    }
    if (!printer.hasPreferredPrinter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a printer in Settings')),
      );
      return;
    }
    await printer.enqueueReceipt(entryId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt queued for printing')),
    );
  }

  void _showEntryDetails(BuildContext context, WidgetRef ref, String entryId) {
    BottomSheetModal.show(
      context: context,
      title: 'Receipt',
      subtitle: entryId,
      child: ReceiptDetailsSheet(entryId: entryId),
    );
  }
}

/// Online Orders List (from backend API)
class _OnlineOrdersList extends ConsumerWidget {
  const _OnlineOrdersList({
    required this.dateFilter,
    this.customStart,
    this.customEnd,
  });

  final DateFilter dateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(transactionsScreenProvider);
    final controller = ref.read(transactionsScreenProvider.notifier);
    final state = ref.watch(ordersControllerProvider);

    if (state.loading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.orders.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off,
        title: 'Failed to load orders',
        subtitle: state.error ?? 'Unknown error',
        action: ElevatedButton.icon(
          onPressed: () => ref.read(ordersControllerProvider.notifier).load(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    // Filter orders by date
    var orders = state.orders;
    if (dateFilter != DateFilter.all) {
      orders = orders.where((order) {
        final date = order.orderedAt;
        if (date == null) return true;

        final now = DateTime.now();
        switch (dateFilter) {
          case DateFilter.today:
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          case DateFilter.week:
            return date.isAfter(now.subtract(const Duration(days: 7)));
          case DateFilter.month:
            return date.year == now.year && date.month == now.month;
          case DateFilter.custom:
            if (customStart != null && customEnd != null) {
              return !date.isBefore(customStart!) &&
                  date.isBefore(customEnd!.add(const Duration(days: 1)));
            }
            return true;
          case DateFilter.all:
            return true;
        }
      }).toList();
    }

    final query = screenState.onlineQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      orders = orders.where((order) {
        final haystack = [
          order.displayCode,
          order.displayCustomer,
          order.displayPaymentMethod,
          order.customerPhone ?? '',
          order.shippingAddress?['phone']?.toString() ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    }

    if (screenState.onlineDeliveryStatus.isNotEmpty) {
      orders = orders.where((order) {
        return order.normalizedDeliveryStatus ==
            screenState.onlineDeliveryStatus;
      }).toList();
    }

    if (screenState.onlinePaymentStatus.isNotEmpty) {
      orders = orders.where((order) {
        return order.normalizedPaymentStatus == screenState.onlinePaymentStatus;
      }).toList();
    }

    if (orders.isEmpty) {
      return Column(
        children: [
          _OnlineOrdersFilterPanel(
            state: screenState,
            onQueryChanged: controller.setOnlineQuery,
            onDeliveryChanged: controller.setOnlineDeliveryStatus,
            onPaymentChanged: controller.setOnlinePaymentStatus,
          ),
          const Expanded(
            child: _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No online orders',
              subtitle: 'Orders from your marketplace will appear here',
            ),
          ),
        ],
      );
    }

    // Calculate summary
    final totalRevenue = orders.fold<double>(
      0,
      (sum, order) => sum + order.displayTotal,
    );
    final paidCount = orders
        .where((order) => order.normalizedPaymentStatus == 'paid')
        .length;
    final attentionCount = orders.where((order) {
      return order.normalizedDeliveryStatus == 'pending' ||
          order.normalizedPaymentStatus != 'paid';
    }).length;

    return Column(
      children: [
        _OnlineOrdersFilterPanel(
          state: screenState,
          onQueryChanged: controller.setOnlineQuery,
          onDeliveryChanged: controller.setOnlineDeliveryStatus,
          onPaymentChanged: controller.setOnlinePaymentStatus,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spaceMd,
            0,
            DesignTokens.spaceMd,
            DesignTokens.spaceMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: _InsightCard(
                  label: 'Orders',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: _InsightCard(
                  label: 'Paid',
                  value: '$paidCount',
                  icon: Icons.verified_outlined,
                  tone: DesignTokens.success,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: _InsightCard(
                  label: 'Revenue',
                  value: totalRevenue.toUgx(),
                  icon: Icons.account_balance_wallet_outlined,
                  tone: DesignTokens.info,
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: _InsightCard(
                  label: 'Attention',
                  value: '$attentionCount',
                  icon: Icons.priority_high_outlined,
                  tone: DesignTokens.warning,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(ordersControllerProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spaceMd,
                0,
                DesignTokens.spaceMd,
                DesignTokens.spaceLg,
              ),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OnlineOrderTile(order: order);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = DesignTokens.brandPrimary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(value, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(label, style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

class _OnlineOrdersFilterPanel extends StatelessWidget {
  const _OnlineOrdersFilterPanel({
    required this.state,
    required this.onQueryChanged,
    required this.onDeliveryChanged,
    required this.onPaymentChanged,
  });

  final TransactionsScreenState state;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onDeliveryChanged;
  final ValueChanged<String?> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
        DesignTokens.spaceMd,
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusLg,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: state.onlineQuery,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search by order code, customer, phone, or payment',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  borderSide: const BorderSide(color: DesignTokens.grayMedium),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  borderSide: const BorderSide(color: DesignTokens.grayLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  borderSide: const BorderSide(
                    color: DesignTokens.brandPrimary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('Delivery status', style: DesignTokens.textSmallBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: const [
                ('', 'All'),
                ('pending', 'Pending'),
                ('confirmed', 'Confirmed'),
                ('on_the_way', 'On the way'),
                ('delivered', 'Delivered'),
                ('cancelled', 'Cancelled'),
              ].map((entry) {
                final value = entry.$1;
                final label = entry.$2;
                return _InlineFilterChip(
                  label: label,
                  selected: state.onlineDeliveryStatus == value,
                  onTap: () => onDeliveryChanged(value),
                );
              }).toList(),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('Payment status', style: DesignTokens.textSmallBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: const [
                ('', 'All'),
                ('paid', 'Paid'),
                ('unpaid', 'Unpaid'),
              ].map((entry) {
                final value = entry.$1;
                final label = entry.$2;
                return _InlineFilterChip(
                  label: label,
                  selected: state.onlinePaymentStatus == value,
                  onTap: () => onPaymentChanged(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineFilterChip extends StatelessWidget {
  const _InlineFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected ? DesignTokens.brandPrimary : DesignTokens.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? DesignTokens.brandPrimary
                : DesignTokens.grayLight,
          ),
        ),
        child: Text(
          label,
          style: DesignTokens.textSmall.copyWith(
            color: selected ? Colors.white : DesignTokens.grayDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Single online order tile
class _OnlineOrderTile extends ConsumerWidget {
  const _OnlineOrderTile({required this.order});
  final MarketplaceOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = order.displayCode;
    final customer = order.displayCustomer;
    final status = order.normalizedDeliveryStatus;
    final paymentStatus = order.normalizedPaymentStatus;
    final total = order.displayTotal;
    final itemCount = order.lineItemCount;
    final orderedAt = order.orderedAt;
    final paymentMethod = order.displayPaymentMethod;
    final hasPendingSync = order.pendingSync;

    final statusColor = _getStatusColor(status);
    final paymentColor = paymentStatus == 'paid'
        ? DesignTokens.success
        : DesignTokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: InkWell(
        borderRadius: DesignTokens.borderRadiusLg,
        onTap: () => _openOrderDetails(context, order),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: DesignTokens.paddingSm,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(id, style: DesignTokens.textBodyBold),
                            ),
                            Text(
                              total.toUgx(),
                              style: DesignTokens.textBodyBold,
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceXs),
                        Text(
                          customer,
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.grayDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DesignTokens.spaceXs),
                        Text(
                          orderedAt == null
                              ? 'Date unavailable'
                              : DateFormat(
                                  'MMM d, y • HH:mm',
                                ).format(orderedAt.toLocal()),
                          style: DesignTokens.textSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceSm,
                children: [
                  _OrderMetaChip(
                    label: _humanizeStatus(status),
                    color: statusColor,
                  ),
                  _OrderMetaChip(
                    label: paymentStatus.toUpperCase(),
                    color: paymentColor,
                  ),
                  _OrderMetaChip(
                    label: '$itemCount item${itemCount == 1 ? '' : 's'}',
                    color: DesignTokens.info,
                  ),
                  if (paymentMethod.isNotEmpty)
                    _OrderMetaChip(
                      label: paymentMethod,
                      color: DesignTokens.grayMedium,
                    ),
                  if (hasPendingSync)
                    const _OrderMetaChip(
                      label: 'Pending sync',
                      color: DesignTokens.warning,
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Container(
                padding: const EdgeInsets.all(DesignTokens.spaceMd),
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoPair(
                        label: 'Customer phone',
                        value: order.displayPhone,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMd),
                    Expanded(
                      child: _InfoPair(
                        label: 'Order source',
                        value: order.displaySource,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: _OrderActionButton(
                      label: 'Details',
                      icon: Icons.visibility_outlined,
                      onPressed: () => _openOrderDetails(context, order),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: _OrderActionButton(
                      label: 'Invoice',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: () async {
                        try {
                          await ref
                              .read(invoiceServiceProvider)
                              .shareOrderInvoicePdf(order.toJson());
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invoice export failed: $e')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: _OrderActionButton(
                      label: 'Status',
                      icon: Icons.edit_outlined,
                      filled: true,
                      onPressed: () => _updateOrderStatus(context, ref, order),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return DesignTokens.success;
      case 'processing':
      case 'shipped':
      case 'confirmed':
      case 'picked_up':
      case 'on_the_way':
        return DesignTokens.info;
      case 'cancelled':
        return DesignTokens.error;
      default:
        return DesignTokens.warning;
    }
  }

  void _openOrderDetails(BuildContext context, MarketplaceOrder order) {
    if (order.id == 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          orderId: order.id,
          initialData: order,
        ),
      ),
    );
  }

  void _updateOrderStatus(
    BuildContext context,
    WidgetRef ref,
    MarketplaceOrder order,
  ) {
    final statuses = [
      'pending',
      'confirmed',
      'picked_up',
      'on_the_way',
      'delivered',
      'cancelled',
    ];
    String delivery = order.normalizedDeliveryStatus;
    String payment = order.normalizedPaymentStatus;
    final orderId = order.id;

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: DesignTokens.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Order #$orderId', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceMd),
            DropdownButtonFormField<String>(
              initialValue: statuses.contains(delivery)
                  ? delivery
                  : statuses.first,
              items: statuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.toUpperCase().replaceAll('_', ' ')),
                    ),
                  )
                  .toList(),
              onChanged: (v) => delivery = v ?? delivery,
              decoration: const InputDecoration(labelText: 'Delivery Status'),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            DropdownButtonFormField<String>(
              initialValue: payment,
              items: const [
                DropdownMenuItem(value: 'paid', child: Text('PAID')),
                DropdownMenuItem(value: 'unpaid', child: Text('UNPAID')),
              ],
              onChanged: (v) => payment = v ?? payment,
              decoration: const InputDecoration(labelText: 'Payment Status'),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (orderId == 0) return;
                  await ref
                      .read(ordersControllerProvider.notifier)
                      .updateStatus(
                        orderId: orderId,
                        delivery: delivery,
                        payment: payment,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
      ),
    );
  }
}

class _OrderActionButton extends StatelessWidget {
  const _OrderActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: DesignTokens.spaceXs),
        Flexible(child: Text(label)),
      ],
    );
    if (filled) {
      return ElevatedButton(onPressed: onPressed, child: child);
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _OrderMetaChip extends StatelessWidget {
  const _OrderMetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: DesignTokens.textSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignTokens.textSmall),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          value,
          style: DesignTokens.textSmallBold.copyWith(
            color: DesignTokens.grayDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingMd,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: DesignTokens.grayMedium),
            const SizedBox(height: DesignTokens.spaceMd),
            Text(title, style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              subtitle,
              style: DesignTokens.textSmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: DesignTokens.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

String _humanizeStatus(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
