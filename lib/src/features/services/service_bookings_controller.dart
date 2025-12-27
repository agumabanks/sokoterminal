import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';

final serviceBookingsControllerProvider =
    StateNotifierProvider<ServiceBookingsController, ServiceBookingsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  final db = ref.watch(appDatabaseProvider);
  return ServiceBookingsController(api, db)..load();
});

class ServiceBookingsState {
  const ServiceBookingsState({this.loading = false, this.bookings = const [], this.error});
  final bool loading;
  final List<Map<String, dynamic>> bookings;
  final String? error;
}

class ServiceBookingsController extends StateNotifier<ServiceBookingsState> {
  ServiceBookingsController(this.api, this.db) : super(const ServiceBookingsState());

  final SellerApi api;
  final AppDatabase db;

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
      state = ServiceBookingsState(error: e.toString(), bookings: state.bookings);
    }
  }

  Future<void> complete(int bookingId) async {
    state = ServiceBookingsState(bookings: state.bookings, loading: true);
    try {
      await api.completeServiceBooking(bookingId);
      await load();
    } catch (e) {
      state = ServiceBookingsState(error: e.toString(), bookings: state.bookings);
    }
  }

  Future<void> cancel(int bookingId, {String? reason}) async {
    state = ServiceBookingsState(bookings: state.bookings, loading: true);
    try {
      await api.cancelServiceBooking(bookingId, reason: reason);
      await load();
    } catch (e) {
      state = ServiceBookingsState(error: e.toString(), bookings: state.bookings);
    }
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

