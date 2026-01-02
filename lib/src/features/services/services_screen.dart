import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../checkout/checkout_screen.dart';
import 'service_bookings_screen.dart';
import 'service_detail_screen.dart';
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
        data: (list) {
          if (list.isEmpty) {
            return _EmptyServicesView(onAddPressed: () => _showAddService(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(syncServiceProvider).pullSellerServices(),
            child: ListView.builder(
              padding: DesignTokens.paddingScreen,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final service = list[index];
                return _ServiceCard(
                  service: service,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreen(serviceId: service.id),
                    ),
                  ),
                  onVariantsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceVariantsScreen(serviceId: service.id),
                    ),
                  ),
                  onTogglePublish: (value) async {
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
                );
              },
            ),
          );
        },
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

/// Premium service card with gradient accent and visual hierarchy
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onTap,
    required this.onVariantsTap,
    required this.onTogglePublish,
  });

  final Service service;
  final VoidCallback onTap;
  final VoidCallback onVariantsTap;
  final ValueChanged<bool> onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final hasDescription = service.description?.isNotEmpty == true;
    final description = hasDescription ? service.description!.plainText : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: DesignTokens.borderRadiusLg,
        child: InkWell(
          borderRadius: DesignTokens.borderRadiusLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Icon with gradient background
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            DesignTokens.brandPrimary,
                            DesignTokens.brandPrimary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.room_service_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMd),
                    // Title and price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title,
                            style: DesignTokens.textBodyBold.copyWith(
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: DesignTokens.brandAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  service.price.toUgx(),
                                  style: TextStyle(
                                    color: DesignTokens.brandAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (service.durationMinutes != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: DesignTokens.grayMedium,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${service.durationMinutes} min',
                                  style: DesignTokens.textSmall.copyWith(
                                    color: DesignTokens.grayMedium,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: service.publishedOnline
                            ? DesignTokens.success.withValues(alpha: 0.1)
                            : DesignTokens.grayLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        service.publishedOnline ? 'Online' : 'Draft',
                        style: TextStyle(
                          color: service.publishedOnline
                              ? DesignTokens.success
                              : DesignTokens.grayMedium,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                // Description preview
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    description,
                    style: DesignTokens.textSmall.copyWith(
                      color: DesignTokens.grayMedium,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: DesignTokens.spaceMd),
                // Action row
                Row(
                  children: [
                    // Variants button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onVariantsTap,
                        icon: const Icon(Icons.style_outlined, size: 18),
                        label: const Text('Variants'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignTokens.brandPrimary,
                          side: BorderSide(
                            color: DesignTokens.brandPrimary.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceMd),
                    // Publish toggle
                    Row(
                      children: [
                        Text(
                          'Publish',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.grayMedium,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: service.publishedOnline,
                          onChanged: onTogglePublish,
                          thumbColor: WidgetStatePropertyAll(
                            service.publishedOnline ? DesignTokens.success : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state with call to action
class _EmptyServicesView extends StatelessWidget {
  const _EmptyServicesView({required this.onAddPressed});
  
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.room_service_outlined,
                size: 64,
                color: DesignTokens.brandPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            Text(
              'No services yet',
              style: DesignTokens.textTitle,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              'Add your first service to start accepting bookings and selling from your terminal.',
              textAlign: TextAlign.center,
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.grayMedium,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
