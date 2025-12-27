import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ServiceVariantsScreen extends ConsumerWidget {
  const ServiceVariantsScreen({required this.serviceId, super.key});
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(serviceVariantsStreamProvider(serviceId));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Pricing Variants'),
      ),
      body: variantsAsync.when(
        data: (variants) {
          if (variants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No variants added', style: DesignTokens.textBody),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Add Variant',
                    onPressed: () => _showEditor(context, ref),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: DesignTokens.paddingScreen,
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final v = variants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                child: ListTile(
                  title: Text(v.name),
                  subtitle: Text('UGX ${v.price.toStringAsFixed(0)} / ${v.unit ?? "unit"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (v.isDefault)
                        const Chip(label: Text('Default'), visualDensity: VisualDensity.compact),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditor(context, ref, variant: v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteVariant(context, ref, v),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: variantsAsync.hasValue && variantsAsync.value!.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showEditor(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _deleteVariant(BuildContext context, WidgetRef ref, ServiceVariant v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete variant?'),
        content: Text('Delete "${v.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);

    await db.deleteServiceVariant(v.id);
    await sync.enqueue('service_variant_delete', {'variant_id': v.id});
    unawaited(sync.syncNow());
  }

  Future<void> _showEditor(BuildContext context, WidgetRef ref, {ServiceVariant? variant}) async {
    final nameCtrl = TextEditingController(text: variant?.name);
    final priceCtrl = TextEditingController(text: variant?.price.toString());
    final unitCtrl = TextEditingController(text: variant?.unit ?? 'unit');
    bool isDefault = variant?.isDefault ?? false;

    await BottomSheetModal.show<void>(
      context: context,
      title: variant == null ? 'Add Variant' : 'Edit Variant',
      child: StatefulBuilder(
        builder: (ctx, setState) => Column(
          children: [
            AppInput(
              controller: nameCtrl,
              label: 'Variant Name (e.g. A4 Color)',
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            AppInput(
              controller: priceCtrl,
              label: 'Price (UGX)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            AppInput(
              controller: unitCtrl,
              label: 'Unit (e.g. page, hr)',
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as Default'),
              value: isDefault,
              onChanged: (v) => setState(() => isDefault = v),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            AppButton(
              label: 'Save Variant',
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                final unit = unitCtrl.text.trim();

                if (name.isEmpty || price <= 0) return;

                Navigator.pop(ctx);

                final db = ref.read(appDatabaseProvider);
                final sync = ref.read(syncServiceProvider);
                final id = variant?.id ?? const Uuid().v4();
                final now = DateTime.now().toUtc();

                // If setting as default, unset others
                if (isDefault) {
                   await db.unsetDefaultVariants(serviceId);
                }

                final companion = ServiceVariantsCompanion(
                  id: Value(id),
                  serviceId: Value(serviceId),
                  name: Value(name),
                  price: Value(price),
                  unit: Value(unit),
                  isDefault: Value(isDefault),
                  updatedAt: Value(now),
                  synced: const Value(false),
                );

                await db.upsertServiceVariant(companion);

                await sync.enqueue('service_variant_push', {
                  'id': id,
                  'service_id': serviceId,
                  'name': name,
                  'price': price,
                  'unit': unit,
                  'is_default': isDefault ? 1 : 0,
                });
                
                // Trigger immediate sync attempt
                unawaited(sync.syncNow());
              },
            ),
          ],
        ),
      ),
    );
  }
}

final serviceVariantsStreamProvider = StreamProvider.family<List<ServiceVariant>, String>((ref, serviceId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchServiceVariants(serviceId);
});
