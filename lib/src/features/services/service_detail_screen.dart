import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/bottom_sheet_modal.dart';
import 'service_bookings_screen.dart';
import 'service_variants_screen.dart';

/// Detail page for a service with edit, variants, and bookings tabs
class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  Service? _service;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final service = await db.getServiceById(widget.serviceId);
    if (mounted) {
      setState(() {
        _service = service;
        _loading = false;
      });
    }
  }

  Future<void> _showEditService() async {
    final service = _service;
    if (service == null) return;

    final titleCtrl = TextEditingController(text: service.title);
    final priceCtrl = TextEditingController(text: service.price.toStringAsFixed(0));
    final descriptionCtrl = TextEditingController(text: service.description ?? '');
    final durationCtrl = TextEditingController(
      text: service.durationMinutes?.toString() ?? '',
    );
    bool online = service.publishedOnline;
    final parentContext = context;

    await BottomSheetModal.show<void>(
      context: context,
      title: 'Edit Service',
      subtitle: service.title,
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.error,
                    ),
                    onPressed: () => _confirmDelete(parentContext),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                      final durationMinutes = int.tryParse(
                        durationCtrl.text.trim().replaceAll(',', ''),
                      );
                      final description = descriptionCtrl.text.trim();
                      if (title.isEmpty || price <= 0) return;

                      final db = ref.read(appDatabaseProvider);
                      final sync = ref.read(syncServiceProvider);

                      await db.upsertService(
                        service.toCompanion(true).copyWith(
                              title: Value(title),
                              price: Value(price),
                              description: description.isEmpty
                                  ? const Value.absent()
                                  : Value(description),
                              durationMinutes: durationMinutes == null
                                  ? const Value.absent()
                                  : Value(durationMinutes),
                              publishedOnline: Value(online),
                              synced: const Value(false),
                              updatedAt: Value(DateTime.now().toUtc()),
                            ),
                      );

                      if (service.remoteId != null) {
                        await sync.enqueue('service_update', {
                          'local_id': service.id,
                          'remote_id': service.remoteId,
                          'title': title,
                          'description': description,
                          'base_price': price,
                          'duration_minutes': durationMinutes,
                          'is_published': online,
                        });
                        unawaited(sync.syncNow());
                      }

                      if (!parentContext.mounted) return;
                      Navigator.pop(parentContext);
                      await _load();
                      if (!parentContext.mounted) return;
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: const Text('Service updated'),
                          backgroundColor: DesignTokens.brandAccent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.brandAccent,
                    ),
                  ),
                ),
              ],
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

  Future<void> _confirmDelete(BuildContext parentContext) async {
    final service = _service;
    if (service == null) return;

    final confirm = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete "${service.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DesignTokens.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);

    if (service.remoteId != null) {
      await sync.enqueue('service_delete', {
        'local_id': service.id,
        'remote_id': service.remoteId,
      });
      unawaited(sync.syncNow());
    }

    await db.deleteService(service.id);

    if (!mounted) return;
    if (parentContext.mounted) {
      Navigator.pop(parentContext); // Close bottom sheet
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Service deleted'),
        backgroundColor: DesignTokens.error,
      ),
    );
    Navigator.pop(context); // Close detail screen
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final service = _service;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: const Center(child: Text('Service not found')),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text(service.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditService,
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          // Service Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: DesignTokens.brandPrimary,
                        child: const Icon(
                          Icons.room_service_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title,
                              style: DesignTokens.textTitleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'UGX ${service.price.toStringAsFixed(0)}',
                              style: DesignTokens.textBodyBold.copyWith(
                                color: DesignTokens.brandAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spaceSm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: service.publishedOnline
                              ? DesignTokens.success.withValues(alpha: 0.1)
                              : DesignTokens.grayLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.publishedOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: service.publishedOnline
                                ? DesignTokens.success
                                : DesignTokens.grayMedium,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (service.durationMinutes != null) ...[
                    const SizedBox(height: DesignTokens.spaceMd),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: DesignTokens.grayMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${service.durationMinutes} minutes',
                          style: DesignTokens.textSmall,
                        ),
                      ],
                    ),
                  ],
                  if (service.description?.isNotEmpty == true) ...[
                    const SizedBox(height: DesignTokens.spaceMd),
                    Text(
                      service.description!.plainText,
                      style: DesignTokens.textBody,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.spaceLg),

          // Quick Actions
          Text(
            'Quick Actions',
            style: DesignTokens.textBodyBold.copyWith(
              color: DesignTokens.grayMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          // Edit Service
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.edit_outlined),
              ),
              title: const Text('Edit Service'),
              subtitle: const Text('Update name, price, and details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showEditService,
            ),
          ),

          const SizedBox(height: DesignTokens.spaceSm),

          // Manage Variants
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.style_outlined),
              ),
              title: const Text('Pricing Variants'),
              subtitle: const Text('Manage different pricing options'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceVariantsScreen(serviceId: service.id),
                ),
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.spaceSm),

          // View Bookings
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: DesignTokens.brandAccent,
                child: const Icon(Icons.event_note_outlined, color: Colors.white),
              ),
              title: const Text('Bookings'),
              subtitle: const Text('View customer bookings for this service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceBookingsScreen(serviceId: service.id),
                ),
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.spaceLg),

          // Stats Section (placeholder for future)
          Text(
            'Statistics',
            style: DesignTokens.textBodyBold.copyWith(
              color: DesignTokens.grayMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Sales',
                    value: '—',
                  ),
                  _StatItem(
                    icon: Icons.event_available,
                    label: 'Bookings',
                    value: '—',
                  ),
                  _StatItem(
                    icon: Icons.attach_money,
                    label: 'Revenue',
                    value: '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: DesignTokens.brandPrimary),
        const SizedBox(height: 4),
        Text(
          value,
          style: DesignTokens.textTitleMedium,
        ),
        Text(
          label,
          style: DesignTokens.textSmall.copyWith(
            color: DesignTokens.grayMedium,
          ),
        ),
      ],
    );
  }
}
