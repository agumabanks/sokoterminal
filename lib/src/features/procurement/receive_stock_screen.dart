import 'dart:async';

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

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(appDatabaseProvider).watchSuppliers(activeOnly: false);
});

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  Supplier? _supplier;
  final _noteCtrl = TextEditingController();
  final List<_ReceiveLine> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Receive Stock'),
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
          Text('Supplier (optional)', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceXs),
          suppliersAsync.when(
            data: (suppliers) {
              final active = suppliers.where((s) => s.active).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              return DropdownButtonFormField<Supplier?>(
                initialValue: _supplier,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No supplier')),
                  ...active.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _supplier = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
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
              Expanded(
                child: Text('Items', style: DesignTokens.textBodyBold),
              ),
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
                  Icon(Icons.inventory_2_outlined, size: 48, color: DesignTokens.grayMedium),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text('No items added', style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceXxs),
                  Text(
                    'Add items you received from a supplier.',
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
                    child: _ReceiveLineCard(
                      line: line,
                      onRemove: _saving
                          ? null
                          : () => setState(() => _lines.remove(line)),
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
            label: Text(_saving ? 'Saving…' : 'Save receipt'),
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

    final config = await BottomSheetModal.show<_LineConfig>(
      context: context,
      title: 'Receive quantity',
      child: _ReceiveLineConfigForm(
        item: chosen,
        stocks: stocks,
      ),
    );
    if (config == null) return;

    setState(() {
      _lines.add(
        _ReceiveLine(
          itemId: chosen.id,
          title: chosen.name,
          variant: config.variant,
          quantity: config.quantity,
          unitCost: config.unitCost,
        ),
      );
    });
  }

  Future<void> _save(BuildContext context) async {
    final approved = await requireManagerPin(
      context,
      ref,
      reason: 'receive stock',
    );
    if (!approved) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final occurredAt = DateTime.now().toUtc();
      final clientGrnId = const Uuid().v4();
      final actorStaffId = ref.read(posSessionProvider).staffId?.toString();

      for (final line in _lines) {
        await db.recordInventoryMovement(
          itemId: line.itemId,
          delta: line.quantity,
          note: 'receive_stock',
          variant: line.variant,
        );
      }

      await sync.enqueue('grn_push', {
        'idempotency_key': 'grn_$clientGrnId',
        'client_grn_id': clientGrnId,
        'supplier_id': _supplier?.id,
        'received_at': occurredAt.toIso8601String(),
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        'lines': _lines
            .map(
              (l) => {
                'product_id': l.itemId, // resolved to remote id during sync dispatch
                if (l.variant.trim().isNotEmpty) 'variation': l.variant.trim(),
                'quantity': l.quantity,
                if (l.unitCost != null) 'unit_cost': l.unitCost,
              },
            )
            .toList(),
      });

      await db.recordAuditLog(
        actorStaffId: actorStaffId,
        action: 'receive_stock',
        payload: {
          'client_grn_id': clientGrnId,
          'supplier_id': _supplier?.id,
          'received_at': occurredAt.toIso8601String(),
          'lines': _lines
              .map((l) => {
                    'item_id': l.itemId,
                    'variant': l.variant,
                    'quantity': l.quantity,
                    if (l.unitCost != null) 'unit_cost': l.unitCost,
                  })
              .toList(),
        },
      );

      unawaited(sync.syncNow());

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stock received'),
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

class _ReceiveLine {
  _ReceiveLine({
    required this.itemId,
    required this.title,
    required this.variant,
    required this.quantity,
    this.unitCost,
  });

  final String itemId;
  final String title;
  final String variant;
  final int quantity;
  final double? unitCost;
}

class _ReceiveLineCard extends StatelessWidget {
  const _ReceiveLineCard({required this.line, this.onRemove});

  final _ReceiveLine line;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      'Qty: ${line.quantity}',
      if (line.variant.trim().isNotEmpty) 'Variant: ${line.variant}',
      if (line.unitCost != null) 'Cost: ${line.unitCost!.toStringAsFixed(0)}',
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

class _LineConfig {
  _LineConfig({required this.variant, required this.quantity, this.unitCost});

  final String variant;
  final int quantity;
  final double? unitCost;
}

class _ReceiveLineConfigForm extends StatefulWidget {
  const _ReceiveLineConfigForm({
    required this.item,
    required this.stocks,
  });

  final Item item;
  final List<ItemStock> stocks;

  @override
  State<_ReceiveLineConfigForm> createState() => _ReceiveLineConfigFormState();
}

class _ReceiveLineConfigFormState extends State<_ReceiveLineConfigForm> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  String _variant = '';

  @override
  void initState() {
    super.initState();
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
    _costCtrl.dispose();
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
              labelText: 'Quantity received',
              prefixIcon: Icon(Icons.add),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Unit cost (optional)',
              prefixIcon: Icon(Icons.price_change_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) return;
              final unitCostRaw = _costCtrl.text.trim();
              final unitCost = unitCostRaw.isEmpty ? null : double.tryParse(unitCostRaw);
              Navigator.pop(context, _LineConfig(variant: _variant, quantity: qty, unitCost: unitCost));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
