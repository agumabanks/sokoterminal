import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import 'notifications_controller.dart';

/// Notification category for filtering
enum NotificationCategory { all, orders, payments, stock, system }

/// Provider for selected category filter
final selectedCategoryProvider = StateProvider<NotificationCategory>((ref) => NotificationCategory.all);

final lowStockAlertsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(appDatabaseProvider).watchItems();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final lowStockItemsAsync = ref.watch(lowStockAlertsProvider);
    final lowStockCount = lowStockItemsAsync.maybeWhen(
      data: (items) => items.where((i) {
        final threshold = i.lowStockWarning ?? 5;
        return i.stockEnabled && i.stockQty <= threshold;
      }).length,
      orElse: () => 0,
    );
    
    // Filter notifications by category
    final filteredItems = _filterByCategory(state.items, selectedCategory);
    final unreadCounts = _getUnreadCounts(state.items);
    unreadCounts[NotificationCategory.stock] =
        (unreadCounts[NotificationCategory.stock] ?? 0) + lowStockCount;
    
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Alerts', style: DesignTokens.textTitle),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Read All'),
              onPressed: () => controller.markAllRead(),
            ),
          IconButton(
            icon: state.loading 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh),
            onPressed: state.loading ? null : () => controller.load(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary / Stats bar
          _StatsSummary(state: state, stockAlertsCount: lowStockCount),
          
          // Category filter chips
          _CategoryFilter(
            selected: selectedCategory,
            unreadCounts: unreadCounts,
            onSelect: (cat) => ref.read(selectedCategoryProvider.notifier).state = cat,
          ),
          
          // Notifications list
          Expanded(
            child: selectedCategory == NotificationCategory.stock
                ? lowStockItemsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _EmptyState(
                      category: selectedCategory,
                      error: e.toString(),
                    ),
                    data: (items) {
                      final low = items.where((i) {
                        final threshold = i.lowStockWarning ?? 5;
                        return i.stockEnabled && i.stockQty <= threshold;
                      }).toList()
                        ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

                      return RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(syncServiceProvider).syncNow();
                          await controller.load();
                        },
                        child: low.isEmpty
                            ? _EmptyState(category: selectedCategory, error: state.error)
                            : ListView.separated(
                                padding: DesignTokens.paddingScreen,
                                itemCount: low.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: DesignTokens.spaceSm),
                                itemBuilder: (context, index) {
                                  final item = low[index];
                                  final threshold = item.lowStockWarning ?? 5;
                                  final outOfStock = item.stockQty <= 0;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: DesignTokens.surfaceWhite,
                                      borderRadius: DesignTokens.borderRadiusMd,
                                      boxShadow: DesignTokens.shadowSm,
                                      border: Border.all(
                                        color: outOfStock
                                            ? DesignTokens.error.withValues(alpha: 0.35)
                                            : DesignTokens.warning.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: outOfStock
                                            ? DesignTokens.error
                                            : DesignTokens.warning,
                                        child: Icon(
                                          outOfStock
                                              ? Icons.inventory_2_outlined
                                              : Icons.warning_amber_outlined,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(item.name, style: DesignTokens.textBodyBold),
                                      subtitle: Text(
                                        outOfStock
                                            ? 'Out of stock • Reorder at $threshold'
                                            : 'Stock ${item.stockQty} • Reorder at $threshold',
                                        style: DesignTokens.textSmall,
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => context.go('/home/more/low-stock'),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  )
                : state.loading && state.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => controller.load(),
                        child: filteredItems.isEmpty
                            ? _EmptyState(
                                category: selectedCategory,
                                error: state.error,
                              )
                            : ListView.builder(
                                padding: DesignTokens.paddingScreen,
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return _NotificationCard(
                                    notification: item,
                                    onTap: () =>
                                        _handleTap(context, controller, item),
                                    onDismiss: () =>
                                        _handleDelete(context, controller, item),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  List<NotificationDto> _filterByCategory(List<NotificationDto> items, NotificationCategory category) {
    if (category == NotificationCategory.all) return items;
    return items.where((item) => _getCategory(item) == category).toList();
  }

  Map<NotificationCategory, int> _getUnreadCounts(List<NotificationDto> items) {
    final counts = <NotificationCategory, int>{};
    for (final item in items.where((i) => !i.isRead)) {
      final cat = _getCategory(item);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  static NotificationCategory _getCategory(NotificationDto notification) {
    final title = notification.title.toLowerCase();
    final body = notification.body.toLowerCase();
    final type = notification.data['type']?.toString().toLowerCase() ?? '';
    
    if (title.contains('order') || body.contains('order') || type.contains('order')) {
      return NotificationCategory.orders;
    }
    if (title.contains('payment') || body.contains('payment') || 
        title.contains('paid') || body.contains('paid') ||
        type.contains('payment')) {
      return NotificationCategory.payments;
    }
    if (title.contains('stock') || body.contains('stock') || 
        title.contains('inventory') || body.contains('inventory') ||
        type.contains('stock') || type.contains('inventory')) {
      return NotificationCategory.stock;
    }
    return NotificationCategory.system;
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationsController controller,
    NotificationDto notification,
  ) async {
    if (!notification.isRead) {
      await controller.markRead(notification.id);
    }
    final link = notification.data['link']?.toString();
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    controller.handleTap(notification);
  }

  Future<void> _handleDelete(
    BuildContext context,
    NotificationsController controller,
    NotificationDto notification,
  ) async {
    await controller.deleteNotification(notification.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.load(), // Reload to restore
        ),
      ),
    );
  }
}

/// Stats summary at the top
class _StatsSummary extends StatelessWidget {
  const _StatsSummary({required this.state, required this.stockAlertsCount});
  final NotificationsState state;
  final int stockAlertsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        gradient: DesignTokens.brandGradient,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.notifications_active,
              value: '${state.unreadCount}',
              label: 'Unread',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _StatItem(
              icon: Icons.inventory_2_outlined,
              value: '$stockAlertsCount',
              label: 'Stock',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _StatItem(
              icon: Icons.inbox,
              value: '${state.items.length}',
              label: 'Total',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: DesignTokens.textBodyBold.copyWith(color: Colors.white)),
            Text(label, style: DesignTokens.textSmall.copyWith(color: Colors.white70)),
          ],
        ),
      ],
    );
  }
}

/// Category filter chips
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.unreadCounts,
    required this.onSelect,
  });
  
  final NotificationCategory selected;
  final Map<NotificationCategory, int> unreadCounts;
  final ValueChanged<NotificationCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd, vertical: 8),
        children: NotificationCategory.values.map((cat) {
          final isSelected = cat == selected;
          final unread = unreadCounts[cat] ?? 0;
          final totalUnread = unreadCounts.values.fold<int>(0, (a, b) => a + b);
          
          return Padding(
            padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getCategoryIcon(cat), size: 16, color: isSelected ? Colors.white : DesignTokens.grayMedium),
                  const SizedBox(width: 4),
                  Text(_getCategoryLabel(cat)),
                  if ((cat == NotificationCategory.all ? totalUnread : unread) > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white24 : DesignTokens.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cat == NotificationCategory.all ? totalUnread : unread}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onSelect(cat),
              selectedColor: DesignTokens.brandPrimary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : DesignTokens.grayDark),
              checkmarkColor: Colors.white,
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getCategoryLabel(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.all: return 'All';
      case NotificationCategory.orders: return 'Orders';
      case NotificationCategory.payments: return 'Payments';
      case NotificationCategory.stock: return 'Stock';
      case NotificationCategory.system: return 'System';
    }
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.all: return Icons.inbox;
      case NotificationCategory.orders: return Icons.shopping_bag_outlined;
      case NotificationCategory.payments: return Icons.payment;
      case NotificationCategory.stock: return Icons.inventory_2_outlined;
      case NotificationCategory.system: return Icons.settings;
    }
  }
}

