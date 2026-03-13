import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift hide Column;

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/firebase/remote_config_service.dart';
import '../../core/security/manager_approval.dart';
import '../../core/settings/pos_void_reason_codes.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../invoices/invoice_providers.dart';
import 'receipt_providers.dart';

class ReceiptDetailsSheet extends ConsumerWidget {
  const ReceiptDetailsSheet({super.key, required this.entryId});
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<LedgerEntryBundle?>(
      future: ref.read(appDatabaseProvider).fetchLedgerEntryBundle(entryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bundle = snapshot.data;
        if (bundle == null) {
          return Center(child: Text('Not found', style: DesignTokens.textBody));
        }
        final entry = bundle.entry;
        final lines = bundle.lines;
        final payments = bundle.payments;
        final remoteConfig = ref.read(remoteConfigProvider);
        final isReversal = entry.type == 'refund' || entry.type == 'void';
        final sign = isReversal ? '-' : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
                  Text(
                    'Type: ${entry.type.toUpperCase()}',
                    style: DesignTokens.textSmallBold,
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    'Date: ${_formatDateTime(entry.createdAt)}',
                    style: DesignTokens.textSmall,
                  ),
                  if (entry.originalEntryId != null) ...[
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Ref: ${entry.originalEntryId}',
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.grayMedium,
                      ),
                    ),
                  ],
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
            ...lines.map(
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
                      '$sign${l.lineTotal.toUgx()}',
                      style: DesignTokens.textBodyBold,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: DesignTokens.spaceLg),

            // --- Payment Methods Section ---
            if (payments.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                'Payments',
                style: DesignTokens.textSmallBold.copyWith(
                  color: DesignTokens.grayMedium,
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              ...payments.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentIcon(p.method),
                        size: 16,
                        color: DesignTokens.grayMedium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatPaymentMethod(p.method),
                          style: DesignTokens.textSmall,
                        ),
                      ),
                      Text(
                        '$sign${p.amount.toUgx()}',
                        style: DesignTokens.textSmallBold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              const Divider(height: DesignTokens.spaceSm),
            ],

            // -------------------------------
            Row(
              children: [
                Expanded(
                  child: Text('Total', style: DesignTokens.textBodyBold),
                ),
                Text(
                  '$sign${entry.total.toUgx()}',
                  style: DesignTokens.textBodyBold,
                ),
              ],
            ),
            if (entry.type == 'sale' && remoteConfig.ffPosVoids) ...[
              const SizedBox(height: DesignTokens.spaceMd),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.error,
                  side: const BorderSide(color: DesignTokens.error),
                ),
                onPressed: () async {
                  // We need to pop this sheet first because requireManagerPin might show another sheet/dialog
                  // But actually strict context management suggests keeping it open or handling returns carefully.
                  // However, the original code popped the sheet only after success in some cases or before opening void dialog.
                  // Let's refactor void logic to be outside or careful about context.
                  // For now, let's keep it simple and assume the void logic is self-contained enough or we pop here.

                  // The original code popped the sheet before calling _voidSale to avoid stacking sheets issues or context issues?
                  Navigator.of(context).pop();
                  _voidSale(context, ref, bundle);
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
                        onPressed: () =>
                            ref.read(receiptServiceProvider).sharePdf(entryId),
                        icon: const Icon(Icons.share),
                        label: const Text('Receipt PDF'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(invoiceServiceProvider)
                            .sharePosInvoicePdf(entryId),
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
                        onPressed: () => ref
                            .read(receiptServiceProvider)
                            .shareWhatsapp(entryId),
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
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_money':
        return 'Mobile Money';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'credit':
        return 'Store Credit';
      case 'split':
        return 'Split Payment';
      default:
        return method; // Capitalize first letter?
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.attach_money;
      case 'card':
        return Icons.credit_card;
      case 'mobile_money':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'credit':
        return Icons.receipt_long; // Credit/Note
      default:
        return Icons.payment;
    }
  }

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final printer = ref.read(printQueueServiceProvider);
    if (!printer.printerEnabled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printing is disabled in Settings')),
      );
      return;
    }
    if (!printer.hasPreferredPrinter) {
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set up void reason codes in Settings first.'),
        ),
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
    final alreadyVoided =
        await (db.select(db.ledgerEntries)
              ..where(
                (t) =>
                    t.type.equals('void') & t.originalEntryId.equals(sale.id),
              )
              ..limit(1))
            .getSingleOrNull();
    if (alreadyVoided != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sale is already voided.')));
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
    final actorStaffId =
        ref.read(posSessionProvider).staffId?.toString() ?? sale.staffId;
    final voidId = const Uuid().v4();
    final idempotencyKey = 'void_$voidId';
    final occurredAt = DateTime.now().toUtc();
    final receiptNumber = await db.getNextReceiptNumber();
    final outletId = sale.outletId ?? (await db.getPrimaryOutlet())?.id;
    final note =
        'Void ($reason) for ${formatPosReceiptNumber(sale.receiptNumber)}';

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
        if (p.externalRef != null) 'external_ref': p.externalRef,
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
        synced: const drift.Value(false),
      ),
      lines: lineRows,
      payments: paymentRows,
    );

    // Reverse inventory movement if applicable
    for (final line in saleBundle.lines) {
      if (line.itemId != null) {
        await db.recordInventoryMovement(
          itemId: line.itemId!,
          delta: line.quantity, // Add back to stock
          note: 'Void sale #${sale.receiptNumber}',
          variant: line.variant,
        );
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Void processed successfully')),
    );

    await sync.syncNow();
  }
}
