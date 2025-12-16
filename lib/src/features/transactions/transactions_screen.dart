import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/security/manager_approval.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/telemetry/telemetry.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../receipts/receipt_providers.dart';

final ledgerEntriesStreamProvider = StreamProvider<List<LedgerEntry>>((ref) {
  return ref.watch(appDatabaseProvider).watchLedgerEntries();
});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});
  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ledgerEntriesStreamProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Ledger', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync started…')));
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sync finished'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
          ),
        ],
      ),
      body: entries.when(
        data: (list) => ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceMd,
            vertical: DesignTokens.spaceSm,
          ),
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: DesignTokens.spaceSm),
          itemBuilder: (context, index) {
            final entry = list[index];
            final isRefund = entry.type == 'refund';
            final sign = isRefund ? '-' : '';
            return ListTile(
              tileColor: DesignTokens.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              leading: Container(
                padding: DesignTokens.paddingSm,
                decoration: BoxDecoration(
                  color:
                      (isRefund ? DesignTokens.error : DesignTokens.brandAccent)
                          .withOpacity(0.12),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: Icon(
                  isRefund
                      ? Icons.assignment_return_outlined
                      : Icons.point_of_sale,
                  color: isRefund
                      ? DesignTokens.error
                      : DesignTokens.brandAccent,
                ),
              ),
              title: Text(
                'UGX $sign${entry.total.toStringAsFixed(0)}',
                style: DesignTokens.textBodyBold.copyWith(
                  color: isRefund ? DesignTokens.error : DesignTokens.grayDark,
                ),
              ),
              subtitle: Text(
                '${entry.type.toUpperCase()} • ${_fmt(entry.createdAt)}',
                style: DesignTokens.textSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Print',
                    onPressed: () async {
                      final printer = ref.read(printQueueServiceProvider);
                      if (!printer.printerEnabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Printing is disabled in Settings'),
                          ),
                        );
                        return;
                      }
                      if (!printer.hasPreferredPrinter) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Choose a printer in Settings to print receipts',
                            ),
                          ),
                        );
                        return;
                      }
                      await printer.enqueueReceipt(entry.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt queued for printing'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share PDF',
                    onPressed: () =>
                        ref.read(receiptServiceProvider).sharePdf(entry.id),
                  ),
                  entry.synced
                      ? const Icon(Icons.cloud_done, color: Colors.green)
                      : const Icon(Icons.cloud_upload, color: Colors.orange),
                ],
              ),
              onTap: () => _showEntryDetails(context, ref, entry.id),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEntryDetails(
    BuildContext parentContext,
    WidgetRef ref,
    String entryId,
  ) {
    BottomSheetModal.show(
      context: parentContext,
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
            return Center(
              child: Text('Not found', style: DesignTokens.textBody),
            );
          }
          final entry = bundle.entry;
          final isRefund = entry.type == 'refund';
          final sign = isRefund ? '-' : '';
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
                    Text(
                      'Type: ${entry.type.toUpperCase()}',
                      style: DesignTokens.textSmallBold,
                    ),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Date: ${_fmt(entry.createdAt)}',
                      style: DesignTokens.textSmall,
                    ),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      entry.synced ? 'Synced' : 'Pending sync',
                      style: DesignTokens.textSmall.copyWith(
                        color: entry.synced
                            ? DesignTokens.brandAccent
                            : DesignTokens.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              ...bundle.lines.map(
                (l) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.spaceXs,
                  ),
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
                        'UGX $sign${l.lineTotal.toStringAsFixed(0)}',
                        style: DesignTokens.textBodyBold,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: DesignTokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: Text('Total', style: DesignTokens.textBodyBold),
                  ),
                  Text(
                    'UGX $sign${entry.total.toStringAsFixed(0)}',
                    style: DesignTokens.textBodyBold,
                  ),
                ],
              ),
              if (bundle.payments.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                Text('Payment', style: DesignTokens.textBodyBold),
                const SizedBox(height: DesignTokens.spaceSm),
                ...bundle.payments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(p.method, style: DesignTokens.textSmall),
                        ),
                        Text(
                          'UGX ${p.amount.toStringAsFixed(0)}',
                          style: DesignTokens.textSmallBold,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(receiptServiceProvider).sharePdf(entryId),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final printer = ref.read(printQueueServiceProvider);
                        if (!printer.printerEnabled) {
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Printing is disabled in Settings'),
                            ),
                          );
                          return;
                        }
                        if (!printer.hasPreferredPrinter) {
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Choose a printer in Settings to print receipts',
                              ),
                            ),
                          );
                          return;
                        }
                        await printer.enqueueReceipt(entryId);
                        if (!parentContext.mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Receipt queued for printing'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
              if (entry.type == 'sale') ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _refundFlow(
                            parentContext,
                            ref,
                            bundle,
                            isVoid: false,
                          );
                        },
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('Refund'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _refundFlow(
                            parentContext,
                            ref,
                            bundle,
                            isVoid: true,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.error,
                        ),
                        icon: const Icon(Icons.block),
                        label: const Text('Void'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _refundFlow(
    BuildContext parentContext,
    WidgetRef ref,
    LedgerEntryBundle original, {
    required bool isVoid,
  }) async {
    final ok = await requireManagerPin(
      parentContext,
      ref,
      reason: isVoid
          ? 'Void sale ${original.entry.id}'
          : 'Refund sale ${original.entry.id}',
    );
    if (!parentContext.mounted) return;
    if (!ok) return;

    final quantities = <int, int>{
      for (final line in original.lines) line.id: line.quantity,
    };
    final reasonCtrl = TextEditingController(text: isVoid ? 'Void sale' : '');

    await BottomSheetModal.show<void>(
      context: parentContext,
      title: isVoid ? 'Void Sale' : 'Refund',
      subtitle: original.entry.id,
      child: StatefulBuilder(
        builder: (context, setState) {
          final selectedLines = original.lines
              .where((l) => (quantities[l.id] ?? 0) > 0)
              .map((l) => (l, quantities[l.id] ?? 0))
              .toList();
          final subtotal = selectedLines.fold<double>(
            0,
            (p, e) => p + (e.$1.unitPrice * e.$2),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isVoid
                    ? 'Select items to void (default: all)'
                    : 'Select items to refund (default: all)',
                style: DesignTokens.textSmall,
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              ...original.lines.map((line) {
                final maxQty = line.quantity;
                final qty = quantities[line.id] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                  padding: DesignTokens.paddingMd,
                  decoration: BoxDecoration(
                    color: DesignTokens.surfaceWhite,
                    borderRadius: DesignTokens.borderRadiusMd,
                    border: Border.all(color: DesignTokens.grayLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.title, style: DesignTokens.textBodyBold),
                            const SizedBox(height: DesignTokens.spaceXs),
                            Text(
                              'UGX ${line.unitPrice.toStringAsFixed(0)} • max $maxQty',
                              style: DesignTokens.textSmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: DesignTokens.grayLight.withOpacity(0.25),
                          borderRadius: DesignTokens.borderRadiusSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                quantities[line.id] = (qty - 1).clamp(
                                  0,
                                  maxQty,
                                );
                              }),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: DesignTokens.textBodyBold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                quantities[line.id] = (qty + 1).clamp(
                                  0,
                                  maxQty,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight.withOpacity(0.25),
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Refund total',
                        style: DesignTokens.textBodyBold,
                      ),
                    ),
                    Text(
                      'UGX ${subtotal.toStringAsFixed(0)}',
                      style: DesignTokens.textBodyBold,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: subtotal <= 0
                    ? null
                    : () async {
                        await _createRefundEntry(
                          parentContext,
                          ref,
                          original: original,
                          quantities: quantities,
                          note: reasonCtrl.text.trim().isEmpty
                              ? null
                              : reasonCtrl.text.trim(),
                          isVoid: isVoid,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isVoid
                      ? DesignTokens.error
                      : DesignTokens.brandAccent,
                ),
                icon: Icon(
                  isVoid ? Icons.block : Icons.assignment_return_outlined,
                ),
                label: Text(isVoid ? 'Void Sale' : 'Create Refund'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createRefundEntry(
    BuildContext context,
    WidgetRef ref, {
    required LedgerEntryBundle original,
    required Map<int, int> quantities,
    required String? note,
    required bool isVoid,
  }) async {
    final selected = original.lines
        .where((l) => (quantities[l.id] ?? 0) > 0)
        .toList();
    if (selected.isEmpty) return;

    final refundEntryId = _uuid.v4();
    final idempotencyKey = _uuid.v4();
    final now = DateTime.now().toUtc();

    final refundLines = <LedgerLinesCompanion>[];
    var subtotal = 0.0;
    for (final l in selected) {
      final qty = quantities[l.id] ?? 0;
      if (qty <= 0) continue;
      final lineTotal = l.unitPrice * qty;
      subtotal += lineTotal;
      refundLines.add(
        LedgerLinesCompanion.insert(
          entryId: refundEntryId,
          itemId: Value(l.itemId),
          serviceId: Value(l.serviceId),
          title: l.title,
          quantity: qty,
          unitPrice: l.unitPrice,
          discount: Value(l.discount),
          tax: Value(l.tax),
          lineTotal: lineTotal,
        ),
      );
    }

    final method = original.payments.isNotEmpty
        ? original.payments.first.method
        : 'cash';
    final payments = [
      PaymentsCompanion.insert(
        entryId: refundEntryId,
        method: method,
        amount: subtotal,
        externalRef: const Value(null),
      ),
    ];

    final db = ref.read(appDatabaseProvider);
    await db.saveLedgerEntry(
      entry: LedgerEntriesCompanion.insert(
        id: Value(refundEntryId),
        idempotencyKey: idempotencyKey,
        type: 'refund',
        subtotal: Value(subtotal),
        discount: const Value(0),
        tax: const Value(0),
        total: Value(subtotal),
        note: Value(
          note ??
              (isVoid
                  ? 'Void sale ${original.entry.id}'
                  : 'Refund sale ${original.entry.id}'),
        ),
        staffId: const Value(null),
        outletId: const Value(null),
        customerId: Value(original.entry.customerId),
        createdAt: Value(now),
      ),
      lines: refundLines,
      payments: payments,
    );

    await db.recordAuditLog(
      action: isVoid ? 'void' : 'refund',
      payload: {
        'original_entry_id': original.entry.id,
        'refund_entry_id': refundEntryId,
        'amount': subtotal,
        'note': note,
      },
    );

    await ref.read(syncServiceProvider).enqueue('ledger_push', {
      'entry_id': refundEntryId,
      'idempotency_key': idempotencyKey,
      'type': 'refund',
      'subtotal': subtotal,
      'discount': 0,
      'tax': 0,
      'total': subtotal,
      'note':
          note ??
          (isVoid
              ? 'Void sale ${original.entry.id}'
              : 'Refund sale ${original.entry.id}'),
      'occurred_at': now.toIso8601String(),
      'lines': refundLines
          .map(
            (e) => {
              'product_id': e.itemId.value,
              'service_id': e.serviceId.value,
              'name': e.title.value,
              'price': e.unitPrice.value,
              'quantity': e.quantity.value,
              'subtotal': e.lineTotal.value,
            },
          )
          .toList(),
      'payments': payments
          .map(
            (p) => {
              'method': p.method.value,
              'amount': p.amount.value,
              'external_ref': null,
            },
          )
          .toList(),
    });

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          isVoid ? 'void_created' : 'refund_created',
          props: {
            'original_entry_id': original.entry.id,
            'entry_id': refundEntryId,
            'amount': subtotal,
            'lines_count': selected.length,
          },
        ),
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVoid
              ? 'Void recorded (sync pending)'
              : 'Refund recorded (sync pending)',
        ),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }
}

String _fmt(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
}
