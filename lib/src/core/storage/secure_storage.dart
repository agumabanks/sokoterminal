import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Health snapshot for a single secure-storage key.
class SecureStorageKeyHealth {
  SecureStorageKeyHealth({
    required this.key,
    required this.readFailures,
    required this.writeFailures,
    required this.lastError,
  });

  final String key;
  final int readFailures;
  final int writeFailures;
  final String? lastError;

  bool get isHealthy => readFailures == 0 && writeFailures == 0;
}

/// Overall health report for secure storage.
class SecureStorageHealth {
  SecureStorageHealth({
    required this.keys,
    required this.globalFailureCount,
    required this.isHealthy,
  });

  final List<SecureStorageKeyHealth> keys;
  final int globalFailureCount;
  final bool isHealthy;
}

class SecureStorage {
  SecureStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _maxRetries = 3;
  int _consecutiveFailures = 0;

  // In-memory fallback for critical tokens when secure storage fails.
  // This prevents users from being locked out on devices with Keystore issues.
  final _memoryFallback = <String, String>{};

  // Per-key failure tracking for diagnostics.
  final _readFailures = <String, int>{};
  final _writeFailures = <String, int>{};
  final _lastErrors = <String, String>{};

  void _recordFailure(Object error, {required String key, required bool isWrite}) {
    _consecutiveFailures++;
    final errorText = error.toString();
    if (isWrite) {
      _writeFailures[key] = (_writeFailures[key] ?? 0) + 1;
    } else {
      _readFailures[key] = (_readFailures[key] ?? 0) + 1;
    }
    _lastErrors[key] = errorText;
    debugPrint(
      '[SecureStorage] operation failed ($_consecutiveFailures) for $key: $errorText',
    );
  }

  void _recordSuccess(String key) {
    _consecutiveFailures = 0;
    _readFailures.remove(key);
    _writeFailures.remove(key);
    _lastErrors.remove(key);
  }

