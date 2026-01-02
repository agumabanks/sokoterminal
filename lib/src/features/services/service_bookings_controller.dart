import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';

final serviceBookingsControllerProvider =
    StateNotifierProvider<ServiceBookingsController, ServiceBookingsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(syncServiceProvider);
  return ServiceBookingsController(api, db, sync)..load();
});

class ServiceBookingsState {
  const ServiceBookingsState({this.loading = false, this.bookings = const [], this.error});
  final bool loading;
  final List<Map<String, dynamic>> bookings;
  final String? error;
}

class ServiceBookingsController extends StateNotifier<ServiceBookingsState> {
  ServiceBookingsController(this.api, this.db, this.sync)
      : super(const ServiceBookingsState());

  final SellerApi api;
  final AppDatabase db;
  final SyncService sync;
  static const _uuid = Uuid();

  Future<void> load() async {
    state = ServiceBookingsState(loading: true, bookings: state.bookings);
    try {
      final res = await api.fetchServiceBookings();
      final data = res.data;
      final listRaw = data is Map<String, dynamic> ? (data['data'] ?? const []) : data;
      final list = List<Map<String, dynamic>>.from(
        (listRaw as Iterable).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      for (final booking in list) {
        final id = int.tryParse(booking['id']?.toString() ?? '');
        if (id == null) continue;
        await db.upsertCachedServiceBooking(id, jsonEncode(booking));
      }

      state = ServiceBookingsState(bookings: list);
    } catch (e) {
      final cachedRows = await db.getCachedServiceBookings();
      if (cachedRows.isNotEmpty) {
        final list = cachedRows
            .map((r) => Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map))
            .toList();
        state = ServiceBookingsState(error: e.toString(), bookings: list);
      } else {
        state = ServiceBookingsState(error: e.toString(), bookings: state.bookings);
      }
    }
  }

  Future<void> confirm(int bookingId) async {
    state = ServiceBookingsState(bookings: state.bookings, loading: true);
    try {
      await api.confirmServiceBooking(bookingId);
      await load();
    } catch (e) {
      await _queueBookingAction(bookingId, action: 'confirm');
      state = ServiceBookingsState(
        error: 'Queued for sync: ${e.toString()}',
        bookings: _optimisticStatus(bookingId, 'confirmed'),
        loading: false,
      );
    }
  }

  Future<void> complete(int bookingId) async {
    state = ServiceBookingsState(bookings: state.bookings, loading: true);
    try {
      await api.completeServiceBooking(bookingId);
      await load();
    } catch (e) {
      await _queueBookingAction(bookingId, action: 'complete');
      state = ServiceBookingsState(
        error: 'Queued for sync: ${e.toString()}',
        bookings: _optimisticStatus(bookingId, 'completed'),
        loading: false,
      );
    }
  }

  Future<void> cancel(int bookingId, {String? reason}) async {
    state = ServiceBookingsState(bookings: state.bookings, loading: true);
    try {
      await api.cancelServiceBooking(bookingId, reason: reason);
      await load();
    } catch (e) {
      await _queueBookingAction(bookingId, action: 'cancel', reason: reason);
      state = ServiceBookingsState(
        error: 'Queued for sync: ${e.toString()}',
        bookings: _optimisticStatus(bookingId, 'cancelled'),
        loading: false,
      );
    }
  }

  Future<void> _queueBookingAction(
    int bookingId, {
    required String action,
    String? reason,
  }) async {
    final opType = 'booking_action:$bookingId';
    await sync.enqueue(opType, {
      'booking_id': bookingId,
      'action': action,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'idempotency_key': _uuid.v4(),
    });
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'booking_action_queued',
          props: {'booking_id': bookingId, 'action': action},
        ),
      );
    }
  }

  List<Map<String, dynamic>> _optimisticStatus(int bookingId, String status) {
    final updated = [
      for (final b in state.bookings)
        if (b['id']?.toString() == bookingId.toString())
          {...b, 'status': status, 'pending_sync': true}
        else
          b
    ];

    final existing = updated.cast<Map<String, dynamic>?>().firstWhere(
          (b) => b?['id']?.toString() == bookingId.toString(),
          orElse: () => null,
        );
    if (existing != null) {
      unawaited(db.upsertCachedServiceBooking(bookingId, jsonEncode(existing)));
    }
    return updated;
  }

  Future<void> pullCached() async {
    final cachedRows = await db.getCachedServiceBookings();
    if (cachedRows.isEmpty) return;
    final list = cachedRows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r.payloadJson) as Map))
        .toList();
    state = ServiceBookingsState(bookings: list, loading: false);
  }
}