/// Enhanced notification card with swipe to delete
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });
  
  final NotificationDto notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final category = NotificationsScreen._getCategory(notification);
    final categoryColor = _getCategoryColor(category);
    final isUnread = !notification.isRead;
    
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: DesignTokens.error,
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
        decoration: BoxDecoration(
          color: isUnread 
              ? DesignTokens.surfaceWhite 
              : DesignTokens.surfaceWhite.withValues(alpha: 0.7),
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: isUnread ? DesignTokens.shadowSm : [],
          border: Border.all(
            color: isUnread 
                ? categoryColor.withValues(alpha: 0.4) 
                : DesignTokens.grayLight,
            width: isUnread ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: DesignTokens.borderRadiusMd,
          child: Padding(
            padding: DesignTokens.paddingMd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: DesignTokens.borderRadiusSm,
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title.isEmpty ? 'Notification' : notification.title,
                              style: DesignTokens.textBodyBold.copyWith(
                                color: isUnread ? DesignTokens.grayDark : DesignTokens.grayMedium,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: categoryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: DesignTokens.textSmall.copyWith(
                          color: isUnread ? DesignTokens.grayDark : DesignTokens.grayMedium,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: DesignTokens.grayMedium),
                          const SizedBox(width: 4),
                          Text(
                            DateTime.tryParse(notification.dateLabel)?.toRelativeLabel() ?? notification.dateLabel,
                            style: DesignTokens.textSmall.copyWith(
                              color: DesignTokens.grayMedium,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getCategoryLabel(category),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: DesignTokens.grayLight,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.all: return DesignTokens.brandPrimary;
      case NotificationCategory.orders: return DesignTokens.info;
      case NotificationCategory.payments: return DesignTokens.success;
      case NotificationCategory.stock: return DesignTokens.warning;
      case NotificationCategory.system: return DesignTokens.grayMedium;
    }
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.all: return Icons.notifications;
      case NotificationCategory.orders: return Icons.shopping_bag;
      case NotificationCategory.payments: return Icons.payment;
      case NotificationCategory.stock: return Icons.inventory_2;
      case NotificationCategory.system: return Icons.info_outline;
    }
  }

  String _getCategoryLabel(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.all: return 'All';
      case NotificationCategory.orders: return 'Order';
      case NotificationCategory.payments: return 'Payment';
      case NotificationCategory.stock: return 'Stock';
      case NotificationCategory.system: return 'System';
    }
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.category, this.error});
  final NotificationCategory category;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: DesignTokens.paddingLg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getEmptyIcon(),
              size: 40,
              color: DesignTokens.grayMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            _getEmptyTitle(),
            style: DesignTokens.textBodyBold,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            _getEmptySubtitle(),
            style: DesignTokens.textSmall,
            textAlign: TextAlign.center,
          ),
          if (error != null) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Text(
                error!,
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (category) {
      case NotificationCategory.all: return Icons.notifications_none;
      case NotificationCategory.orders: return Icons.shopping_bag_outlined;
      case NotificationCategory.payments: return Icons.payment;
      case NotificationCategory.stock: return Icons.inventory_2_outlined;
      case NotificationCategory.system: return Icons.settings_outlined;
    }
  }

  String _getEmptyTitle() {
    switch (category) {
      case NotificationCategory.all: return 'No notifications yet';
      case NotificationCategory.orders: return 'No order alerts';
      case NotificationCategory.payments: return 'No payment alerts';
      case NotificationCategory.stock: return 'No stock alerts';
      case NotificationCategory.system: return 'No system alerts';
    }
  }

  String _getEmptySubtitle() {
    switch (category) {
      case NotificationCategory.all: return 'When you receive notifications, they will appear here';
      case NotificationCategory.orders: return 'Order updates and new orders will appear here';
      case NotificationCategory.payments: return 'Payment confirmations will appear here';
      case NotificationCategory.stock: return 'Low stock and inventory alerts will appear here';
      case NotificationCategory.system: return 'System updates and announcements will appear here';
    }
  }
}
