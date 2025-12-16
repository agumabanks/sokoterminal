import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;

  Future<void> _exportCsv({
    required String filename,
    required List<List<String>> rows,
  }) async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      final csv = rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Export: $filename');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportLedger() async {
    final db = ref.read(appDatabaseProvider);
    final entries = await db.select(db.ledgerEntries).get();
    final rows = <List<String>>[
      [
        'id',
        'type',
        'created_at',
        'subtotal',
        'discount',
        'tax',
        'total',
        'synced',
        'payments',
        'note',
      ],
    ];

    for (final entry in entries) {
      final pays = await (db.select(db.payments)..where((t) => t.entryId.equals(entry.id))).get();
      final paymentStr = pays.map((p) => '${p.method}:${p.amount.toStringAsFixed(0)}').join('|');
      rows.add([
        entry.id,
        entry.type,
        entry.createdAt.toIso8601String(),
        entry.subtotal.toStringAsFixed(2),
        entry.discount.toStringAsFixed(2),
        entry.tax.toStringAsFixed(2),
        entry.total.toStringAsFixed(2),
        entry.synced ? '1' : '0',
        paymentStr,
        entry.note ?? '',
      ]);
    }

    await _exportCsv(filename: 'soko-ledger.csv', rows: rows);
  }

  Future<void> _exportProducts() async {
    final db = ref.read(appDatabaseProvider);
    final items = await db.select(db.items).get();
    final rows = <List<String>>[
      ['id', 'name', 'price', 'stock_qty', 'published_online', 'synced', 'updated_at'],
    ];
    for (final i in items) {
      rows.add([
        i.id,
        i.name,
        i.price.toStringAsFixed(2),
        i.stockQty.toString(),
        i.publishedOnline ? '1' : '0',
        i.synced ? '1' : '0',
        i.updatedAt.toIso8601String(),
      ]);
    }
    await _exportCsv(filename: 'soko-products.csv', rows: rows);
  }

  Future<void> _exportCustomers() async {
    final db = ref.read(appDatabaseProvider);
    final customers = await db.select(db.customers).get();
    final rows = <List<String>>[
      ['id', 'name', 'phone', 'email', 'note', 'updated_at'],
    ];
    for (final c in customers) {
      rows.add([
        c.id,
        c.name,
        c.phone ?? '',
        c.email ?? '',
        c.note ?? '',
        c.updatedAt.toIso8601String(),
      ]);
    }
    await _exportCsv(filename: 'soko-customers.csv', rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Export', style: DesignTokens.textTitle),
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          Container(
            padding: DesignTokens.paddingLg,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusLg,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export data as CSV', style: DesignTokens.textBodyBold),
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  'Share to email/Drive/WhatsApp, or save to files.',
                  style: DesignTokens.textSmall,
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportLedger,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Export ledger'),
                  style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportProducts,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Export products'),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _exportCustomers,
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('Export customers'),
                ),
                if (_busy) ...[
                  const SizedBox(height: DesignTokens.spaceMd),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _csvEscape(String value) {
  final needsQuotes = value.contains(',') || value.contains('\n') || value.contains('"');
  if (!needsQuotes) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
