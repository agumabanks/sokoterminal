import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

class StocktakeScreen extends ConsumerStatefulWidget {
  const StocktakeScreen({super.key});

  @override
  ConsumerState<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends ConsumerState<StocktakeScreen> {
  final _noteCtrl = TextEditingController();
  final List<_StocktakeLine> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Stock Count'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => unawaited(ref.read(syncServiceProvider).syncNow()),
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            children: [
              Expanded(child: Text('Counted items', style: DesignTokens.textBodyBold)),
              TextButton.icon(
                onPressed: _saving ? null : () => _addLine(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          if (_lines.isEmpty)
            Container(
              padding: DesignTokens.paddingLg,
              decoration: BoxDecoration(
                color: DesignTokens.surfaceWhite,
                borderRadius: DesignTokens.borderRadiusMd,
                boxShadow: DesignTokens.shadowSm,
              ),
              child: Column(
                children: [
                  Icon(Icons.fact_check_outlined, size: 48, color: DesignTokens.grayMedium),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text('No items counted', style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceXxs),
                  Text(
                    'Add items you counted and set the correct quantity.',
                    style: DesignTokens.textSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final line in _lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    child: _StocktakeLineCard(
                      line: line,
                      onRemove: _saving ? null : () => setState(() => _lines.remove(line)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            onPressed: _saving || _lines.isEmpty ? null : () => _save(context),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Save stock count'),
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }

  Future<void> _addLine(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final items = await db.getAllItems();
    if (!context.mounted) return;

    final chosen = await BottomSheetModal.show<Item>(
      context: context,
      title: 'Select product',
      child: _ItemPicker(items: items),
    );
    if (chosen == null) return;

    final stocks = await db.getItemStocksForItem(chosen.id);
    if (!context.mounted) return;

    final config = await BottomSheetModal.show<_StocktakeConfig>(
      context: context,
      title: 'Counted quantity',
      child: _StocktakeLineConfigForm(item: chosen, stocks: stocks),
    );
    if (config == null) return;

    setState(() {
      _lines.add(
        _StocktakeLine(
          itemId: chosen.id,
          title: chosen.name,
          variant: config.variant,
          countedQty: config.countedQty,
        ),
      );
    });
  }

  Future<void> _save(BuildContext context) async {
    final approved = await requireManagerPin(
      context,
      ref,
      reason: 'save a stock count',
    );
    if (!approved) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final occurredAt = DateTime.now().toUtc();
      final clientStocktakeId = const Uuid().v4();
      final actorStaffId = ref.read(posSessionProvider).staffId?.toString();

      for (final line in _lines) {
        final item = await db.getItemById(line.itemId);
        if (item == null) continue;

        var current = item.stockQty;
        if (line.variant.trim().isNotEmpty) {
          final row = await (db.select(db.itemStocks)
                ..where((t) => t.itemId.equals(line.itemId) & t.variant.equals(line.variant.trim())))
              .getSingleOrNull();
          if (row != null) current = row.stockQty;
        }

        final delta = line.countedQty - current;
        if (delta == 0) continue;
        await db.recordInventoryMovement(
          itemId: line.itemId,
          delta: delta,
          note: 'stocktake',
          variant: line.variant,
        );
      }

      await sync.enqueue('stocktake_push', {
        'idempotency_key': 'stocktake_$clientStocktakeId',
        'client_stocktake_id': clientStocktakeId,
        'occurred_at': occurredAt.toIso8601String(),
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'lines': _lines
            .map(
              (l) => {
                'product_id': l.itemId, // resolved during sync dispatch
                if (l.variant.trim().isNotEmpty) 'variation': l.variant.trim(),
                'counted_qty': l.countedQty,
              },
            )
            .toList(),
      });

      await db.recordAuditLog(
        actorStaffId: actorStaffId,
        action: 'stocktake',
        payload: {
          'client_stocktake_id': clientStocktakeId,
          'occurred_at': occurredAt.toIso8601String(),
          'lines': _lines
              .map((l) => {
                    'item_id': l.itemId,
                    'variant': l.variant,
                    'counted_qty': l.countedQty,
                  })
              .toList(),
        },
      );

      unawaited(sync.syncNow());

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stock count saved'),
          backgroundColor: DesignTokens.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
      setState(() => _saving = false);
    }
  }
}

class _StocktakeLine {
  _StocktakeLine({
    required this.itemId,
    required this.title,
    required this.variant,
    required this.countedQty,
  });

  final String itemId;
  final String title;
  final String variant;
  final int countedQty;
}

class _StocktakeLineCard extends StatelessWidget {
  const _StocktakeLineCard({required this.line, this.onRemove});

  final _StocktakeLine line;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      'Counted: ${line.countedQty}',
      if (line.variant.trim().isNotEmpty) 'Variant: ${line.variant}',
    ];
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        title: Text(line.title),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({required this.items});

  final List<Item> items;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items
            .where((i) => i.name.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Stock: ${item.stockQty}'),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StocktakeConfig {
  _StocktakeConfig({required this.variant, required this.countedQty});

  final String variant;
  final int countedQty;
}

class _StocktakeLineConfigForm extends StatefulWidget {
  const _StocktakeLineConfigForm({
    required this.item,
    required this.stocks,
  });

  final Item item;
  final List<ItemStock> stocks;

  @override
  State<_StocktakeLineConfigForm> createState() => _StocktakeLineConfigFormState();
}

class _StocktakeLineConfigFormState extends State<_StocktakeLineConfigForm> {
  final _qtyCtrl = TextEditingController();
  String _variant = '';

  @override
  void initState() {
    super.initState();
    _qtyCtrl.text = '0';
    if (widget.stocks.isNotEmpty) {
      final hasDefault = widget.stocks.any((s) => (s.variant).trim().isEmpty);
      if (!hasDefault) {
        _variant = widget.stocks.first.variant;
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.stocks
        .map((s) => s.variant)
        .toSet()
        .where((v) => v.trim().isNotEmpty)
        .toList()
      ..sort();

    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.item.name, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          if (variants.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _variant,
              decoration: const InputDecoration(labelText: 'Variant'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Default')),
                ...variants.map((v) => DropdownMenuItem(value: v, child: Text(v))),
              ],
              onChanged: (v) => setState(() => _variant = v ?? ''),
            ),
          if (variants.isNotEmpty) const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Counted quantity',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            onPressed: () {
              final counted = int.tryParse(_qtyCtrl.text.trim()) ?? -1;
              if (counted < 0) return;
              Navigator.pop(context, _StocktakeConfig(variant: _variant, countedQty: counted));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
