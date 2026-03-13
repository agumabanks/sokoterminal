import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorage {
  SecureStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _maxRetries = 3;
  int _consecutiveFailures = 0;

  bool get _storageAvailable => _consecutiveFailures < 10;

  void _recordFailure(Object error) {
    _consecutiveFailures++;
    debugPrint(
      '[SecureStorage] operation failed ($_consecutiveFailures): $error',
    );
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
  }

  Future<void> _safeWrite(String key, String value) async {
    if (!_storageAvailable) return;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.write(key: key, value: value);
        _recordSuccess();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) _recordFailure(e);
      }
    }
  }

  Future<String?> _safeRead(String key) async {
    if (!_storageAvailable) return null;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _storage.read(key: key);
        _recordSuccess();
        return result;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          _recordFailure(e);
          return null;
        }
      }
    }
    return null;
  }

  Future<void> _safeDelete(String key) async {
    if (!_storageAvailable) return;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.delete(key: key);
        _recordSuccess();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) _recordFailure(e);
      }
    }
  }

  Future<void> _safeDeleteAll() async {
    if (!_storageAvailable) return;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _storage.deleteAll();
        _recordSuccess();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) _recordFailure(e);
      }
    }
  }

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
}
