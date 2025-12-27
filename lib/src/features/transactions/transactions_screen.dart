import 'dart:async';

import 'package:drift/drift.dart' as drift hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/settings/pos_void_reason_codes.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../invoices/invoice_providers.dart';
import '../receipts/receipt_providers.dart';
import '../orders/orders_controller.dart';
import '../refunds/pos_refund_screen.dart';

/// Date filter options for transactions
enum DateFilter { today, week, month, all, custom }

/// Source filter for which transactions to show
enum TransactionSource { pos, online, all }

/// Provider for POS ledger entries with date filtering
final filteredLedgerProvider = StreamProvider.family<List<LedgerEntry>, DateFilter>((ref, filter) {
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
    this.loading = false,
    this.syncing = false,
  });
  
  final DateFilter dateFilter;
  final TransactionSource source;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool loading;
  final bool syncing;
  
  TransactionsScreenState copyWith({
    DateFilter? dateFilter,
    TransactionSource? source,
    DateTime? customStart,
    DateTime? customEnd,
    bool? loading,
    bool? syncing,
  }) => TransactionsScreenState(
    dateFilter: dateFilter ?? this.dateFilter,
    source: source ?? this.source,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    loading: loading ?? this.loading,
    syncing: syncing ?? this.syncing,
  );
}

final transactionsScreenProvider = StateNotifierProvider<TransactionsScreenController, TransactionsScreenState>((ref) {
  return TransactionsScreenController(ref);
});

