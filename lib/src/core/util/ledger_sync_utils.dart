import 'dart:convert';

import '../db/app_database.dart';

bool isLedgerEntryQueued(
  String entryId,
  Iterable<SyncOp> syncOps,
) {
  for (final op in syncOps) {
    if (op.opType != 'ledger_push') continue;
    try {
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;
      if (payload['entry_id']?.toString() == entryId) {
        return true;
      }
    } catch (_) {
      continue;
    }
  }
  return false;
}

List<LedgerEntry> ledgerEntriesNeedingPush({
  required List<LedgerEntry> unsynced,
  required Iterable<SyncOp> syncOps,
}) {
  return unsynced
      .where((entry) => !isLedgerEntryQueued(entry.id, syncOps))
      .toList();
}

Map<String, dynamic> buildLedgerPushPayload(LedgerEntryBundle bundle) {
  final entry = bundle.entry;
  return {
    'entry_id': entry.id,
    'idempotency_key': entry.idempotencyKey,
    'type': entry.type,
    if (entry.originalEntryId != null)
      'original_entry_id': entry.originalEntryId,
    'subtotal': entry.subtotal,
    'discount': entry.discount,
    'tax': entry.tax,
    'total': entry.total,
    'note': entry.note,
    'occurred_at': entry.createdAt.toIso8601String(),
    'customer_id': entry.customerId,
    'payments': bundle.payments
        .map(
          (payment) => {
            'method': payment.method,
            'amount': payment.amount,
            if (payment.externalRef != null) 'external_ref': payment.externalRef,
          },
        )
        .toList(),
    'lines': bundle.lines
        .map(
          (line) => {
            'product_id': line.itemId,
            'service_id': line.serviceId,
            'name': line.title,
            if (line.variant != null && line.variant!.trim().isNotEmpty)
              'variation': line.variant,
            'price': line.unitPrice,
            'quantity': line.quantity,
            'subtotal': line.lineTotal,
          },
        )
        .toList(),
  };
}