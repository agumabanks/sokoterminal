import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../orders/orders_controller.dart';
import '../notifications/notifications_controller.dart';
import '../services/service_bookings_controller.dart';

enum InboxBucket { needsAction, inProgress, completed }
enum InboxType { all, orders, bookings, alerts, stock }

final inboxBucketProvider = StateProvider<InboxBucket>(
  (ref) => InboxBucket.needsAction,
);
final inboxTypeProvider = StateProvider<InboxType>((ref) => InboxType.all);

final cachedOrdersStreamProvider = StreamProvider<List<CachedOrder>>((ref) {
  return ref.watch(appDatabaseProvider).watchCachedOrders();
});

final cachedBookingsStreamProvider =
    StreamProvider<List<CachedServiceBooking>>((ref) {
  return ref.watch(appDatabaseProvider).watchCachedServiceBookings();
});

final pendingSyncOpsStreamProvider = StreamProvider<List<SyncOp>>((ref) {
  return ref.watch(appDatabaseProvider).watchPendingSyncOps();
});

final stockAlertsStreamProvider =
    StreamProvider<List<StockAlertWithItem>>((ref) {
  return ref.watch(appDatabaseProvider).watchOpenStockAlertsWithItem();
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.event('inbox_open'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bucket = ref.watch(inboxBucketProvider);
    final type = ref.watch(inboxTypeProvider);
    final ordersAsync = ref.watch(cachedOrdersStreamProvider);
    final bookingsAsync = ref.watch(cachedBookingsStreamProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final pendingOpsAsync = ref.watch(pendingSyncOpsStreamProvider);
    final stockAlertsAsync = ref.watch(stockAlertsStreamProvider);

    final pendingIds = pendingOpsAsync.maybeWhen(
      data: (ops) => _PendingIds.from(ops),
      orElse: () => const _PendingIds(),
    );

    final items = <_InboxItem>[
      ...ordersAsync.maybeWhen(
        data: (rows) => rows
            .map((r) => _InboxItem.fromOrderJson(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                  pending: pendingIds.pendingOrderIds
                      .contains(r.orderId.toString()),
                ))
            .toList(),
        orElse: () => const [],
      ),
      ...bookingsAsync.maybeWhen(
        data: (rows) => rows
            .map((r) => _InboxItem.fromBookingJson(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                  pending: pendingIds.pendingBookingIds
                      .contains(r.bookingId.toString()),
                ))
            .toList(),
        orElse: () => const [],
      ),
      ...notifications.items.map((n) => _InboxItem.fromNotification(n)),
      ...stockAlertsAsync.maybeWhen(
        data: (rows) => rows
            .map((r) => _InboxItem.fromStockAlert(r))
            .toList(growable: false),
        orElse: () => const [],
      ),
    ];

    final filtered = _filter(items, bucket: bucket, type: type)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Inbox', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final sync = ref.read(syncServiceProvider);
              await sync.syncNow();
              // Warm up notifications.
              await ref.read(notificationsControllerProvider.notifier).load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _BucketChips(
            selected: bucket,
            onSelect: (b) => ref.read(inboxBucketProvider.notifier).state = b,
          ),
          _TypeChips(
            selected: type,
            onSelect: (t) => ref.read(inboxTypeProvider.notifier).state = t,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final sync = ref.read(syncServiceProvider);
                await sync.syncNow();
                await ref.read(notificationsControllerProvider.notifier).load();
              },
              child: filtered.isEmpty
                  ? _EmptyState(bucket: bucket, type: type)
                  : ListView.separated(
                      padding: DesignTokens.paddingScreen,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: DesignTokens.spaceSm),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _InboxTile(item: item);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<_InboxItem> _filter(
    List<_InboxItem> items, {
    required InboxBucket bucket,
    required InboxType type,
  }) {
    var out = items;
    out = out.where((i) => i.bucket == bucket).toList();
    if (type != InboxType.all) {
      out = out.where((i) => i.type == type).toList();
    }
    return out;
  }
}

class _PendingIds {
  const _PendingIds({
    this.pendingOrderIds = const {},
    this.pendingBookingIds = const {},
  });

  final Set<String> pendingOrderIds;
  final Set<String> pendingBookingIds;

  factory _PendingIds.from(List<SyncOp> ops) {
    final orderIds = <String>{};
    final bookingIds = <String>{};
    for (final op in ops) {
      final type = op.opType;
      if (type.startsWith('order_status_update:')) {
        orderIds.add(type.substring('order_status_update:'.length));
      } else if (type.startsWith('booking_action:')) {
        bookingIds.add(type.substring('booking_action:'.length));
      }
    }
    return _PendingIds(pendingOrderIds: orderIds, pendingBookingIds: bookingIds);
  }
}

class _InboxItem {
  const _InboxItem({
    required this.type,
    required this.bucket,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.status,
    this.phone,
    this.pendingSync = false,
    this.notification,
    this.stockAlert,
  });

  final InboxType type;
  final InboxBucket bucket;
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String status;
  final String? phone;
  final bool pendingSync;

  final NotificationDto? notification;
  final StockAlertWithItem? stockAlert;

  static _InboxItem fromOrderJson(
    Map<String, dynamic> order, {
    required bool pending,
  }) {
    final id = order['id']?.toString() ?? '';
    final code = order['order_code']?.toString() ??
        order['code']?.toString() ??
        id;
    final customer = order['customer_name']?.toString() ??
        (order['user'] is Map ? (order['user']['name']?.toString()) : null) ??
        'Customer';
    final phone = order['customer_phone']?.toString() ??
        (order['user'] is Map ? (order['user']['phone']?.toString()) : null);
    final delivery = (order['delivery_status_raw'] ??
            order['delivery_status'] ??
            'pending')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '') ??
        DateTime.tryParse(order['date']?.toString() ?? '') ??
        DateTime.now().toUtc();

    final bucket = _bucketFromOrder(delivery);
    return _InboxItem(
      type: InboxType.orders,
      bucket: bucket,
      id: id,
      title: 'Order $code',
      subtitle: customer,
      timestamp: createdAt.toUtc(),
      status: delivery,
      phone: phone,
      pendingSync: pending || order['pending_sync'] == true,
    );
  }

  static InboxBucket _bucketFromOrder(String status) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return InboxBucket.needsAction;
      case 'packed':
      case 'picked_up':
      case 'on_the_way':
      case 'out_for_delivery':
      case 'processing':
        return InboxBucket.inProgress;
      case 'delivered':
      case 'complete':
      case 'cancelled':
      case 'canceled':
        return InboxBucket.completed;
      default:
        return InboxBucket.needsAction;
    }
  }

  static _InboxItem fromBookingJson(
    Map<String, dynamic> booking, {
    required bool pending,
  }) {
    final id = booking['id']?.toString() ?? '';
    final offeringTitle =
        (booking['offering'] is Map ? (booking['offering']['title']?.toString()) : null) ??
            'Booking';
    final customerName =
        (booking['user'] is Map ? (booking['user']['name']?.toString()) : null) ??
            'Customer';
    final phone =
        (booking['user'] is Map ? (booking['user']['phone']?.toString()) : null);
    final status = (booking['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
    final scheduled = DateTime.tryParse(booking['scheduled_start']?.toString() ?? '');
    final ts = (scheduled ?? DateTime.now().toUtc()).toUtc();

    final bucket = switch (status) {
      'pending' => InboxBucket.needsAction,
      'confirmed' => InboxBucket.inProgress,
      'completed' => InboxBucket.completed,
      'cancelled' => InboxBucket.completed,
      _ => InboxBucket.needsAction,
    };

    return _InboxItem(
      type: InboxType.bookings,
      bucket: bucket,
      id: id,
      title: offeringTitle,
      subtitle: customerName,
      timestamp: ts,
      status: status,
      phone: phone,
      pendingSync: pending || booking['pending_sync'] == true,
    );
  }

  static _InboxItem fromNotification(NotificationDto n) {
    final unread = !n.isRead;
    return _InboxItem(
      type: InboxType.alerts,
      bucket: unread ? InboxBucket.needsAction : InboxBucket.completed,
      id: n.id,
      title: n.title,
      subtitle: n.body,
      timestamp: DateTime.now().toUtc(),
      status: unread ? 'unread' : 'read',
      notification: n,
    );
  }

  static _InboxItem fromStockAlert(StockAlertWithItem row) {
    final item = row.item;
    final alert = row.alert;
    final variant = alert.variant.trim();
    final label = variant.isEmpty ? item.name : '${item.name} • $variant';
    final out = alert.stockQty <= 0;
    final title = out ? 'Out of stock' : 'Low stock';
    final subtitle =
        '$label • Stock ${alert.stockQty} • Reorder at ${alert.threshold}';
    return _InboxItem(
      type: InboxType.stock,
      bucket: alert.acknowledged
          ? InboxBucket.inProgress
          : InboxBucket.needsAction,
      id: '${alert.itemId}::${alert.variant}',
      title: title,
      subtitle: subtitle,
      timestamp: alert.lastTriggeredAt,
      status: out ? 'out_of_stock' : 'low_stock',
      stockAlert: row,
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.item});
  final _InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (item.type) {
      InboxType.orders => Icons.shopping_bag_outlined,
      InboxType.bookings => Icons.event_note_outlined,
      InboxType.alerts => Icons.notifications_outlined,
      InboxType.stock => Icons.inventory_2_outlined,
      InboxType.all => Icons.inbox_outlined,
    };

    final color = switch (item.type) {
      InboxType.orders => DesignTokens.info,
      InboxType.bookings => DesignTokens.brandAccent,
      InboxType.alerts => DesignTokens.grayMedium,
      InboxType.stock => DesignTokens.warning,
      InboxType.all => DesignTokens.brandPrimary,
    };

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
        border: item.pendingSync
            ? Border.all(color: DesignTokens.warning.withValues(alpha: 0.4))
            : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(item.title, style: DesignTokens.textBodyBold),
        subtitle: Text(
          item.subtitle,
          style: DesignTokens.textSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _Actions(item: item),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.item});
  final _InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.type == InboxType.stock) {
      final alertRow = item.stockAlert;
      if (alertRow == null) return const SizedBox.shrink();
      final isAck = alertRow.alert.acknowledged;
      return PopupMenuButton<String>(
        icon: Icon(
          isAck ? Icons.check_circle_outline : Icons.more_horiz,
          color: isAck ? DesignTokens.success : null,
        ),
        itemBuilder: (context) {
          final actions = <PopupMenuEntry<String>>[
            if (!isAck)
              const PopupMenuItem(
                value: 'ack',
                child: Text('Acknowledge'),
              ),
            const PopupMenuItem(
              value: 'open_low_stock',
              child: Text('Open Low Stock'),
            ),
            const PopupMenuItem(
              value: 'receive_stock',
              child: Text('Receive Stock'),
            ),
          ];
          return actions;
        },
        onSelected: (action) async {
          final telemetry = Telemetry.instance;
          if (telemetry != null) {
            unawaited(
              telemetry.event(
                'item_action_taken',
                props: {
                  'type': 'stock',
                  'action': action,
                  'item_id': alertRow.alert.itemId,
                  'variant': alertRow.alert.variant,
                },
              ),
            );
          }

          switch (action) {
            case 'ack':
              await ref.read(appDatabaseProvider).acknowledgeStockAlert(
                    itemId: alertRow.alert.itemId,
                    variant: alertRow.alert.variant,
                  );
              return;
            case 'open_low_stock':
              if (!context.mounted) return;
              ref.read(routerProvider).go('/home/more/low-stock');
              return;
            case 'receive_stock':
              if (!context.mounted) return;
              ref.read(routerProvider).go('/home/more/receive-stock');
              return;
          }
        },
      );
    }

    if (item.type == InboxType.orders) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz),
        itemBuilder: (context) {
          final actions = <String>[
            'confirmed',
            'packed',
            'out_for_delivery',
            'delivered',
            'cancelled',
          ];
          return actions
              .map((a) => PopupMenuItem(
                    value: a,
                    child: Text(a.toUpperCase().replaceAll('_', ' ')),
                  ))
              .toList();
        },
        onSelected: (next) async {
          final id = int.tryParse(item.id);
          if (id == null) return;
          final telemetry = Telemetry.instance;
          if (telemetry != null) {
            unawaited(
              telemetry.event(
                'item_action_taken',
                props: {'type': 'order', 'order_id': id, 'action': next},
              ),
            );
          }
          await ref.read(ordersControllerProvider.notifier).updateStatus(
                orderId: id,
                delivery: next,
                payment: '',
              );
        },
      );
    }

    if (item.type == InboxType.bookings) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz),
        itemBuilder: (context) {
          const actions = <String>['confirm', 'complete', 'cancel'];
          return actions
              .map((a) => PopupMenuItem(value: a, child: Text(a.toUpperCase())))
              .toList();
        },
        onSelected: (action) async {
          final id = int.tryParse(item.id);
          if (id == null) return;
          final telemetry = Telemetry.instance;
          if (telemetry != null) {
            unawaited(
              telemetry.event(
                'item_action_taken',
                props: {'type': 'booking', 'booking_id': id, 'action': action},
              ),
            );
          }
          final controller = ref.read(serviceBookingsControllerProvider.notifier);
          switch (action) {
            case 'confirm':
              await controller.confirm(id);
              break;
            case 'complete':
              await controller.complete(id);
              break;
            case 'cancel':
              await controller.cancel(id);
              break;
          }
        },
      );
    }

    if (item.phone != null && item.phone!.trim().isNotEmpty) {
      return IconButton(
        tooltip: 'WhatsApp',
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: () async {
          final digits = item.phone!.replaceAll(RegExp(r'\\D'), '');
          final uri = Uri.parse('https://wa.me/$digits');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      );
    }

    return item.pendingSync
        ? const Icon(Icons.cloud_upload_outlined, color: DesignTokens.warning)
        : const SizedBox.shrink();
  }
}