class TransactionsScreenController extends StateNotifier<TransactionsScreenState> {
  TransactionsScreenController(this.ref) : super(const TransactionsScreenState());
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

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> with SingleTickerProviderStateMixin {
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                  children: DateFilter.values.where((f) => f != DateFilter.custom || screenState.dateFilter == DateFilter.custom).map((filter) {
                    final isSelected = screenState.dateFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: DesignTokens.spaceXs),
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
                        selectedColor: DesignTokens.brandAccent.withValues(alpha: 0.2),
                        checkmarkColor: DesignTokens.brandAccent,
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'POS Sales', icon: Icon(Icons.point_of_sale, size: 18)),
                  Tab(text: 'Online Orders', icon: Icon(Icons.shopping_bag_outlined, size: 18)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _POSTransactionsList(dateFilter: screenState.dateFilter, customStart: screenState.customStart, customEnd: screenState.customEnd),
          _OnlineOrdersList(dateFilter: screenState.dateFilter, customStart: screenState.customStart, customEnd: screenState.customEnd),
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

  Future<void> _pickCustomRange(BuildContext context, TransactionsScreenController controller) async {
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
      child: RadioGroup<DateFilter>(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...DateFilter.values.map(
              (filter) => RadioListTile<DateFilter>(
                title: Text(_dateFilterLabel(filter, state)),
                value: filter,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
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
        if (dateFilter == DateFilter.custom && customStart != null && customEnd != null) {
          entries = allEntries.where((e) {
            return e.createdAt.isAfter(customStart!) && 
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
                  padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
                  child: Row(
                    children: [
                      Text(
                        group.label,
                        style: DesignTokens.textSmallBold.copyWith(color: DesignTokens.grayMedium),
                      ),
                      const Spacer(),
                      Text(
                        '${group.entries.length} txn • ${group.total.toUgx()}',
                        style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                      ),
                    ],
                  ),
                ),
                ...group.entries.map((entry) => _POSTransactionTile(entry: entry)),
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
      final total = e.value.fold<double>(0, (sum, entry) => 
        sum + ((entry.type == 'refund' || entry.type == 'void') ? -entry.total : entry.total));
      return _DateGroup(label: label, entries: e.value, total: total);
    }).toList();
  }
  
  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }
}

class _DateGroup<T> {
  const _DateGroup({required this.label, required this.entries, required this.total});
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
          child: Icon(
            icon,
            color: tone,
          ),
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
                : const Icon(Icons.cloud_upload, color: Colors.orange, size: 18),
          ],
        ),
        onTap: () => _showEntryDetails(context, ref, entry.id),
      ),
    );
  }
  
  Future<void> _printReceipt(BuildContext context, WidgetRef ref, String entryId) async {
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
      child: FutureBuilder<LedgerEntryBundle?>(
        future: ref.read(appDatabaseProvider).fetchLedgerEntryBundle(entryId),
        builder: (sheetContext, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snapshot.data;
          if (bundle == null) {
            return Center(child: Text('Not found', style: DesignTokens.textBody));
          }
          final entry = bundle.entry;
          final isReversal = entry.type == 'refund' || entry.type == 'void';
          final sign = isReversal ? '-' : '';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight.withValues(alpha: 0.25),
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type: ${entry.type.toUpperCase()}', style: DesignTokens.textSmallBold),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text('Date: ${_formatDateTime(entry.createdAt)}', style: DesignTokens.textSmall),
                    if (entry.originalEntryId != null) ...[
                      const SizedBox(height: DesignTokens.spaceXs),
                      Text(
                        'Ref: ${entry.originalEntryId}',
                        style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      entry.synced ? 'Synced' : 'Pending sync',
                      style: DesignTokens.textSmall.copyWith(
                        color: entry.synced ? DesignTokens.brandAccent : DesignTokens.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              ...bundle.lines.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.title} x${l.quantity}',
                        style: DesignTokens.textBody,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Text(
                      '$sign${l.lineTotal.toUgx()}',
                      style: DesignTokens.textBodyBold,
                    ),
                  ],
                ),
              )),
              const Divider(height: DesignTokens.spaceLg),
              Row(
                children: [
                  Expanded(child: Text('Total', style: DesignTokens.textBodyBold)),
                  Text(
                    '$sign${entry.total.toUgx()}',
                    style: DesignTokens.textBodyBold,
                  ),
                ],
              ),
              if (entry.type == 'sale') ...[
                const SizedBox(height: DesignTokens.spaceMd),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.error,
                    side: const BorderSide(color: DesignTokens.error),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _voidSale(context, ref, bundle);
                  },
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Void sale'),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceLg),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ref.read(receiptServiceProvider).sharePdf(entryId),
                          icon: const Icon(Icons.share),
                          label: const Text('Receipt PDF'),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ref.read(invoiceServiceProvider).sharePosInvoicePdf(entryId),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Invoice PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ref.read(receiptServiceProvider).shareWhatsapp(entryId),
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _printReceipt(context, ref, entryId),
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
  
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }

  Future<void> _voidSale(
    BuildContext context,
    WidgetRef ref,
    LedgerEntryBundle saleBundle,
  ) async {
    final sale = saleBundle.entry;
    if (sale.type != 'sale') return;

    final ok = await requireManagerPin(context, ref, reason: 'void this sale');
    if (!ok || !context.mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final reasons = PosVoidReasonCodesCache.read(prefs);
    if (reasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set up void reason codes in Settings first.')),
      );
      return;
    }

    final reason = await BottomSheetModal.show<String>(
      context: context,
      title: 'Void reason',
      subtitle: 'Select a reason code',
      maxHeight: 520,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: reasons.length,
        itemBuilder: (ctx, i) {
          final code = reasons[i];
          return ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(code),
            onTap: () => Navigator.of(ctx).pop(code),
          );
        },
      ),
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;

    final db = ref.read(appDatabaseProvider);
    final alreadyVoided = await (db.select(db.ledgerEntries)
          ..where((t) => t.type.equals('void') & t.originalEntryId.equals(sale.id))
          ..limit(1))
        .getSingleOrNull();
    if (alreadyVoided != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale is already voided.')),
      );
      return;
    }

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'pos_void_started',
          props: {
            'sale_entry_id': sale.id,
            'sale_total': sale.total,
            'reason_code': reason,
          },
        ),
      );
    }

    final sync = ref.read(syncServiceProvider);
    final actorStaffId = ref.read(posSessionProvider).staffId?.toString() ?? sale.staffId;
    final voidId = const Uuid().v4();
    final idempotencyKey = 'void_$voidId';
    final occurredAt = DateTime.now().toUtc();
    final receiptNumber = await db.getNextReceiptNumber();
    final outletId = sale.outletId ?? (await db.getPrimaryOutlet())?.id;
    final note = 'Void ($reason) for ${formatPosReceiptNumber(sale.receiptNumber)}';

    final lineRows = <LedgerLinesCompanion>[];
    final apiLines = <Map<String, dynamic>>[];
    for (final line in saleBundle.lines) {
      lineRows.add(
        LedgerLinesCompanion.insert(
          entryId: voidId,
          title: line.title,
          itemId: drift.Value(line.itemId),
          serviceId: drift.Value(line.serviceId),
          variant: drift.Value(line.variant),
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          lineTotal: line.lineTotal,
        ),
      );

      apiLines.add({
        'product_id': line.itemId,
        'service_id': line.serviceId,
        'name': line.title,
        if (line.variant != null && line.variant!.trim().isNotEmpty)
          'variation': line.variant,
        'price': line.unitPrice,
        'quantity': line.quantity,
        'subtotal': line.lineTotal,
      });
    }

    final paymentsSource = saleBundle.payments.isNotEmpty
        ? saleBundle.payments
        : [
            Payment(
              id: 0,
              entryId: sale.id,
              method: 'cash',
              amount: sale.total,
              externalRef: null,
            ),
          ];

    final paymentRows = <PaymentsCompanion>[];
    final apiPayments = <Map<String, dynamic>>[];
    for (final p in paymentsSource) {
      paymentRows.add(
        PaymentsCompanion.insert(
          entryId: voidId,
          method: p.method,
          amount: p.amount,
          externalRef: drift.Value(p.externalRef),
        ),
      );
      apiPayments.add({
        'method': p.method,
        'amount': p.amount,
        if (p.externalRef != null && p.externalRef!.trim().isNotEmpty)
          'external_ref': p.externalRef,
      });
    }

    await db.saveLedgerEntry(
      entry: LedgerEntriesCompanion.insert(
        id: drift.Value(voidId),
        receiptNumber: drift.Value(receiptNumber),
        idempotencyKey: idempotencyKey,
        type: 'void',
        originalEntryId: drift.Value(sale.id),
        outletId: drift.Value(outletId),
        staffId: drift.Value(actorStaffId),
        customerId: drift.Value(sale.customerId),
        subtotal: drift.Value(sale.subtotal),
        discount: drift.Value(sale.discount),
        tax: drift.Value(sale.tax),
        total: drift.Value(sale.total),
        note: drift.Value(note),
        createdAt: drift.Value(occurredAt),
      ),
      lines: lineRows,
      payments: paymentRows,
    );

    for (final line in saleBundle.lines) {
      final itemId = line.itemId;
      if (itemId == null || itemId.trim().isEmpty) continue;
      await db.recordInventoryMovement(
        itemId: itemId,
        delta: line.quantity,
        note: 'void',
        variant: line.variant ?? '',
      );
    }

    await sync.enqueue('ledger_push', {
      'entry_id': voidId,
      'idempotency_key': idempotencyKey,
      'type': 'void',
      'reason_code': reason,
      'original_entry_id': sale.id,
      'subtotal': sale.subtotal,
      'discount': sale.discount,
      'tax': sale.tax,
      'total': sale.total,
      'note': note,
      'occurred_at': occurredAt.toIso8601String(),
      'customer_id': sale.customerId,
      'payments': apiPayments,
      'lines': apiLines,
    });

    await db.recordAuditLog(
      actorStaffId: actorStaffId,
      action: 'void',
      payload: {
        'void_entry_id': voidId,
        'original_entry_id': sale.id,
        'reason_code': reason,
        'amount': sale.total,
        'lines': apiLines,
      },
    );

    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'pos_void_created',
          props: {
            'void_entry_id': voidId,
            'sale_entry_id': sale.id,
            'amount': sale.total,
            'lines_count': apiLines.length,
            'reason_code': reason,
          },
        ),
      );
    }

    unawaited(sync.syncNow());

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sale voided (${sale.total.toUgx()})'),
        backgroundColor: DesignTokens.error,
      ),
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
        final dateStr = order['created_at']?.toString() ?? order['date']?.toString();
        if (dateStr == null) return true;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return true;
        
        final now = DateTime.now();
        switch (dateFilter) {
          case DateFilter.today:
            return date.year == now.year && date.month == now.month && date.day == now.day;
          case DateFilter.week:
            return date.isAfter(now.subtract(const Duration(days: 7)));
          case DateFilter.month:
            return date.year == now.year && date.month == now.month;
          case DateFilter.custom:
            if (customStart != null && customEnd != null) {
              return date.isAfter(customStart!) && date.isBefore(customEnd!.add(const Duration(days: 1)));
            }
            return true;
          case DateFilter.all:
            return true;
        }
      }).toList();
    }
    
    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No online orders',
        subtitle: 'Orders from your marketplace will appear here',
      );
    }
    
    // Calculate summary
    final totalRevenue = orders.fold<double>(0, (sum, order) {
      return sum + (double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0);
    });
    
    return Column(
      children: [
        // Summary bar
        Container(
          width: double.infinity,
          padding: DesignTokens.paddingMd,
          color: DesignTokens.brandPrimary.withValues(alpha: 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(label: 'Orders', value: '${orders.length}'),
              _SummaryItem(label: 'Revenue', value: totalRevenue.toUgx()),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(ordersControllerProvider.notifier).load(),
            child: ListView.builder(
              padding: DesignTokens.paddingScreen,
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

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: DesignTokens.textBodyBold),
        const SizedBox(height: 2),
        Text(label, style: DesignTokens.textSmall),
      ],
    );
  }
}

