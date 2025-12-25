import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
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
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _searching = true);
    try {
      final db = ref.read(appDatabaseProvider);
      // Search by idempotency key (receipt number) or date
      final results = await (db.select(db.ledgerEntries)
        ..where((t) => t.type.equals('sale'))
        ..where((t) => t.idempotencyKey.like('%$query%'))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(20))
        .get();
      
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
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final uuid = const Uuid();
      
      final refundId = uuid.v4();
      final idempotencyKey = 'REF-${DateTime.now().millisecondsSinceEpoch}';
      
      // Build refund lines
      final refundLines = <Map<String, dynamic>>[];
      for (final line in _saleLines) {
        final qty = _refundQuantities[line.id] ?? 0;
        if (qty > 0) {
          refundLines.add({
            'title': line.title,
            'item_id': line.itemId,
            'service_id': line.serviceId,
            'quantity': -qty, // Negative for refund
            'unit_price': line.unitPrice,
            'line_total': -(line.unitPrice * qty),
          });
        }
      }
      
      // Create refund ledger entry (negative amounts)
      await db.into(db.ledgerEntries).insert(
        LedgerEntriesCompanion.insert(
          id: drift.Value(refundId),
          idempotencyKey: idempotencyKey,
          type: 'refund',
          originalEntryId: drift.Value(_selectedSale!.id),
          outletId: drift.Value(_selectedSale!.outletId),
          staffId: drift.Value(_selectedSale!.staffId),
          customerId: drift.Value(_selectedSale!.customerId),
          total: drift.Value(-_refundTotal),
          note: drift.Value(_noteCtrl.text.isNotEmpty 
              ? 'Refund: ${_noteCtrl.text}' 
              : 'Refund for ${_selectedSale!.idempotencyKey}'),
        ),
      );
      
      // Insert refund lines
      for (final lineData in refundLines) {
        await db.into(db.ledgerLines).insert(
          LedgerLinesCompanion.insert(
            entryId: refundId,
            title: lineData['title'] as String,
            itemId: drift.Value(lineData['item_id'] as String?),
            serviceId: drift.Value(lineData['service_id'] as String?),
            quantity: lineData['quantity'] as int,
            unitPrice: lineData['unit_price'] as double,
            lineTotal: lineData['line_total'] as double,
          ),
        );
      }
      
      // Restore stock for refunded items
      for (final line in _saleLines) {
        final qty = _refundQuantities[line.id] ?? 0;
        if (qty > 0 && line.itemId != null) {
          await db.restoreStock(line.itemId!, qty);
        }
      }
      
      // Queue sync
      await sync.enqueue('ledger_push', {
        'entry_id': refundId,
        'idempotency_key': idempotencyKey,
        'type': 'refund',
        'original_entry_id': _selectedSale!.id,
        'total': -_refundTotal,
        'lines': refundLines,
        'note': _noteCtrl.text,
      });
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
            label: 'Receipt number',
            prefixIcon: Icons.search,
            onChanged: (v) => _searchReceipts(v),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
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
                      'Refunding: ${_selectedSale!.idempotencyKey}',
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
                  loading: _loading,
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
        title: Text(sale.idempotencyKey),
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
