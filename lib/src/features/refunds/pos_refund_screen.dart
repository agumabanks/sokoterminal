import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift hide Column;

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/security/manager_approval.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/error_page.dart';

/// POS Refund screen for processing refunds on previous sales
class PosRefundScreen extends ConsumerStatefulWidget {
  const PosRefundScreen({super.key});

  @override
  ConsumerState<PosRefundScreen> createState() => _PosRefundScreenState();
}

class _PosRefundScreenState extends ConsumerState<PosRefundScreen> {
  final _searchCtrl = TextEditingController();
  LedgerEntry? _selectedSale;
  List<LedgerLine> _saleLines = [];
  bool _loading = false;
  bool _searching = false;
  List<LedgerEntry> _searchResults = [];
  String? _error;
  
  // Refund amounts per line (key: line id)
  final Map<int, int> _refundQuantities = {};
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchReceipts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _error = null;
      });
      return;
    }
    
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      // Search by receipt number (preferred), fallback to idempotency key.
      final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      final q = db.select(db.ledgerEntries)
        ..where((t) => t.type.equals('sale'))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
        ..limit(20);
      if (digits.isNotEmpty) {
        final receiptNo = int.tryParse(digits);
        if (receiptNo != null) {
          q.where((t) => t.receiptNumber.equals(receiptNo));
        } else {
          q.where((t) => t.idempotencyKey.like('%$trimmed%'));
        }
      } else {
        q.where((t) => t.idempotencyKey.like('%$trimmed%'));
      }
      final results = await q.get();
      
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  Future<void> _selectSale(LedgerEntry sale) async {
    setState(() => _loading = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final lines = await (db.select(db.ledgerLines)
        ..where((t) => t.entryId.equals(sale.id)))
        .get();
      
      setState(() {
        _selectedSale = sale;
        _saleLines = lines;
        _refundQuantities.clear();
        // Default: refund all quantities
        for (final line in lines) {
          _refundQuantities[line.id] = line.quantity;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _refundTotal {
    double total = 0;
    for (final line in _saleLines) {
      final qty = _refundQuantities[line.id] ?? 0;
      if (qty > 0) {
        total += line.unitPrice * qty;
      }
    }
    return total;
  }

  Future<void> _processRefund() async {
    if (_selectedSale == null || _refundTotal <= 0) return;
    
    setState(() => _loading = true);
    try {
      final approved = await requireManagerPin(
        context,
        ref,
        reason: 'process a refund',
      );
      if (!approved) {
        setState(() => _loading = false);
        return;
      }

      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final actorStaffId =
          ref.read(posSessionProvider).staffId?.toString() ?? _selectedSale!.staffId;
      
      final refundId = const Uuid().v4();
      final idempotencyKey = 'refund_$refundId';
      final occurredAt = DateTime.now().toUtc();
      
      // Build refund lines (store positive amounts; entry type indicates refund).
      final lineRows = <LedgerLinesCompanion>[];
      final apiLines = <Map<String, dynamic>>[];
      for (final line in _saleLines) {
        final qty = _refundQuantities[line.id] ?? 0;
        if (qty <= 0) continue;

        final lineTotal = line.unitPrice * qty;
        lineRows.add(
          LedgerLinesCompanion.insert(
            entryId: refundId,
            title: line.title,
            itemId: drift.Value(line.itemId),
            serviceId: drift.Value(line.serviceId),
            variant: drift.Value(line.variant),
            quantity: qty,
            unitPrice: line.unitPrice,
            lineTotal: lineTotal,
          ),
        );

        apiLines.add({
          'product_id': line.itemId,
          'service_id': line.serviceId,
          'name': line.title,
          if (line.variant != null && line.variant!.trim().isNotEmpty)
            'variation': line.variant,
          'price': line.unitPrice,
          'quantity': qty,
          'subtotal': lineTotal,
        });
      }
      
      // Get next receipt number for refund
      final receiptNumber = await db.getNextReceiptNumber();
      final outletId =
          _selectedSale!.outletId ?? (await db.getPrimaryOutlet())?.id;

      final refundNote = _noteCtrl.text.trim().isEmpty
          ? 'Refund for ${formatPosReceiptNumber(_selectedSale!.receiptNumber)}'
          : _noteCtrl.text.trim();

      await db.saveLedgerEntry(
        entry: LedgerEntriesCompanion.insert(
          id: drift.Value(refundId),
          receiptNumber: drift.Value(receiptNumber),
          idempotencyKey: idempotencyKey,
          type: 'refund',
          originalEntryId: drift.Value(_selectedSale!.id),
          outletId: drift.Value(outletId),
          staffId: drift.Value(actorStaffId),
          customerId: drift.Value(_selectedSale!.customerId),
          subtotal: drift.Value(_refundTotal),
          discount: const drift.Value(0),
          tax: const drift.Value(0),
          total: drift.Value(_refundTotal),
          note: drift.Value(refundNote),
          createdAt: drift.Value(occurredAt),
        ),
        lines: lineRows,
        payments: [
          PaymentsCompanion.insert(
            entryId: refundId,
            method: 'cash',
            amount: _refundTotal,
          ),
        ],
      );

      // Restore stock for refunded items (best-effort).
      for (final line in _saleLines) {
        final qty = _refundQuantities[line.id] ?? 0;
        if (qty <= 0) continue;
        final itemId = line.itemId;
        if (itemId == null || itemId.isEmpty) continue;
        await db.recordInventoryMovement(
          itemId: itemId,
          delta: qty,
          note: 'refund',
          variant: line.variant ?? '',
        );
      }
      
      // Queue sync
      await sync.enqueue('ledger_push', {
        'entry_id': refundId,
        'idempotency_key': idempotencyKey,
        'type': 'refund',
        'original_entry_id': _selectedSale!.id,
        'subtotal': _refundTotal,
        'discount': 0,
        'tax': 0,
        'total': _refundTotal,
        'note': refundNote,
        'occurred_at': occurredAt.toIso8601String(),
        'customer_id': _selectedSale!.customerId,
        'payments': [
          {'method': 'cash', 'amount': _refundTotal},
        ],
        'lines': apiLines,
      });
      await db.recordAuditLog(
        actorStaffId: actorStaffId,
        action: 'refund',
        payload: {
          'refund_entry_id': refundId,
          'original_entry_id': _selectedSale!.id,
          'refund_receipt_number': receiptNumber,
          'amount': _refundTotal,
          'lines': apiLines,
          if (refundNote.trim().isNotEmpty) 'note': refundNote.trim(),
        },
      );
      unawaited(sync.syncNow());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund of ${NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(_refundTotal)} processed'),
          backgroundColor: DesignTokens.success,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Process Refund'),
      ),
      body: _selectedSale == null 
          ? _buildSearchView() 
          : _buildRefundView(),
    );
  }

  Widget _buildSearchView() {
    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find Original Sale', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          AppInput(
            controller: _searchCtrl,
            label: 'Receipt number (e.g. 000-123)',
            prefixIcon: Icons.search,
            onChanged: (v) => _searchReceipts(v),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
              child: ErrorPage(
                title: 'Refund search failed',
                message: _error,
                onRetry: () => _searchReceipts(_searchCtrl.text),
              ),
            )
          else
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isEmpty && _searchCtrl.text.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: DesignTokens.grayMedium),
                    const SizedBox(height: 12),
                    Text('No sales found', style: DesignTokens.textBody),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (_, i) => _SaleCard(
                  sale: _searchResults[i],
                  onTap: () => _selectSale(_searchResults[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefundView() {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    
    return Column(
      children: [
        // Original sale info
        Container(
          color: DesignTokens.surfaceWhite,
          padding: DesignTokens.paddingScreen,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedSale = null),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refunding: ${formatPosReceiptNumber(_selectedSale!.receiptNumber)}',
                      style: DesignTokens.textBodyBold,
                    ),
                    Text(
                      dateFormat.format(_selectedSale!.createdAt.toLocal()),
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(_selectedSale!.total),
                style: DesignTokens.textBodyBold,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Lines to refund
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: DesignTokens.paddingScreen,
                  itemCount: _saleLines.length,
                  itemBuilder: (_, i) => _RefundLineCard(
                    line: _saleLines[i],
                    refundQty: _refundQuantities[_saleLines[i].id] ?? 0,
                    onQtyChanged: (qty) {
                      setState(() {
                        _refundQuantities[_saleLines[i].id] = qty;
                      });
                    },
                  ),
                ),
        ),
        
        // Refund note
        Container(
          padding: DesignTokens.paddingScreen,
          color: DesignTokens.surfaceWhite,
          child: AppInput(
            controller: _noteCtrl,
            label: 'Reason for refund (optional)',
            maxLines: 2,
          ),
        ),
        
        // Footer
        Container(
          padding: DesignTokens.paddingScreen,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceWhite,
            boxShadow: DesignTokens.shadowSm,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refund Total', style: DesignTokens.textSmall),
                      Text(
                        currencyFormat.format(_refundTotal),
                        style: DesignTokens.textTitle.copyWith(
                          color: DesignTokens.error,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Process Refund',
                  onPressed: _refundTotal > 0 ? _processRefund : null,
                  isLoading: _loading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, this.onTap});
  
  final LedgerEntry sale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt, color: DesignTokens.brandPrimary),
        ),
        title: Text('Receipt ${formatPosReceiptNumber(sale.receiptNumber)}'),
        subtitle: Text(dateFormat.format(sale.createdAt.toLocal())),
        trailing: Text(
          currencyFormat.format(sale.total),
          style: DesignTokens.textBodyBold,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RefundLineCard extends StatelessWidget {
  const _RefundLineCard({
    required this.line,
    required this.refundQty,
    required this.onQtyChanged,
  });
  
  final LedgerLine line;
  final int refundQty;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.title, style: DesignTokens.textBodyBold),
                  Text(
                    '${line.quantity} × ${currencyFormat.format(line.unitPrice)}',
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ],
              ),
            ),
            // Quantity selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: DesignTokens.grayLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: refundQty > 0 
                        ? () => onQtyChanged(refundQty - 1)
                        : null,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$refundQty',
                      textAlign: TextAlign.center,
                      style: DesignTokens.textBodyBold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: refundQty < line.quantity 
                        ? () => onQtyChanged(refundQty + 1)
                        : null,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Text(
                currencyFormat.format(line.unitPrice * refundQty),
                textAlign: TextAlign.end,
                style: DesignTokens.textBodyBold.copyWith(
                  color: refundQty > 0 ? DesignTokens.error : DesignTokens.grayMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
