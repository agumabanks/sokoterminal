import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class SyncHealthScreen extends ConsumerStatefulWidget {
  const SyncHealthScreen({super.key});

  @override
  ConsumerState<SyncHealthScreen> createState() => _SyncHealthScreenState();
}

class _SyncHealthScreenState extends ConsumerState<SyncHealthScreen> {
  late Future<_SyncHealthSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SyncHealthSnapshot> _load() async {
    final db = ref.read(appDatabaseProvider);

    final connectivity = await Connectivity().checkConnectivity();
    final online =
        connectivity.contains(ConnectivityResult.mobile) ||
        connectivity.contains(ConnectivityResult.wifi);

    final pendingOps = await db.pendingSyncOps();
    final pendingCount = pendingOps.length;
    final retryingCount = pendingOps.where((e) => e.retryCount > 0).length;

    final byType = <String, int>{};
    for (final op in pendingOps) {
      byType[op.opType] = (byType[op.opType] ?? 0) + 1;
    }

    final failures =
        pendingOps
            .where(
              (op) =>
                  op.retryCount > 0 && (op.lastError ?? '').trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) {
            final at =
                a.lastTriedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            final bt =
                b.lastTriedAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            return bt.compareTo(at);
          });

    final lastTriedExp = db.syncOps.lastTriedAt.max();
    final lastTriedRow = await (db.selectOnly(
      db.syncOps,
    )..addColumns([lastTriedExp])).getSingle();

    final oldestPendingExp = db.syncOps.createdAt.min();
    final oldestPendingRow =
        await (db.selectOnly(db.syncOps)
              ..addColumns([oldestPendingExp])
              ..where(db.syncOps.status.equals('pending')))
            .getSingle();

    final pendingLedgerExp = db.ledgerEntries.id.count();
    final pendingLedgerRow =
        await (db.selectOnly(db.ledgerEntries)
              ..addColumns([pendingLedgerExp])
              ..where(db.ledgerEntries.synced.equals(false)))
            .getSingle();

    final productsPulled = await db.getLastPulledAt('products');
    final servicesPulled = await db.getLastPulledAt('services');
    final customersPulled = await db.getLastPulledAt('customers');
    final configPulled = await db.getLastPulledAt('config');

    return _SyncHealthSnapshot(
      online: online,
      pendingOps: pendingCount,
      retryingOps: retryingCount,
      failingOps: failures.take(8).toList(),
      pendingLedgerEntries: pendingLedgerRow.read(pendingLedgerExp) ?? 0,
      lastTriedAt: lastTriedRow.read(lastTriedExp),
      oldestPendingAt: oldestPendingRow.read(oldestPendingExp),
      byType: byType,
      productsPulledAt: productsPulled,
      servicesPulledAt: servicesPulled,
      customersPulledAt: customersPulled,
      configPulledAt: configPulled,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Sync Health', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_SyncHealthSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Text(
                  'Failed to load sync health: ${snapshot.error}',
                  style: DesignTokens.textBody,
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                _SummaryCard(data: data),
                const SizedBox(height: DesignTokens.spaceMd),
                _CursorsCard(data: data),
                const SizedBox(height: DesignTokens.spaceMd),
                _OutboxCard(data: data),
                if (data.failingOps.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.spaceMd),
                  _FailuresCard(data: data),
                ],
                const SizedBox(height: DesignTokens.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sync started…')),
                          );
                          await ref.read(syncServiceProvider).syncNow();
                          _refresh();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sync finished')),
                          );
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Now'),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final db = ref.read(appDatabaseProvider);
                          await (db.delete(
                            db.syncOps,
                          )..where((t) => t.status.equals('synced'))).go();
                          _refresh();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cleared synced outbox items'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Cleanup'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceLg),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final _SyncHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    final statusColor = data.online
        ? DesignTokens.brandAccent
        : DesignTokens.warning;
    final statusLabel = data.online ? 'Online' : 'Offline';
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: DesignTokens.spaceSm),
              Text('Status: $statusLabel', style: DesignTokens.textBodyBold),
              const Spacer(),
              Text(
                '${data.pendingOps} queued',
                style: DesignTokens.textSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: data.pendingOps == 0
                      ? DesignTokens.grayMedium
                      : DesignTokens.grayDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Pending ledger entries: ${data.pendingLedgerEntries}',
            style: DesignTokens.textSmall,
          ),
          Text(
            'Retrying ops: ${data.retryingOps}',
            style: DesignTokens.textSmall,
          ),
          if (data.failingOps.isNotEmpty)
            Text(
              'Recent failures: ${data.failingOps.length}',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Last tried: ${_fmt(data.lastTriedAt)}',
            style: DesignTokens.textSmall,
          ),
          Text(
            'Oldest pending: ${_fmt(data.oldestPendingAt)}',
            style: DesignTokens.textSmall,
          ),
        ],
      ),
    );
  }
}

