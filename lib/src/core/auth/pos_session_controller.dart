import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_providers.dart';
import '../db/app_database.dart';
import '../network/seller_api.dart';
import '../storage/secure_storage.dart';
import '../sync/sync_service.dart';
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

  bool get isActive => token != null && token!.trim().isNotEmpty;
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
  )..load();
});

class PosSessionController extends StateNotifier<PosSessionState> {
  PosSessionController({
    required SecureStorage storage,
    required SellerApi api,
    required AppDatabase db,
    required SyncService syncService,
    required SharedPreferences prefs,
  })  : _storage = storage,
        _api = api,
        _db = db,
        _sync = syncService,
        _prefs = prefs,
        super(PosSessionState.empty);

  final SecureStorage _storage;
  final SellerApi _api;
  final AppDatabase _db;
  final SyncService _sync;
  final SharedPreferences _prefs;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final token = await _storage.readPosSessionToken();
    final cachedStaffId = await _storage.readPosSessionStaffId();
    final cachedStaffName = await _storage.readPosSessionStaffName();
    final cachedStaffRole = await _storage.readPosSessionStaffRole();
    final cachedExpiresAt = await _storage.readPosSessionExpiresAt();
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
        await _upsertLocalStaff(
          staffId: staffId,
          staffName: staffName,
        );
      }
    } catch (_) {
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
        state =
            prevState.copyWith(loading: false, error: 'Invalid session response');
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
        await _upsertLocalStaff(staffId: staffId, staffName: staffName);
      }

      state = PosSessionState(
        token: token,
        expiresAt: expiresAt,
        staffId: staffId,
        staffName: staffName,
        staffRole: staffRole,
        loading: false,
      );

      // If the user just fixed a missing/expired session, retry blocked ops that
      // are recoverable by re-authenticating a POS session.
      unawaited(_retryRecoverableBlockedOps());
      unawaited(_sync.syncNow());
      return true;
    } catch (e) {
      state = prevState.copyWith(loading: false, error: e.toString());
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
    } catch (_) {
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
  }) async {
    final now = DateTime.now().toUtc();
    await _db.upsertStaff(
      StaffCompanion.insert(
        id: drift.Value(staffId.toString()),
        name: staffName,
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
}