  Future<void> _safeWrite(String key, String value) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.write(key: key, value: value);
        _recordSuccess(key);
        // Update memory fallback on successful write.
        _memoryFallback[key] = value;
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          _recordFailure(e, key: key, isWrite: true);
          // Fallback: keep in memory so the session survives the operation.
          _memoryFallback[key] = value;
        }
      }
    }
  }

  Future<String?> _safeRead(String key) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _storage.read(key: key);
        _recordSuccess(key);
        if (result != null) {
          _memoryFallback[key] = result;
        }
        return result;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          _recordFailure(e, key: key, isWrite: false);
          // Fallback: return memory value if available.
          final fallback = _memoryFallback[key];
          if (fallback != null) {
            debugPrint(
              '[SecureStorage] Returning memory fallback for $key',
            );
          }
          return fallback;
        }
      }
    }
    return _memoryFallback[key];
  }

  Future<void> _safeDelete(String key) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.delete(key: key);
        _recordSuccess(key);
        _memoryFallback.remove(key);
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          _recordFailure(e, key: key, isWrite: true);
          _memoryFallback.remove(key);
        }
      }
    }
  }

  Future<void> _safeDeleteAll() async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.deleteAll();
        _recordSuccess('all');
        _memoryFallback.clear();
        _readFailures.clear();
        _writeFailures.clear();
        _lastErrors.clear();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          _recordFailure(e, key: 'all', isWrite: true);
          _memoryFallback.clear();
        }
      }
    }
  }

  // ── Token helpers ────────────────────────────────────────────────────────

  Future<void> writeAccessToken(String token) =>
      _safeWrite('access_token', token);
  Future<String?> readAccessToken() => _safeRead('access_token');
  Future<void> deleteAccessToken() => _safeDelete('access_token');

  Future<void> writeLastLoginPhone(String phone) =>
      _safeWrite('last_login_phone', phone);
  Future<String?> readLastLoginPhone() => _safeRead('last_login_phone');

  // Unique seller identity (UUID)
  Future<void> writeSellerUUID(String uuid) => _safeWrite('seller_uuid', uuid);
  Future<String?> readSellerUUID() => _safeRead('seller_uuid');

  // Numeric seller ID for owner comparison
  Future<void> writeSellerId(String id) => _safeWrite('seller_id', id);
  Future<String?> readSellerId() => _safeRead('seller_id');

  Future<void> writeSellerQuickPin(String pin) =>
      _safeWrite('seller_quick_pin', pin);
  Future<String?> readSellerQuickPin() => _safeRead('seller_quick_pin');

  Future<void> writeSellerQuickPassword(String password) =>
      _safeWrite('seller_quick_password', password);
  Future<String?> readSellerQuickPassword() =>
      _safeRead('seller_quick_password');

  Future<void> writeSellerQuickPhone(String phone) =>
      _safeWrite('seller_quick_phone', phone);
  Future<String?> readSellerQuickPhone() => _safeRead('seller_quick_phone');

  Future<void> clearSellerQuickLogin() async {
    await Future.wait([
      _safeDelete('seller_quick_phone'),
      _safeDelete('seller_quick_password'),
      _safeDelete('seller_quick_pin'),
    ]);
  }

  Future<void> writePin(String pin) => _safeWrite('staff_pin', pin);
  Future<String?> readPin() => _safeRead('staff_pin');
  Future<void> deletePin() => _safeDelete('staff_pin');

  // POS staff session (server-side RBAC)
  Future<void> writePosSessionToken(String token) =>
      _safeWrite('pos_session_token', token);
  Future<String?> readPosSessionToken() => _safeRead('pos_session_token');
  Future<void> deletePosSessionToken() => _safeDelete('pos_session_token');

  Future<void> writePinHashSalt(String salt) => _safeWrite('pin_hash_salt', salt);
  Future<String?> readPinHashSalt() => _safeRead('pin_hash_salt');

  Future<void> writePosStaffRole(int staffId, String role) =>
      _safeWrite('pos_staff_role_$staffId', role);
  Future<String?> readPosStaffRole(int staffId) =>
      _safeRead('pos_staff_role_$staffId');
  Future<void> deletePosStaffRole(int staffId) =>
      _safeDelete('pos_staff_role_$staffId');

  Future<void> writePosSessionMeta({
    required int staffId,
    required String staffName,
    required String staffRole,
    DateTime? expiresAt,
  }) async {
    await Future.wait([
      _safeWrite('pos_session_staff_id', staffId.toString()),
      _safeWrite('pos_session_staff_name', staffName),
      _safeWrite('pos_session_staff_role', staffRole),
      if (expiresAt != null)
        _safeWrite(
          'pos_session_expires_at',
          expiresAt.toUtc().toIso8601String(),
        )
      else
        _safeDelete('pos_session_expires_at'),
    ]);
  }

  Future<int?> readPosSessionStaffId() async {
    final raw = await _safeRead('pos_session_staff_id');
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  Future<String?> readPosSessionStaffName() =>
      _safeRead('pos_session_staff_name');

  Future<String?> readPosSessionStaffRole() =>
      _safeRead('pos_session_staff_role');

  Future<DateTime?> readPosSessionExpiresAt() async {
    final raw = await _safeRead('pos_session_expires_at');
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim())?.toUtc();
  }

  Future<void> deletePosSessionMeta() async {
    await Future.wait([
      _safeDelete('pos_session_staff_id'),
      _safeDelete('pos_session_staff_name'),
      _safeDelete('pos_session_staff_role'),
      _safeDelete('pos_session_expires_at'),
    ]);
  }

  Future<void> write({required String key, required String value}) =>
      _safeWrite(key, value);
  Future<String?> read({required String key}) => _safeRead(key);
  Future<void> delete({required String key}) => _safeDelete(key);

  Future<void> clearAll() => _safeDeleteAll();

  // ── Health diagnostics ───────────────────────────────────────────────────

  /// Returns a health report showing which keys have failed and how many times.
  SecureStorageHealth checkHealth() {
    final allKeys = <String>{
      ..._readFailures.keys,
      ..._writeFailures.keys,
      ..._lastErrors.keys,
    };

    final keyHealth = allKeys.map((key) {
      return SecureStorageKeyHealth(
        key: key,
        readFailures: _readFailures[key] ?? 0,
        writeFailures: _writeFailures[key] ?? 0,
        lastError: _lastErrors[key],
      );
    }).toList();

    final totalFailures = _readFailures.values.fold<int>(
          0,
          (a, b) => a + b,
        ) +
        _writeFailures.values.fold<int>(0, (a, b) => a + b);

    return SecureStorageHealth(
      keys: keyHealth,
      globalFailureCount: totalFailures,
      isHealthy: totalFailures == 0,
    );
  }

  /// Clears failure counters (useful after a successful login or manual repair).
  void clearFailureCounters() {
    _consecutiveFailures = 0;
    _readFailures.clear();
    _writeFailures.clear();
    _lastErrors.clear();
  }

  /// Whether any memory fallbacks are currently active.
  bool get hasMemoryFallbacks => _memoryFallback.isNotEmpty;

  /// Returns the list of keys currently falling back to memory.
  List<String> get memoryFallbackKeys => _memoryFallback.keys.toList();
}
