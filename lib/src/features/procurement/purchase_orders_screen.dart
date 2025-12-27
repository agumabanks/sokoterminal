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
import '../../widgets/error_page.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  bool _loading = false;
  String? _error;
  List<_PurchaseOrderSummary> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => unawaited(_load()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DesignTokens.brandAccent,
        onPressed: () => _showCreatePurchaseOrder(context),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return ErrorPage(
        title: 'Failed to load purchase orders',
        message: _error,
        onRetry: _load,
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: DesignTokens.paddingScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add_check_outlined, size: 56, color: DesignTokens.grayMedium),
              const SizedBox(height: DesignTokens.spaceMd),
              Text('No purchase orders yet', style: DesignTokens.textBodyBold),
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                'Create purchase orders for suppliers, then receive stock when delivered.',
                style: DesignTokens.textSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: () => _showCreatePurchaseOrder(context),
                icon: const Icon(Icons.add),
                label: const Text('Create purchase order'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: DesignTokens.paddingScreen,
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spaceSm),
        itemBuilder: (context, index) {
          final po = _rows[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: DesignTokens.brandPrimary,
                child: const Icon(Icons.receipt_long, color: Colors.white),
              ),
              title: Text('PO #${po.id} • ${po.status.toUpperCase()}'),
              subtitle: Text(po.supplierName ?? 'No supplier'),
              trailing: Text(
                'UGX ${po.totalCost.toStringAsFixed(0)}',
                style: DesignTokens.textBodyBold,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(sellerApiProvider).fetchPurchaseOrders();
      final data = res.data;
      final list = data is Map && data['data'] is List ? data['data'] as List : const <dynamic>[];
      final rows = list
          .whereType<Map>()
          .map((e) => _PurchaseOrderSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showCreatePurchaseOrder(BuildContext context) {
    unawaited(() async {
      final approved = await requireManagerPin(
        context,
        ref,
        reason: 'create a purchase order',
      );
      if (!approved) return;

      if (!context.mounted) return;
      final result = await BottomSheetModal.show<_CreatePoResult>(
        context: context,
        title: 'Create Purchase Order',
        child: const _CreatePoForm(),
      );
      if (result == null) return;

      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);
      final occurredAt = DateTime.now().toUtc();
      final clientPoId = const Uuid().v4();
      final actorStaffId = ref.read(posSessionProvider).staffId?.toString();

      await sync.enqueue('purchase_order_push', {
        'idempotency_key': 'po_$clientPoId',
        'client_po_id': clientPoId,
        'supplier_id': result.supplier?.id,
        'status': 'draft',
        'occurred_at': occurredAt.toIso8601String(),
        'note': result.note?.trim().isNotEmpty == true ? result.note!.trim() : null,
        'lines': result.lines
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
        action: 'purchase_order_create',
        payload: {
          'client_po_id': clientPoId,
          'occurred_at': occurredAt.toIso8601String(),
          'supplier_id': result.supplier?.id,
          'lines': result.lines
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
          content: const Text('Purchase order queued for sync'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      await _load();
    }());
  }
}

class _PurchaseOrderSummary {
  _PurchaseOrderSummary({
    required this.id,
    required this.status,
    required this.totalCost,
    this.supplierName,
  });

  final int id;
  final String status;
  final double totalCost;
  final String? supplierName;

  factory _PurchaseOrderSummary.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    return _PurchaseOrderSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'draft',
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      supplierName: supplier is Map ? supplier['name']?.toString() : null,
    );
  }
}

class _CreatePoResult {
  _CreatePoResult({this.supplier, this.note, required this.lines});

  final Supplier? supplier;
  final String? note;
  final List<_CreatePoLine> lines;
}

class _CreatePoLine {
  _CreatePoLine({
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

final _activeSuppliersProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(appDatabaseProvider).watchSuppliers(activeOnly: true);
});

class _CreatePoForm extends ConsumerStatefulWidget {
  const _CreatePoForm();

  @override
  ConsumerState<_CreatePoForm> createState() => _CreatePoFormState();
}

class _CreatePoFormState extends ConsumerState<_CreatePoForm> {
  Supplier? _supplier;
  final _noteCtrl = TextEditingController();
  final List<_CreatePoLine> _lines = [];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(_activeSuppliersProvider);
    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          suppliersAsync.when(
            data: (rows) {
              final sorted = List<Supplier>.from(rows)
                ..sort((a, b) => a.name.compareTo(b.name));
              return DropdownButtonFormField<Supplier?>(
                initialValue: _supplier,
                decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No supplier')),
                  ...sorted.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                ],
                onChanged: (v) => setState(() => _supplier = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(child: Text('Lines', style: DesignTokens.textBodyBold)),
              TextButton.icon(
                onPressed: () => _addLine(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Text('Add at least 1 item', style: DesignTokens.textSmall)
          else
            Column(
              children: [
                for (final l in _lines)
                  ListTile(
                    title: Text(l.title),
                    subtitle: Text('Qty ${l.quantity}${l.variant.trim().isEmpty ? '' : ' • ${l.variant}'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _lines.remove(l)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: DesignTokens.spaceMd),
          ElevatedButton(
            onPressed: _lines.isEmpty
                ? null
                : () {
                    Navigator.pop(
                      context,
                      _CreatePoResult(
                        supplier: _supplier,
                        note: _noteCtrl.text,
                        lines: List<_CreatePoLine>.from(_lines),
                      ),
                    );
                  },
            child: const Text('Save PO'),
          ),
        ],
      ),
    );
  }

  Future<void> _addLine(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final items = await db.getAllItems();
    if (!context.mounted) return;

    final item = await BottomSheetModal.show<Item>(
      context: context,
      title: 'Select product',
      child: _ItemPicker(items: items),
    );
    if (item == null) return;

    final stocks = await db.getItemStocksForItem(item.id);
    if (!context.mounted) return;

    final config = await BottomSheetModal.show<_PoLineConfig>(
      context: context,
      title: 'Line details',
      child: _PoLineConfigForm(item: item, stocks: stocks),
    );
    if (config == null) return;

    setState(() {
      _lines.add(
        _CreatePoLine(
          itemId: item.id,
          title: item.name,
          variant: config.variant,
          quantity: config.quantity,
          unitCost: config.unitCost,
        ),
      );
    });
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
        : widget.items.where((i) => i.name.toLowerCase().contains(q)).toList();

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

class _PoLineConfig {
  _PoLineConfig({required this.variant, required this.quantity, this.unitCost});

  final String variant;
  final int quantity;
  final double? unitCost;
}

class _PoLineConfigForm extends StatefulWidget {
  const _PoLineConfigForm({required this.item, required this.stocks});

  final Item item;
  final List<ItemStock> stocks;

  @override
  State<_PoLineConfigForm> createState() => _PoLineConfigFormState();
}

class _PoLineConfigFormState extends State<_PoLineConfigForm> {
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
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Unit cost (optional)'),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) return;
              final costRaw = _costCtrl.text.trim();
              final cost = costRaw.isEmpty ? null : double.tryParse(costRaw);
              Navigator.pop(context, _PoLineConfig(variant: _variant, quantity: qty, unitCost: cost));
            },
            child: const Text('Add line'),
          ),
        ],
      ),
    );
  }
}
