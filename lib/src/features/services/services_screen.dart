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
import 'service_bookings_screen.dart';
import 'service_variants_screen.dart';

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
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Bookings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServiceBookingsScreen()),
            ),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.style_outlined),
                          tooltip: 'Manage Variants',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceVariantsScreen(serviceId: service.id),
                            ),
                          ),
                        ),
                        Switch(
                          value: service.publishedOnline,
                          onChanged: (value) async {
                            final db = ref.read(appDatabaseProvider);
                            final sync = ref.read(syncServiceProvider);
                            await db.upsertService(
                              service.toCompanion(true).copyWith(
                                    publishedOnline: Value(value),
                                    synced: const Value(false),
                                    updatedAt: Value(DateTime.now().toUtc()),
                                  ),
                            );

                            final payload = <String, dynamic>{
                              'local_id': service.id,
                              if (service.remoteId != null) 'remote_id': service.remoteId,
                              'title': service.title,
                              'description': service.description,
                              'base_price': service.price,
                              'duration_minutes': service.durationMinutes,
                              'is_published': value,
                            };

                            if (value && service.remoteId == null) {
                              await sync.enqueue('service_create', payload);
                              unawaited(sync.syncNow());
                              return;
                            }

                            if (service.remoteId != null) {
                              await sync.enqueue('service_update', payload);
                              unawaited(sync.syncNow());
                            }
                          },
                        ),
                      ],
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
    final descriptionCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
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
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            TextField(
              controller: descriptionCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
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
                final durationMinutes =
                    int.tryParse(durationCtrl.text.trim().replaceAll(',', ''));
                final description = descriptionCtrl.text.trim();
                if (title.isEmpty || price <= 0) return;

                final db = ref.read(appDatabaseProvider);
                final sync = ref.read(syncServiceProvider);
                final id = const Uuid().v4();
                await db.upsertService(
                  ServicesCompanion.insert(
                    id: Value(id),
                    title: title,
                    price: price,
                    description: description.isEmpty ? const Value.absent() : Value(description),
                    durationMinutes: durationMinutes == null
                        ? const Value.absent()
                        : Value(durationMinutes),
                    publishedOnline: Value(online),
                    synced: const Value(false),
                  ),
                );
                if (online) {
                  await sync.enqueue('service_create', {
                    'local_id': id,
                    'title': title,
                    'description': description,
                    'base_price': price,
                    'duration_minutes': durationMinutes,
                    'is_published': true,
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
    descriptionCtrl.dispose();
    durationCtrl.dispose();
  }
}