class _CursorsCard extends StatelessWidget {
  const _CursorsCard({required this.data});
  final _SyncHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last Delta Pull', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          _CursorRow(label: 'Products', value: _fmt(data.productsPulledAt)),
          _CursorRow(label: 'Services', value: _fmt(data.servicesPulledAt)),
          _CursorRow(label: 'Customers', value: _fmt(data.customersPulledAt)),
          _CursorRow(label: 'Config', value: _fmt(data.configPulledAt)),
        ],
      ),
    );
  }
}

class _CursorRow extends StatelessWidget {
  const _CursorRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DesignTokens.textSmall)),
          Text(value, style: DesignTokens.textSmallBold),
        ],
      ),
    );
  }
}

class _OutboxCard extends StatelessWidget {
  const _OutboxCard({required this.data});
  final _SyncHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    final entries = data.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outbox Breakdown', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          if (entries.isEmpty)
            Text('No pending sync operations.', style: DesignTokens.textSmall)
          else
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceXs,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: DesignTokens.textSmall)),
                    Text('${e.value}', style: DesignTokens.textSmallBold),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FailuresCard extends ConsumerWidget {
  const _FailuresCard({required this.data});
  final _SyncHealthSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Failures', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          ...data.failingOps.map(
            (op) => InkWell(
              onTap: () => _showFailureDetails(context, ref, op),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceXs,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: DesignTokens.error,
                      size: 18,
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Text(
                        '${op.opType} • retry ${op.retryCount}',
                        style: DesignTokens.textSmallBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Text(_fmt(op.lastTriedAt), style: DesignTokens.textSmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Tap an item to see the error and payload.',
            style: DesignTokens.textSmall,
          ),
        ],
      ),
    );
  }

  void _showFailureDetails(BuildContext context, WidgetRef ref, SyncOp op) {
    BottomSheetModal.show(
      context: context,
      title: 'Sync failure',
      subtitle: op.opType,
      maxHeight: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('ID', op.id.toString()),
          _kv('Retries', op.retryCount.toString()),
          _kv('Last tried', _fmt(op.lastTriedAt)),
          const SizedBox(height: DesignTokens.spaceSm),
          if ((op.lastError ?? '').trim().isNotEmpty) ...[
            Text('Error', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.25),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Text(op.lastError!, style: DesignTokens.textSmall),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
          ],
          Text('Payload', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceXs),
          Expanded(
            child: Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.25),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: SingleChildScrollView(
                child: Text(
                  _prettyJson(op.payload),
                  style: DesignTokens.textSmall.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(appDatabaseProvider).retrySyncOpNow(op.id);
                    await ref.read(syncServiceProvider).syncNow();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Retry triggered')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry now'),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: op.payload));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied payload')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(key, style: DesignTokens.textSmallBold),
          ),
          Expanded(child: Text(value, style: DesignTokens.textSmall)),
        ],
      ),
    );
  }

  String _prettyJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }
}

class _SyncHealthSnapshot {
  _SyncHealthSnapshot({
    required this.online,
    required this.pendingOps,
    required this.retryingOps,
    required this.failingOps,
    required this.pendingLedgerEntries,
    required this.lastTriedAt,
    required this.oldestPendingAt,
    required this.byType,
    required this.productsPulledAt,
    required this.servicesPulledAt,
    required this.customersPulledAt,
    required this.configPulledAt,
  });

  final bool online;
  final int pendingOps;
  final int retryingOps;
  final List<SyncOp> failingOps;
  final int pendingLedgerEntries;
  final DateTime? lastTriedAt;
  final DateTime? oldestPendingAt;
  final Map<String, int> byType;
  final DateTime? productsPulledAt;
  final DateTime? servicesPulledAt;
  final DateTime? customersPulledAt;
  final DateTime? configPulledAt;
}

String _fmt(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
}
