import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/service_html_utils.dart';
import '../../core/util/service_publish_utils.dart';
import '../../core/util/service_pricing_utils.dart';
import '../../widgets/offline_cached_image.dart';
import '../../widgets/service_description_article.dart';
import '../ads/studio_editor_launcher.dart';
import 'availability_schedule_screen.dart';
import 'service_bookings_screen.dart';
import 'service_calendar_screen.dart';
import 'service_edit_screen.dart';
import 'service_tile_widgets.dart';
import 'service_variants_screen.dart';

/// Detail page for a service — blog-style description, gallery, and actions.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
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

  Future<void> _togglePublish(bool value) async {
    final service = _service;
    if (service == null) return;

    final blockReason = servicePublishBlockReason(service, wantsPublish: value);
    if (blockReason != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blockReason),
          backgroundColor: DesignTokens.warning,
          action: SnackBarAction(
            label: 'Edit',
            onPressed: _showEditService,
          ),
        ),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final payload = buildServiceSyncPayload(
      service.copyWith(
        publishedOnline: value,
        moderationStatus: value
            ? const Value.absent()
            : const Value(null),
      ),
    );
    final opType = service.remoteId == null ? 'service_create' : 'service_update';
    try {
      await db.saveServiceAndEnqueueSync(
        service: service.toCompanion(true).copyWith(
          publishedOnline: Value(value),
          moderationStatus: value
              ? const Value.absent()
              : const Value(null),
          synced: const Value(false),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
        opType: opType,
        syncPayload: payload,
      );
      unawaited(sync.syncCatalogImmediately());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Publishing service — syncing to your shop…'
                : 'Service moved to draft',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
    } catch (e) {
      debugPrint('[ServiceDetail] Publish toggle failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update publish state: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    await ref.read(syncServiceProvider).syncCatalogImmediately();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync requested')),
    );
  }

  Future<void> _showEditService() async {
    final service = _service;
    if (service == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceEditScreen(existingService: service),
      ),
    );
    if (updated == true) {
      await _load();
    }
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

    try {
      await db.deleteServiceAndEnqueueSync(
        serviceId: service.id,
        remoteId: service.remoteId,
      );
      if (service.remoteId != null) {
        unawaited(sync.syncCatalogImmediately());
      }
    } catch (e) {
      debugPrint('[ServiceDetail] Delete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: DesignTokens.error),
        );
      }
      return;
    }

    if (!mounted) return;
    if (parentContext.mounted) {
      Navigator.pop(parentContext);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service deleted'),
        backgroundColor: DesignTokens.success,
      ),
    );
  }

  List<String> _galleryImages(Service service) {
    final urls = decodeJsonStringList(service.galleryUrls);
    final cover = service.imageUrl?.trim();
    if (cover != null && cover.isNotEmpty) {
      final merged = <String>[cover];
      for (final url in urls) {
        if (url != cover) merged.add(url);
      }
      return merged;
    }
    return urls;
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

    final gallery = _galleryImages(service);
    final hasDescription = (service.description?.trim().isNotEmpty ?? false);
    final pricingTiers = decodePricingPackages(service.pricingPackages)
        .where((t) => t.hasPrice)
        .toList();

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          service.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DesignTokens.textTitle,
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: _syncNow,
          ),
          IconButton(
            tooltip: 'Edit service',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditService,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEditService,
        icon: const Icon(Icons.edit),
        label: const Text('Edit'),
        backgroundColor: DesignTokens.brandAccent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: DesignTokens.paddingScreen,
        children: [
          _buildHeroGallery(service, gallery),
          const SizedBox(height: 12),
          if (isServicePendingModeration(service)) ...[
            _buildModerationBanner(),
            const SizedBox(height: 12),
          ],
          _buildSummaryCard(service),
          if (pricingTiers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPackagesCard(pricingTiers),
          ],
          if (hasDescription) ...[
            const SizedBox(height: 12),
            _buildDescriptionCard(service),
          ],
          const SizedBox(height: DesignTokens.spaceLg),
          Text(
            'Actions',
            style: DesignTokens.textBodyBold.copyWith(color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: DesignTokens.info,
                onTap: _showEditService,
              ),
              _ActionTile(
                icon: Icons.design_services_rounded,
                label: 'Design in Studio',
                color: DesignTokens.brandPrimary,
                onTap: () async {
                  final file = await launchStudioForService(
                    context,
                    ref,
                    service: service,
                  );
                  if (!context.mounted) return;
                  if (file != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service promo image saved to Studio')),
                    );
                  }
                },
              ),
              _ActionTile(
                icon: Icons.style_outlined,
                label: 'Variants',
                color: DesignTokens.brandPrimary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceVariantsScreen(serviceId: service.id),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.event_note_outlined,
                label: 'Bookings',
                color: DesignTokens.brandAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceBookingsScreen(serviceId: service.id),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                color: DesignTokens.brandPrimary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServiceCalendarScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.access_time,
                label: 'Availability',
                color: DesignTokens.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AvailabilityScheduleScreen()),
                ),
              ),
              _ActionTile(
                icon: service.publishedOnline
                    ? Icons.unpublished_outlined
                    : Icons.publish_outlined,
                label: service.publishedOnline ? 'Unpublish' : 'Publish',
                color: service.publishedOnline ? DesignTokens.warning : DesignTokens.success,
                onTap: () => _togglePublish(!service.publishedOnline),
              ),
              _ActionTile(
                icon: Icons.cloud_sync_outlined,
                label: 'Sync now',
                color: DesignTokens.grayMedium,
                onTap: _syncNow,
              ),
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: DesignTokens.error,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeroGallery(Service service, List<String> gallery) {
    if (gallery.isEmpty) {
      return ClipRRect(
        borderRadius: DesignTokens.borderRadiusLg,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ServiceArtwork(
            title: service.title,
            imageUrl: service.imageUrl,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: DesignTokens.borderRadiusLg,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _galleryImage(gallery.first, service.title),
          ),
        ),
        if (gallery.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: gallery.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  child: _galleryImage(gallery[i], service.title),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _galleryImage(String url, String title) {
    if (url.startsWith('http')) {
      return OfflineCachedImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorWidget: ServiceArtwork(
          title: title,
          imageUrl: null,
          width: double.infinity,
          height: double.infinity,
          borderRadius: 0,
        ),
      );
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return ServiceArtwork(
      title: title,
      imageUrl: null,
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
    );
  }

  Widget _buildModerationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.warning.withValues(alpha: 0.08),
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_outlined, color: DesignTokens.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Awaiting shop approval', style: DesignTokens.textBodyBold),
                const SizedBox(height: 2),
                Text(
                  'This service is in the moderation queue. Buyers will see it once approved.',
                  style: DesignTokens.textSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Service service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(service.title, style: DesignTokens.textTitleMedium),
              ),
              ServiceStatusBadge(
                publishedOnline: service.publishedOnline,
                moderationStatus: service.moderationStatus,
              ),
            ],
          ),
          if ((service.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              service.summary!.trim(),
              style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
            ),
          ],
          const SizedBox(height: 10),
          Text(service.price.toUgx(), style: DesignTokens.textMono.copyWith(fontSize: 20)),
          if (service.cost != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cost: UGX ${service.cost!.toStringAsFixed(0)}',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (service.durationMinutes != null)
                _MetaChip(
                  icon: Icons.schedule_outlined,
                  label: '${service.durationMinutes} min',
                ),
              if (service.category?.trim().isNotEmpty == true)
                _MetaChip(icon: Icons.category_outlined, label: service.category!.trim()),
              if ((service.serviceType ?? '').trim().isNotEmpty)
                _MetaChip(
                  icon: Icons.place_outlined,
                  label: switch (service.serviceType) {
                    'onsite' => 'On-site',
                    'hybrid' => 'Hybrid',
                    _ => 'Virtual',
                  },
                ),
              if ((service.deliveryTimeframe ?? '').trim().isNotEmpty)
                _MetaChip(
                  icon: Icons.local_shipping_outlined,
                  label: service.deliveryTimeframe!.trim(),
                ),
              _MetaChip(
                icon: service.publishedOnline ? Icons.public : Icons.store_outlined,
                label: service.publishedOnline ? 'Online shop' : 'POS only',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesCard(List<ServicePricingTier> tiers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pricing packages', style: DesignTokens.textBodyBold),
          const SizedBox(height: 10),
          ...tiers.map((tier) {
            final label = switch (tier.tier) {
              'basic' => 'Basic',
              'standard' => 'Standard',
              'premium' => 'Premium',
              _ => tier.tier,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: DesignTokens.textBodyBold),
                        if ((tier.description ?? '').trim().isNotEmpty)
                          Text(tier.description!.trim(), style: DesignTokens.textSmall),
                        if (tier.deliveryDays != null || tier.revisions != null)
                          Text(
                            [
                              if (tier.deliveryDays != null) '${tier.deliveryDays} days',
                              if (tier.revisions != null) '${tier.revisions} revisions',
                            ].join(' · '),
                            style: DesignTokens.textCaption,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    tier.price!.toUgx(),
                    style: DesignTokens.textMono.copyWith(fontSize: 14),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(Service service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18, color: DesignTokens.brandPrimary),
              const SizedBox(width: 8),
              Text('About this service', style: DesignTokens.textBodyBold),
            ],
          ),
          const SizedBox(height: 14),
          ServiceDescriptionArticle(html: service.description),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DesignTokens.canvasCloud,
        borderRadius: DesignTokens.borderRadiusFull,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignTokens.inkMuted),
          const SizedBox(width: 4),
          Text(label, style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surfaceWhite,
      borderRadius: DesignTokens.borderRadiusLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: DesignTokens.textBodyBold.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}