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
import '../widgets/section_header.dart';
import '../checkout/checkout_screen.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesStreamProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddService(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Sync from seller',
            onPressed: () async {
              await ref.read(syncServiceProvider).pullSellerServices();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Services synced')));
              }
            },
          ),
        ],
      ),
      body: services.when(
        data: (list) => ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            const SectionHeader(title: 'Service menu'),
            ...list.map((service) => Card(
                  child: ListTile(
                    title: Text(service.title),
                    subtitle: Text(
                      'UGX ${service.price.toStringAsFixed(0)}'
                      '${service.durationMinutes != null ? ' • ${service.durationMinutes} mins' : ''}',
                    ),
                    trailing: Switch(
                      value: service.publishedOnline,
                      onChanged: (value) async {
                        await ref.read(appDatabaseProvider).upsertService(
                              service.toCompanion(true).copyWith(
                                    publishedOnline: Value(value),
                                    updatedAt: Value(DateTime.now().toUtc()),
                                  ),
                            );
                        if (value) {
                          await ref.read(syncServiceProvider).enqueue('service_update', {
                            'local_id': service.id,
                            'title': service.title,
                            'price': service.price,
                            'description': service.description,
                            'duration': service.durationMinutes,
                            'published': value ? 1 : 0,
                          });
                        }
                      },
                    ),
                  ),
                )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showAddService(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool online = true;
    final parentContext = context;

    await BottomSheetModal.show<void>(
      context: context,
      title: 'Add service',
      subtitle: 'Local service menu',
      child: StatefulBuilder(
        builder: (context, setLocalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.room_service_outlined),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (UGX)',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: online,
              onChanged: (v) => setLocalState(() => online = v),
              title: const Text('Publish online'),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                if (title.isEmpty || price <= 0) return;

                final db = ref.read(appDatabaseProvider);
                final sync = ref.read(syncServiceProvider);
                final id = const Uuid().v4();
                await db.upsertService(
                  ServicesCompanion.insert(
                    id: Value(id),
                    title: title,
                    price: price,
                    publishedOnline: Value(online),
                  ),
                );
                if (online) {
                  await sync.enqueue('service_create', {
                    'local_id': id,
                    'title': title,
                    'price': price,
                    'published': 1,
                  });
                  unawaited(sync.syncNow());
                }

                if (!parentContext.mounted) return;
                Navigator.pop(parentContext);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: const Text('Service added'),
                    backgroundColor: DesignTokens.brandAccent,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    priceCtrl.dispose();
  }
}
