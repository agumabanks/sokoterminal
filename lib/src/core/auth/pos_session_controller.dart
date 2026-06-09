import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';
import '../db/app_database.dart';
import '../network/seller_api.dart';
import '../storage/secure_storage.dart';
import '../sync/sync_service.dart';
import 'pin_hash_service.dart';
import 'pos_staff_prefs.dart';

class PosSessionState {
  const PosSessionState({
    this.token,
    this.expiresAt,
    this.staffId,
    this.staffName,
    this.staffRole,
    this.loading = false,
    this.error,
  });

  final String? token;
  final DateTime? expiresAt;
  final int? staffId;
  final String? staffName;
  final String? staffRole; // cashier | manager
  final bool loading;
  final String? error;

  bool get isActive {
    if (token == null || token!.trim().isEmpty) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }
  bool get isManager => (staffRole ?? '').toLowerCase() == 'manager';

  PosSessionState copyWith({
    String? token,
    DateTime? expiresAt,
    int? staffId,
    String? staffName,
    String? staffRole,
    bool? loading,
    String? error,
  }) {
    return PosSessionState(
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      staffRole: staffRole ?? this.staffRole,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  static const empty = PosSessionState();
}

final posSessionProvider =
    StateNotifierProvider<PosSessionController, PosSessionState>((ref) {
      final storage = ref.watch(secureStorageProvider);
      final api = ref.watch(sellerApiProvider);
      final db = ref.watch(appDatabaseProvider);
      final sync = ref.watch(syncServiceProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      return PosSessionController(
        storage: storage,
        api: api,
        db: db,
        syncService: sync,
        prefs: prefs,
        pinHash: PinHashService(storage: storage),
      )..load();
    });

class PosSessionController extends StateNotifier<PosSessionState> {
  PosSessionController({
    required SecureStorage storage,
    required SellerApi api,
    required AppDatabase db,
    required SyncService syncService,
    required SharedPreferences prefs,
    required PinHashService pinHash,
  }) : _storage = storage,
       _api = api,
       _db = db,
       _sync = syncService,
       _prefs = prefs,
       _pinHash = pinHash,
       super(PosSessionState.empty);

  final SecureStorage _storage;
  final SellerApi _api;
  final AppDatabase _db;
  final SyncService _sync;
  final SharedPreferences _prefs;
  final PinHashService _pinHash;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final token = await _storage.readPosSessionToken();
    final cachedStaffId = await _storage.readPosSessionStaffId();
    final cachedStaffName = await _storage.readPosSessionStaffName();
    final cachedStaffRole = await _storage.readPosSessionStaffRole();
    final cachedExpiresAt = await _storage.readPosSessionExpiresAt();

    // Offline sessions bypass backend validation
    if (token != null && token.startsWith('OFFLINE_')) {
      state = PosSessionState(
        token: token,
        expiresAt: cachedExpiresAt,
        staffId: cachedStaffId,
        staffName: cachedStaffName,
        staffRole: cachedStaffRole,
        loading: false,
      );
      return;
    }

    try {
      final res = await _api.posSessionMe();
      final data = res.data;
      if (data is! Map) {
        if (token == null || token.trim().isEmpty) {
          state = PosSessionState.empty;
          return;
        }
        state = PosSessionState(
          token: token,
          expiresAt: cachedExpiresAt,
          staffId: cachedStaffId,
          staffName: cachedStaffName,
          staffRole: cachedStaffRole,
        );
        await _upsertCachedStaff(cachedStaffId, cachedStaffName);
        return;
      }
      final map = Map<String, dynamic>.from(data);
      final staffInitialized = map['staff_initialized'];
      if (staffInitialized is bool) {
        await _prefs.setBool(posStaffInitializedPrefKey, staffInitialized);
      } else if (staffInitialized is num) {
        await _prefs.setBool(posStaffInitializedPrefKey, staffInitialized != 0);
      }

      final active = map['active'] == true || map['active'] == 1;
      if (!active) {
        if (token == null || token.trim().isEmpty) {
          state = PosSessionState.empty;
          return;
        }
        await _storage.deletePosSessionToken();
        await _storage.deletePosSessionMeta();
        state = PosSessionState.empty;
        return;
      }
      final expiresAt = DateTime.tryParse(map['expires_at']?.toString() ?? '');
      final staff = map['staff'];
      final staffMap = staff is Map ? Map<String, dynamic>.from(staff) : null;
      final staffId = _asNullableInt(staffMap?['id']);
      final staffName = staffMap?['name']?.toString();
      final staffRole = staffMap?['role']?.toString();

      state = PosSessionState(
        token: token,
        expiresAt: expiresAt,
        staffId: staffId,
        staffName: staffName,
        staffRole: staffRole,
        loading: false,
      );

      if (staffId != null && staffName != null && staffRole != null) {
        await _storage.writePosSessionMeta(
          staffId: staffId,
          staffName: staffName,
          staffRole: staffRole,
          expiresAt: expiresAt,
        );
        await _storage.writePosStaffRole(staffId, staffRole);
        await _upsertLocalStaff(
          staffId: staffId,
          staffName: staffName,
        );
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _storage.deletePosSessionToken();
        await _storage.deletePosSessionMeta();
        state = PosSessionState.empty;
        return;
      }
      // Best-effort: keep the token (offline) but avoid blocking the UI.
      if (token == null || token.trim().isEmpty) {
        state = PosSessionState.empty;
        return;
      }
      state = PosSessionState(
        token: token,
        expiresAt: cachedExpiresAt,
        staffId: cachedStaffId,
        staffName: cachedStaffName,
        staffRole: cachedStaffRole,
      );
      await _upsertCachedStaff(cachedStaffId, cachedStaffName);
    } catch (e) {
      // Non-network/storage parsing failures should not block the UI.
      debugPrint('[PosSession] load failed: $e');
      if (token == null || token.trim().isEmpty) {
        state = PosSessionState.empty;
        return;
      }
      state = PosSessionState(
        token: token,
        expiresAt: cachedExpiresAt,
        staffId: cachedStaffId,
        staffName: cachedStaffName,
        staffRole: cachedStaffRole,
      );
      await _upsertCachedStaff(cachedStaffId, cachedStaffName);
    }
  }

  Future<bool> startWithPin(String pin, {String? requiredRole}) async {
    final trimmed = pin.trim();
    if (trimmed.isEmpty) return false;

    final prevState = state;
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.startPosSession(pin: trimmed);
      final data = res.data;
      if (data is! Map) {
        state = prevState.copyWith(
          loading: false,
          error: 'Invalid session response',
        );
        return false;
      }

      final map = Map<String, dynamic>.from(data);
      final token = map['token']?.toString();
      if (token == null || token.trim().isEmpty) {
        state = prevState.copyWith(loading: false, error: 'Missing token');
        return false;
      }

      final expiresAt = DateTime.tryParse(map['expires_at']?.toString() ?? '');
      final staff = map['staff'];
      final staffMap = staff is Map ? Map<String, dynamic>.from(staff) : null;
      final staffRole = staffMap?['role']?.toString();
      final staffName = staffMap?['name']?.toString();
      final staffId = _asNullableInt(staffMap?['id']);

      if (requiredRole != null &&
          (staffRole ?? '').toLowerCase() != requiredRole.toLowerCase()) {
        state = prevState.copyWith(
          loading: false,
          error: 'This action requires a $requiredRole PIN.',
        );
        return false;
      }

      await _storage.writePosSessionToken(token);
      await _prefs.setBool(posStaffInitializedPrefKey, true);
      if (staffId != null && staffName != null && staffRole != null) {
        await _storage.writePosSessionMeta(
          staffId: staffId,
          staffName: staffName,
          staffRole: staffRole,
          expiresAt: expiresAt,
        );
        await _storage.writePosStaffRole(staffId, staffRole);
        final hashedPin = await _pinHash.hash(trimmed);
        await _upsertLocalStaff(
          staffId: staffId,
          staffName: staffName,
          pin: hashedPin,
        );
      }

      state = PosSessionState(
        token: token,
        expiresAt: expiresAt,
        staffId: staffId,
        staffName: staffName,
        staffRole: staffRole,
        loading: false,
      );

      unawaited(_retryRecoverableBlockedOps());
      unawaited(_sync.syncNow());
      return true;
    } on DioException catch (e) {
      // Offline fallback: verify against locally cached staff PIN
      final isOffline =
          e.response == null ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown;
      if (isOffline) {
        final hashedPin = await _pinHash.hash(trimmed);
        final localStaff = await _db.getStaffByPin(hashedPin);
        if (localStaff != null) {
          final staffId = int.tryParse(localStaff.id);
          final staffName = localStaff.name;
          final staffRole =
              staffId != null
                  ? await _storage.readPosStaffRole(staffId)
                  : null;
          final resolvedRole = staffRole ?? 'cashier';

          if (requiredRole != null &&
              resolvedRole.toLowerCase() != requiredRole.toLowerCase()) {
            state = prevState.copyWith(
              loading: false,
              error: 'This action requires a $requiredRole PIN.',
            );
            return false;
          }

          final offlineToken =
              'OFFLINE_${localStaff.id}_${DateTime.now().millisecondsSinceEpoch}';
          if (staffId != null) {
            await _storage.writePosSessionToken(offlineToken);
            await _storage.writePosSessionMeta(
              staffId: staffId,
              staffName: staffName,
              staffRole: resolvedRole,
              expiresAt: null,
            );
          }

          state = PosSessionState(
            token: offlineToken,
            staffId: staffId,
            staffName: staffName,
            staffRole: resolvedRole,
            loading: false,
          );
          return true;
        }
      }

      state = prevState.copyWith(
        loading: false,
        error: _extractErrorMessage(e),
      );
      return false;
    } catch (e) {
      state = prevState.copyWith(
        loading: false,
        error: _extractErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> end() async {
    final token = state.token;
    state = state.copyWith(loading: true, error: null);
    try {
      if (token != null && token.trim().isNotEmpty) {
        await _api.endPosSession();
      }
    } catch (e) {
      debugPrint('[PosSession] end session API call failed: $e');
      // Best effort.
    } finally {
      await _storage.deletePosSessionToken();
      await _storage.deletePosSessionMeta();
      state = PosSessionState.empty;
    }
  }

  Future<void> clearLocal() async {
    await _storage.deletePosSessionToken();
    await _storage.deletePosSessionMeta();
    state = PosSessionState.empty;
  }

  Future<void> _upsertLocalStaff({
    required int staffId,
    required String staffName,
    String? pin,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.upsertStaff(
      StaffCompanion.insert(
        id: drift.Value(staffId.toString()),
        name: staffName,
        pin:
            pin == null
                ? const drift.Value.absent()
                : drift.Value(pin),
        roleId: const drift.Value.absent(),
        active: const drift.Value(true),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> _upsertCachedStaff(int? staffId, String? staffName) async {
    if (staffId == null) return;
    final name = (staffName ?? '').trim();
    if (name.isEmpty) return;
    await _upsertLocalStaff(staffId: staffId, staffName: name);
  }

  Future<void> _retryRecoverableBlockedOps() async {
    final blocked = await _db.blockedSyncOps();
    for (final op in blocked) {
      final err = (op.lastError ?? '').toLowerCase();
      final isSessionIssue =
          err.contains('pos session required') ||
          err.contains('manager pos session required') ||
          err.contains('invalid or expired pos session') ||
          err.contains('x-pos-session');
      if (!isSessionIssue) continue;
      await _db.retrySyncOpNow(op.id);
    }
  }

  int? _asNullableInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final message = map['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        final errors = map['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              final text = value.first.toString().trim();
              if (text.isNotEmpty) return text;
            }
          }
        }
      }
      final fallback = error.message?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.substring('Exception:'.length).trim();
    }
    return raw.isEmpty ? 'Sign in failed.' : raw;
  }
}
