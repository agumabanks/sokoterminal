import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_input.dart';
import '../../widgets/bottom_sheet_modal.dart';

final itemStocksStreamProvider =
    StreamProvider.family<List<ItemStock>, String>((ref, itemId) {
  return ref.watch(appDatabaseProvider).watchItemStocksForItem(itemId);
});

class ProductVariantsScreen extends ConsumerWidget {
  const ProductVariantsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final stocksAsync = ref.watch(itemStocksStreamProvider(itemId));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Variants', style: DesignTokens.textTitle),
      ),
      body: FutureBuilder<Item?>(
        future: db.getItemById(itemId),
        builder: (context, snap) {
          final item = snap.data;
          return stocksAsync.when(
            data: (stocks) {
              final variantsCount =
                  stocks.where((s) => s.variant.trim().isNotEmpty).length;
              return ListView(
                padding: DesignTokens.paddingScreen,
                children: [
                  if (item != null)
                    _HeaderCard(
                      item: item,
                      variantsCount: variantsCount,
                    ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  if (stocks.isEmpty)
                    _EmptyState(
                      onAdd: () => _addVariant(context, ref, item, stocks),
                    )
                  else
                    ...stocks
                        .map(
                          (s) => _VariantTile(
                            stock: s,
                            onEdit: () => _editVariant(
                              context,
                              ref,
                              item,
                              stocks,
                              s,
                            ),
                            onArchive: s.variant.trim().isEmpty
                                ? null
                                : () => _archiveVariant(
                                      context,
                                      ref,
                                      item,
                                      s,
                                    ),
                          ),
                        )
                        .toList(),
                  const SizedBox(height: DesignTokens.spaceXl),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load variants: $e')),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DesignTokens.brandAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add variant'),
        onPressed: () async {
          final item = await ref.read(appDatabaseProvider).getItemById(itemId);
          final stocks = await ref
              .read(appDatabaseProvider)
              .getItemStocksForItem(itemId);
          if (!context.mounted) return;
          await _addVariant(context, ref, item, stocks);
        },
      ),
    );
  }

  Future<void> _addVariant(
    BuildContext context,
    WidgetRef ref,
    Item? item,
    List<ItemStock> existingStocks,
  ) async {
    await _showVariantEditor(
      context,
      ref,
      item: item,
      existingStocks: existingStocks,
      editing: null,
    );
  }

  Future<void> _editVariant(
    BuildContext context,
    WidgetRef ref,
    Item? item,
    List<ItemStock> existingStocks,
    ItemStock stock,
  ) async {
    await _showVariantEditor(
      context,
      ref,
      item: item,
      existingStocks: existingStocks,
      editing: stock,
    );
  }

  Future<void> _archiveVariant(
    BuildContext context,
    WidgetRef ref,
    Item? item,
    ItemStock stock,
  ) async {
    final confirmed = await BottomSheetModal.show<bool>(
      context: context,
      title: 'Archive variant',
      subtitle: stock.variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This sets the variant stock to 0 (safe for audit/history) and will sync on next sync.',
            style: DesignTokens.textSmall,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.error),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(appDatabaseProvider);
    await (db.update(db.itemStocks)
          ..where((t) =>
              t.itemId.equals(itemId) & t.variant.equals(stock.variant)))
        .write(
      ItemStocksCompanion(
        stockQty: const drift.Value(0),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );

    await _recomputeItemSummary(ref, item);
    await _enqueueVariantSync(ref, item);

    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'variant_archived',
          props: {'item_id': itemId, 'variant': stock.variant},
        ),
      );
    }
  }

  Future<void> _showVariantEditor(
    BuildContext context,
    WidgetRef ref, {
    required Item? item,
    required List<ItemStock> existingStocks,
    required ItemStock? editing,
  }) async {
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the product first, then add variants.')),
      );
      return;
    }

    final variantCtrl = TextEditingController(text: editing?.variant ?? '');
    final priceCtrl = TextEditingController(
      text: editing != null ? editing.price.toStringAsFixed(0) : '',
    );
    final stockCtrl = TextEditingController(
      text: editing != null ? editing.stockQty.toString() : '0',
    );
    final skuCtrl = TextEditingController(text: editing?.sku ?? '');

    try {
      final saved = await BottomSheetModal.show<bool>(
        context: context,
        title: editing == null ? 'Add variant' : 'Edit variant',
        subtitle: item.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              controller: variantCtrl,
              label: 'Variant label *',
              hint: 'e.g. Red-L / 5KG / 32GB',
              prefixIcon: Icons.category_outlined,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {},
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: priceCtrl,
                    label: 'Price (UGX) *',
                    hint: '5000',
                    prefixIcon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm),
                Expanded(
                  child: AppInput(
                    controller: stockCtrl,
                    label: 'Stock *',
                    hint: '0',
                    prefixIcon: Icons.inventory_2_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            AppInput(
              controller: skuCtrl,
              label: 'SKU / Barcode (optional)',
              hint: 'ABC-RED-L',
              prefixIcon: Icons.qr_code_2_outlined,
              onChanged: (_) {},
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save variant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
              ),
            ),
          ],
        ),
      );
      if (saved != true) return;

      final variant = variantCtrl.text.trim();
      if (variant.isEmpty) {
        _toast(context, 'Variant label is required.');
        return;
      }

      if (editing == null) {
        final dup = existingStocks.any(
          (s) => s.variant.trim().toLowerCase() == variant.toLowerCase(),
        );
        if (dup) {
          _toast(context, 'Variant already exists.');
          return;
        }
      } else {
        // Keep variant key stable (primary key includes variant).
        if (editing.variant.trim() != variant) {
          _toast(context, 'Renaming variants is not supported yet.');
          return;
        }
      }

      final price = double.tryParse(priceCtrl.text.trim());
      if (price == null || price <= 0) {
        _toast(context, 'Enter a valid variant price.');
        return;
      }
      final qty = int.tryParse(stockCtrl.text.trim());
      if (qty == null || qty < 0) {
        _toast(context, 'Enter a valid stock quantity.');
        return;
      }

      final sku = skuCtrl.text.trim();
      if (sku.isNotEmpty) {
        final db = ref.read(appDatabaseProvider);
        final stockMatches = await (db.select(db.itemStocks)
              ..where((t) => t.sku.equals(sku)))
            .get();
        final conflictStock = stockMatches.any(
          (s) => !(s.itemId == itemId && s.variant == variant),
        );
        if (conflictStock) {
          _toast(context, 'SKU is already used by another variant.');
          return;
        }

        final itemMatches =
            await (db.select(db.items)..where((t) => t.sku.equals(sku))).get();
        final conflictItem = itemMatches.any((i) => i.id != itemId);
        if (conflictItem) {
          _toast(context, 'SKU is already used by another product.');
          return;
        }
      }

      final db = ref.read(appDatabaseProvider);

      // If this is the first non-empty variant, prevent selling the legacy base row.
      final hasBaseRow = existingStocks.any((s) => s.variant.trim().isEmpty);
      final hasNonEmpty = existingStocks.any((s) => s.variant.trim().isNotEmpty);
      if (editing == null && hasBaseRow && !hasNonEmpty) {
        await (db.update(db.itemStocks)
              ..where((t) =>
                  t.itemId.equals(itemId) & t.variant.equals('')))
            .write(
          ItemStocksCompanion(
            stockQty: const drift.Value(0),
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
      }

      await db.upsertItemStock(
        ItemStocksCompanion.insert(
          itemId: itemId,
          variant: variant,
          remoteStockId: editing?.remoteStockId != null
              ? drift.Value(editing!.remoteStockId!)
              : const drift.Value.absent(),
          price: price,
          stockQty: drift.Value(qty),
          sku: sku.isEmpty ? const drift.Value.absent() : drift.Value(sku),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );

      await _recomputeItemSummary(ref, item);
      await _enqueueVariantSync(ref, item);

      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(
          telemetry.event(
            editing == null ? 'variant_added' : 'variant_updated',
            props: {
              'item_id': itemId,
              'variant': variant,
              'has_sku': sku.isNotEmpty,
            },
          ),
        );
      }
    } finally {
      variantCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
      skuCtrl.dispose();
    }
  }

  Future<void> _recomputeItemSummary(WidgetRef ref, Item? item) async {
    if (item == null) return;
    final db = ref.read(appDatabaseProvider);
    final stocks = await db.getItemStocksForItem(itemId);
    if (stocks.isEmpty) return;

    final minPrice = stocks.map((s) => s.price).reduce((a, b) => a < b ? a : b);
    final totalStock = stocks.fold<int>(0, (sum, s) => sum + s.stockQty);

    await db.updateItemFields(
      itemId,
      ItemsCompanion(
        price: drift.Value(minPrice),
        stockQty: drift.Value(totalStock),
        synced: const drift.Value(false),
        updatedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _enqueueVariantSync(WidgetRef ref, Item? item) async {
    if (item == null) return;
    final sync = ref.read(syncServiceProvider);
    await sync.enqueue('item_update', {
      'local_id': itemId,
      if (item.remoteId != null) 'remote_id': item.remoteId,
    });
    unawaited(sync.syncNow());
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.item, required this.variantsCount});

  final Item item;
  final int variantsCount;

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
          Text(item.name, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            '$variantsCount variants • Stock ${item.stockQty}',
            style: DesignTokens.textSmall,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Tip: Use clear labels (e.g. “Red-L”, “5KG”). If you add variants, selling requires choosing a variant at checkout.',
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayDark),
          ),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.stock,
    required this.onEdit,
    this.onArchive,
  });

  final ItemStock stock;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final label = stock.variant.trim().isEmpty ? 'Default' : stock.variant.trim();
    final sku = (stock.sku ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.grayLight),
      ),
      child: ListTile(
        title: Text(label, style: DesignTokens.textBodyBold),
        subtitle: Text(
          [
            'Price UGX ${stock.price.toStringAsFixed(0)}',
            'Stock ${stock.stockQty}',
            if (sku.isNotEmpty) 'SKU $sku',
          ].join(' • '),
          style: DesignTokens.textSmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            if (onArchive != null)
              IconButton(
                tooltip: 'Archive',
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined),
                color: DesignTokens.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingLg,
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: DesignTokens.grayMedium),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No variants yet', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              'Add sizes/colors/pack sizes to sell with accurate stock.',
              style: DesignTokens.textSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add variant'),
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
            ),
          ],
        ),
      ),
    );
  }
}
