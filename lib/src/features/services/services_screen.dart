import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/service_publish_utils.dart';
import '../../widgets/sync_status_badge.dart';
import '../checkout/checkout_screen.dart';
import 'availability_schedule_screen.dart';
import 'client_directory_screen.dart';
import 'service_calendar_screen.dart';
import 'service_edit_screen.dart';
import 'service_insights_screen.dart';
import 'service_detail_screen.dart';
import 'service_tile_widgets.dart';
const _servicesViewModeKey = 'services_view_mode';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String _searchQuery = '';
  ServicesViewMode _viewMode = ServicesViewMode.list;
  ServicesFilter _filter = ServicesFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadViewMode());
  }

  Future<void> _loadViewMode() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_servicesViewModeKey);
    if (!mounted || saved == null) return;
    setState(() {
      _viewMode = saved == 'grid' ? ServicesViewMode.grid : ServicesViewMode.list;
    });
  }

  Future<void> _setViewMode(ServicesViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _servicesViewModeKey,
      mode == ServicesViewMode.grid ? 'grid' : 'list',
    );
  }

  Future<void> _togglePublish(Service service, bool value) async {
    final blockReason = servicePublishBlockReason(service, wantsPublish: value);
    if (blockReason != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blockReason),
          backgroundColor: DesignTokens.warning,
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () => _openServiceDetail(service),
          ),
        ),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final next = service.toCompanion(true).copyWith(
      publishedOnline: Value(value),
      moderationStatus: value
          ? const Value.absent()
          : const Value(null),
      synced: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    );
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
        service: next,
        opType: opType,
        syncPayload: payload,
      );
      unawaited(sync.syncCatalogImmediately());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? servicePublishSnackbarMessage(
                    publishing: true,
                    moderationStatus: 'pending',
                  )
                : 'Service moved to draft',
          ),
          backgroundColor: DesignTokens.brandAccent,
          duration: value ? const Duration(seconds: 5) : const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('[ServicesScreen] Toggle publish sync failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update publish state: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
    }
  }

  void _openServiceDetail(Service service) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => ServiceDetailScreen(serviceId: service.id),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  static const _servicesScrollPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesStreamProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Services', style: DesignTokens.textTitle),
        actions: [
          const SyncStatusBadge(),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) => _handleToolbarAction(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'calendar',
                child: ListTile(
                  leading: Icon(Icons.calendar_month_outlined, size: 20),
                  title: Text('Calendar'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'availability',
                child: ListTile(
                  leading: Icon(Icons.access_time, size: 20),
                  title: Text('Availability'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'clients',
                child: ListTile(
                  leading: Icon(Icons.people_outline, size: 20),
                  title: Text('Clients'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'insights',
                child: ListTile(
                  leading: Icon(Icons.insights_outlined, size: 20),
                  title: Text('Insights'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'sync',
                child: ListTile(
                  leading: Icon(Icons.cloud_sync, size: 20),
                  title: Text('Sync from seller'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _ServicesFab(
        onPressed: () => _showAddService(context, ref),
      ),
      body: Column(
        children: [
          Padding(
            padding: DesignTokens.paddingScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: DesignTokens.surfaceRaised,
                    borderRadius: DesignTokens.borderRadiusSm,
                    border: Border.all(color: DesignTokens.hairline),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: DesignTokens.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          style: DesignTokens.textBody,
                          decoration: InputDecoration(
                            hintText: 'Search services',
                            hintStyle: DesignTokens.textBody.copyWith(
                              color: DesignTokens.textTertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: _ServicesFilterBar(
                        filter: _filter,
                        onChanged: (next) => setState(() => _filter = next),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    _ViewModeToggle(
                      mode: _viewMode,
                      onChanged: _setViewMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: services.when(
              data: (list) {
                final filtered = filterServices(
                  list,
                  searchQuery: _searchQuery,
                  filter: _filter,
                );
                if (filtered.isEmpty) {
                  return _EmptyServicesView(
                    onAddPressed: () => _showAddService(context, ref),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignTokens.spaceMd,
                        0,
                        DesignTokens.spaceMd,
                        DesignTokens.spaceSm,
                      ),
                      child: Text(
                        '${filtered.length} ${filtered.length == 1 ? 'service' : 'services'}',
                        style: DesignTokens.textCaption.copyWith(
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(syncServiceProvider).pullSellerServices(),
                        child: _viewMode == ServicesViewMode.grid
                            ? GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceMd,
                                ),
                                physics: _servicesScrollPhysics,
                                cacheExtent: 640,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: DesignTokens.spaceSm,
                                  crossAxisSpacing: DesignTokens.spaceSm,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final service = filtered[index];
                                  return RepaintBoundary(
                                    child: ServiceGridTile(
                                      service: service,
                                      onTap: () => _openServiceDetail(service),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spaceMd,
                                ),
                                physics: _servicesScrollPhysics,
                                cacheExtent: 720,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final service = filtered[index];
                                  return RepaintBoundary(
                                    child: ServiceLineTile(
                                      service: service,
                                      onTap: () => _openServiceDetail(service),
                                      onTogglePublish: (value) =>
                                          _togglePublish(service, value),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToolbarAction(BuildContext context, String action) async {
    switch (action) {
      case 'calendar':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceCalendarScreen()),
        );
      case 'availability':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AvailabilityScheduleScreen()),
        );
      case 'clients':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClientDirectoryScreen()),
        );
      case 'insights':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceInsightsScreen()),
        );
      case 'sync':
        await ref.read(syncServiceProvider).pullSellerServices();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Services synced')),
          );
        }
    }
  }

  Future<void> _showAddService(BuildContext context, WidgetRef ref) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ServiceEditScreen()),
    );
  }

}

class _ServicesFilterBar extends StatelessWidget {
  const _ServicesFilterBar({
    required this.filter,
    required this.onChanged,
  });

  final ServicesFilter filter;
  final ValueChanged<ServicesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DesignTokens.canvasCloud,
        borderRadius: DesignTokens.borderRadiusFull,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ServicesFilterSegment(
              label: 'All',
              selected: filter == ServicesFilter.all,
              onTap: () => onChanged(ServicesFilter.all),
              compact: true,
            ),
            _ServicesFilterSegment(
              label: 'Live',
              selected: filter == ServicesFilter.online,
              onTap: () => onChanged(ServicesFilter.online),
              compact: true,
            ),
            _ServicesFilterSegment(
              label: 'Pending',
              selected: filter == ServicesFilter.pending,
              onTap: () => onChanged(ServicesFilter.pending),
              compact: true,
            ),
            _ServicesFilterSegment(
              label: 'Draft',
              selected: filter == ServicesFilter.draft,
              onTap: () => onChanged(ServicesFilter.draft),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesFilterSegment extends StatelessWidget {
  const _ServicesFilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        curve: DesignTokens.curveStandard,
        margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 0),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 0,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? DesignTokens.surfaceRaised : Colors.transparent,
          borderRadius: DesignTokens.borderRadiusFull,
          boxShadow: selected ? DesignTokens.shadowSm : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: DesignTokens.textSmallBold.copyWith(
            color: selected ? DesignTokens.ink : DesignTokens.inkMuted,
            fontSize: compact ? 11 : null,
          ),
        ),
      ),
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final ServicesViewMode mode;
  final ValueChanged<ServicesViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isGrid = mode == ServicesViewMode.grid;
    return Material(
      color: DesignTokens.surfaceRaised,
      borderRadius: DesignTokens.borderRadiusFull,
      child: InkWell(
        onTap: () => onChanged(
          isGrid ? ServicesViewMode.list : ServicesViewMode.grid,
        ),
        borderRadius: DesignTokens.borderRadiusFull,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: DesignTokens.borderRadiusFull,
            border: Border.all(color: DesignTokens.hairline),
          ),
          child: Icon(
            isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            size: 20,
            color: DesignTokens.inkSubtle,
          ),
        ),
      ),
    );
  }
}

class _ServicesFab extends StatefulWidget {
  const _ServicesFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ServicesFab> createState() => _ServicesFabState();
}

class _ServicesFabState extends State<_ServicesFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'services-fab',
      onPressed: () {
        setState(() => _pressed = !_pressed);
        widget.onPressed();
      },
      icon: AnimatedRotation(
        turns: _pressed ? 0.5 : 0,
        duration: DesignTokens.durationFast,
        child: const Icon(Icons.add),
      ),
      label: const Text('New Service'),
      backgroundColor: DesignTokens.brandAccent,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.room_service_outlined,
              size: 56,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No services yet', style: DesignTokens.textHeadline),
            const SizedBox(height: DesignTokens.spaceXs),
            SizedBox(
              width: 280,
              child: Text(
                'Add services here or sync from your online shop to start selling and booking.',
                textAlign: TextAlign.center,
                style: DesignTokens.textBody.copyWith(
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Service'),
            ),
          ],
        ),
      ),
    );
  }
}