class _BucketChips extends StatelessWidget {
  const _BucketChips({required this.selected, required this.onSelect});

  final InboxBucket selected;
  final ValueChanged<InboxBucket> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.surfaceWhite,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceSm,
      ),
      child: Row(
        children: [
          _chip(InboxBucket.needsAction, 'Needs action'),
          const SizedBox(width: 8),
          _chip(InboxBucket.inProgress, 'In progress'),
          const SizedBox(width: 8),
          _chip(InboxBucket.completed, 'Completed'),
        ],
      ),
    );
  }

  Widget _chip(InboxBucket bucket, String label) {
    final isSelected = bucket == selected;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: isSelected,
        onSelected: (_) => onSelect(bucket),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelect});

  final InboxType selected;
  final ValueChanged<InboxType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.surface,
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spaceMd,
        DesignTokens.spaceSm,
        DesignTokens.spaceMd,
        DesignTokens.spaceSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(InboxType.all, 'All'),
            const SizedBox(width: 8),
            _chip(InboxType.orders, 'Orders'),
            const SizedBox(width: 8),
            _chip(InboxType.bookings, 'Bookings'),
            const SizedBox(width: 8),
            _chip(InboxType.stock, 'Stock'),
            const SizedBox(width: 8),
            _chip(InboxType.alerts, 'Alerts'),
          ],
        ),
      ),
    );
  }

  Widget _chip(InboxType type, String label) {
    final isSelected = type == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(type),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.bucket, required this.type});
  final InboxBucket bucket;
  final InboxType type;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: DesignTokens.paddingLg,
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 56, color: DesignTokens.grayMedium),
        const SizedBox(height: 12),
        Text(
          'No items',
          style: DesignTokens.textBodyBold,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Nothing in ${bucket.name} for ${type.name}.',
          style: DesignTokens.textSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
