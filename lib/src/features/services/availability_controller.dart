import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/sync/sync_service.dart';

final availabilityControllerProvider =
    StateNotifierProvider<AvailabilityController, AvailabilityState>((ref) {
      final api = ref.watch(sellerApiProvider);
      final db = ref.watch(appDatabaseProvider);
      final sync = ref.watch(syncServiceProvider);
      return AvailabilityController(api, db, sync)..load();
    });

class AvailabilityState {
  const AvailabilityState({
    this.loading = false,
    this.schedules = const [],
    this.exceptions = const [],
    this.error,
  });

  final bool loading;
  final List<AvailabilitySchedule> schedules;
  final List<AvailabilityException> exceptions;
  final String? error;

  AvailabilityState copyWith({
    bool? loading,
    List<AvailabilitySchedule>? schedules,
    List<AvailabilityException>? exceptions,
    String? error,
  }) => AvailabilityState(
    loading: loading ?? this.loading,
    schedules: schedules ?? this.schedules,
    exceptions: exceptions ?? this.exceptions,
    error: error,
  );
}

class AvailabilityController extends StateNotifier<AvailabilityState> {
  AvailabilityController(this.api, this.db, this.sync)
    : super(const AvailabilityState());

  final SellerApi api;
  final AppDatabase db;
  final SyncService sync;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final schedules = await db.getAllAvailabilitySchedules();
      final exceptions = await db.getAllAvailabilityExceptions();
      state = state.copyWith(loading: false, schedules: schedules, exceptions: exceptions);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Update the weekly schedule for all 7 days.
  /// [schedules] is a list of maps with keys: day_of_week, start_time, end_time, is_available
  Future<void> updateSchedules(List<Map<String, dynamic>> schedules) async {
    state = state.copyWith(loading: true, error: null);
    try {
      // Update local DB
      await db.deleteAllAvailabilitySchedules();
      for (final s in schedules) {
        await db.upsertAvailabilitySchedule(
          AvailabilitySchedulesCompanion.insert(
            dayOfWeek: s['day_of_week'] as int,
            startTime: s['start_time'] as String,
            endTime: s['end_time'] as String,
            isAvailable: Value(s['is_available'] as bool? ?? true),
          ),
        );
      }

      // Queue sync
      await sync.enqueue(
        'availability_update',
        {'schedules': schedules},
      );

      final updated = await db.getAllAvailabilitySchedules();
      state = state.copyWith(loading: false, schedules: updated);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> addException({
    required String date,
    required bool isAvailable,
    String? startTime,
    String? endTime,
    String? reason,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await db.upsertAvailabilityException(
        AvailabilityExceptionsCompanion.insert(
          date: date,
          isAvailable: Value(isAvailable),
          startTime: startTime != null ? Value(startTime) : const Value.absent(),
          endTime: endTime != null ? Value(endTime) : const Value.absent(),
          reason: reason != null ? Value(reason) : const Value.absent(),
        ),
      );

      await sync.enqueue(
        'availability_exception_create',
        {
          'date': date,
          'is_available': isAvailable,
          if (startTime != null) 'start_time': startTime,
          if (endTime != null) 'end_time': endTime,
          if (reason != null) 'reason': reason,
        },
      );

      final updated = await db.getAllAvailabilityExceptions();
      state = state.copyWith(loading: false, exceptions: updated);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> removeException(int id) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final row = await (db.select(db.availabilityExceptions)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      await db.deleteAvailabilityException(id);

      if (row?.remoteId != null) {
        await sync.enqueue(
          'availability_exception_delete',
          {'remote_id': row!.remoteId},
        );
      }

      final updated = await db.getAllAvailabilityExceptions();
      state = state.copyWith(loading: false, exceptions: updated);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  AvailabilitySchedule? getScheduleForDay(int dayOfWeek) {
    try {
      return state.schedules.firstWhere((s) => s.dayOfWeek == dayOfWeek);
    } catch (_) {
      return null;
    }
  }

  AvailabilityException? getExceptionForDate(String dateStr) {
    try {
      return state.exceptions.firstWhere((e) => e.date == dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Generate available time slots for a given date and service duration.
  /// Returns a list of "HH:MM" strings.
  List<String> generateSlotsForDate({
    required String dateStr,
    required int durationMinutes,
    int bufferMinutes = 0,
    List<Map<String, dynamic>> existingBookings = const [],
  }) {
    final date = DateTime.parse(dateStr);
    final dayOfWeek = date.weekday % 7; // Dart: 1=Mon … 7=Sun, convert to 0=Sun … 6=Sat

    final exception = getExceptionForDate(dateStr);
    DateTime? windowStart;
    DateTime? windowEnd;

    if (exception != null) {
      if (!exception.isAvailable) return [];
      if (exception.startTime != null && exception.endTime != null) {
        windowStart = DateTime.parse('$dateStr ${exception.startTime}');
        windowEnd = DateTime.parse('$dateStr ${exception.endTime}');
      }
    } else {
      final schedule = getScheduleForDay(dayOfWeek);
      if (schedule == null || !schedule.isAvailable) return [];
      windowStart = DateTime.parse('$dateStr ${schedule.startTime}');
      windowEnd = DateTime.parse('$dateStr ${schedule.endTime}');
    }

    if (windowStart == null || windowEnd == null) return [];

    final slotInterval = durationMinutes >= 60 ? 60 : 30;
    final slots = <String>[];
    var current = windowStart;

    while (current.add(Duration(minutes: durationMinutes)).isBefore(windowEnd) ||
        current.add(Duration(minutes: durationMinutes)).isAtSameMomentAs(windowEnd)) {
      final slotStart = current;
      final slotEnd = current.add(Duration(minutes: durationMinutes));

      // Skip slots in the past
      if (slotStart.isBefore(DateTime.now())) {
        current = current.add(Duration(minutes: slotInterval));
        continue;
      }

      // Check conflicts with existing bookings
      bool conflict = false;
      for (final b in existingBookings) {
        final bStartStr = b['scheduled_start']?.toString();
        final bEndStr = b['scheduled_end']?.toString();
        if (bStartStr == null || bEndStr == null) continue;
        final bStart = DateTime.tryParse(bStartStr);
        final bEnd = DateTime.tryParse(bEndStr);
        if (bStart == null || bEnd == null) continue;

        final bufferedStart = bStart.subtract(Duration(minutes: bufferMinutes));
        final bufferedEnd = bEnd.add(Duration(minutes: bufferMinutes));

        if (slotStart.isBefore(bufferedEnd) && slotEnd.isAfter(bufferedStart)) {
          conflict = true;
          break;
        }
      }

      if (!conflict) {
        slots.add(
          '${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}',
        );
      }

      current = current.add(Duration(minutes: slotInterval));
    }

    return slots;
  }
}