/// Single online order tile
class _OnlineOrderTile extends ConsumerWidget {
  const _OnlineOrderTile({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = order['code']?.toString() ?? order['id']?.toString() ?? 'N/A';
    final customer = order['customer_name']?.toString() ?? 'Customer';
    final status = order['delivery_status']?.toString() ?? 'pending';
    final paymentStatus = order['payment_status']?.toString() ?? 'unpaid';
    final total = double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0;
    
    final statusColor = _getStatusColor(status);
    final paymentColor = paymentStatus == 'paid' ? DesignTokens.success : DesignTokens.warning;
    
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
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          child: Icon(Icons.shopping_bag_outlined, color: statusColor),
        ),
        title: Row(
          children: [
            Text(id, style: DesignTokens.textBodyBold),
            const SizedBox(width: DesignTokens.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: DesignTokens.textSmall.copyWith(color: statusColor, fontSize: 10),
              ),
            ),
          ],
        ),
        subtitle: Text(
          customer,
          style: DesignTokens.textSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(total.toUgx(), style: DesignTokens.textBodyBold),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: paymentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                paymentStatus.toUpperCase(),
                style: DesignTokens.textSmall.copyWith(color: paymentColor, fontSize: 10),
              ),
            ),
          ],
        ),
        onTap: () => _showOrderDetails(context, ref, order),
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
        return DesignTokens.info;
      case 'cancelled':
        return DesignTokens.error;
      default:
        return DesignTokens.warning;
    }
  }

  void _showOrderDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> order) {
    final orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
    final items = order['items'] as List<dynamic>? ?? [];
    
    BottomSheetModal.show(
      context: context,
      title: 'Order #${order['code'] ?? orderId}',
      subtitle: order['customer_name']?.toString() ?? 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order info
          Container(
            padding: DesignTokens.paddingMd,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight.withValues(alpha: 0.25),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Delivery: ', style: DesignTokens.textSmall),
                    Text(
                      (order['delivery_status'] ?? 'pending').toString().toUpperCase(),
                      style: DesignTokens.textSmallBold,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                Row(
                  children: [
                    Text('Payment: ', style: DesignTokens.textSmall),
                    Text(
                      (order['payment_status'] ?? 'unpaid').toString().toUpperCase(),
                      style: DesignTokens.textSmallBold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          
          // Items list
          if (items.isNotEmpty) ...[
            Text('Items', style: DesignTokens.textSmallBold),
            const SizedBox(height: DesignTokens.spaceSm),
            ...items.map((item) {
              final i = item as Map<String, dynamic>;
              final name = i['name']?.toString() ?? i['product_name']?.toString() ?? 'Item';
              final qty = int.tryParse(i['quantity']?.toString() ?? '1') ?? 1;
              final price = double.tryParse(i['price']?.toString() ?? i['total']?.toString() ?? '0') ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
                child: Row(
                  children: [
                    Expanded(child: Text('$name x$qty', style: DesignTokens.textBody)),
                    Text(price.toUgx(), style: DesignTokens.textBodyBold),
                  ],
                ),
              );
            }),
          ] else
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(ordersControllerProvider.notifier).loadItems(orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final loadedItems = snapshot.data ?? [];
                if (loadedItems.isEmpty) {
                  return Text('No items', style: DesignTokens.textSmall);
                }
                return Column(
                  children: loadedItems.map((i) {
                    final name = i['name']?.toString() ?? i['product_name']?.toString() ?? 'Item';
                    final qty = int.tryParse(i['quantity']?.toString() ?? '1') ?? 1;
                    final unitPrice = i['unit_price'] is num
                        ? (i['unit_price'] as num).toDouble()
                        : double.tryParse(i['unit_price']?.toString() ?? '') ?? 0;
                    final lineTotal = i['total'] is num
                        ? (i['total'] as num).toDouble()
                        : (unitPrice * qty);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
                      child: Row(
                        children: [
                          Expanded(child: Text('$name x$qty', style: DesignTokens.textBody)),
                          Text(lineTotal.toUgx(), style: DesignTokens.textBodyBold),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          
          const Divider(height: DesignTokens.spaceLg),
          Row(
            children: [
              Expanded(child: Text('Total', style: DesignTokens.textBodyBold)),
              Text(
                (double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0).toUgx(),
                style: DesignTokens.textBodyBold,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          
          // Actions
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(invoiceServiceProvider).shareOrderInvoicePdf(order);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invoice export failed: $e')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Invoice PDF'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(context, ref, order);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Update Status'),
          ),
        ],
      ),
    );
  }
  
  void _updateOrderStatus(BuildContext context, WidgetRef ref, Map<String, dynamic> order) {
    final statuses = ['pending', 'confirmed', 'picked_up', 'on_the_way', 'delivered', 'cancelled'];
    String delivery = (order['delivery_status_raw'] ?? order['delivery_status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    String payment = order['payment_status']?.toString() ?? 'unpaid';
    final orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
    
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
              initialValue: statuses.contains(delivery) ? delivery : statuses.first,
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
                  await ref.read(ordersControllerProvider.notifier).updateStatus(
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
