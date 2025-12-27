import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: 'access_token', value: token);
  Future<String?> readAccessToken() => _storage.read(key: 'access_token');
  Future<void> deleteAccessToken() => _storage.delete(key: 'access_token');

  Future<void> writeLastLoginPhone(String phone) =>
      _storage.write(key: 'last_login_phone', value: phone);
  Future<String?> readLastLoginPhone() => _storage.read(key: 'last_login_phone');

  Future<void> writeSellerQuickPin(String pin) =>
      _storage.write(key: 'seller_quick_pin', value: pin);
  Future<String?> readSellerQuickPin() => _storage.read(key: 'seller_quick_pin');

  Future<void> writeSellerQuickPassword(String password) =>
      _storage.write(key: 'seller_quick_password', value: password);
  Future<String?> readSellerQuickPassword() =>
      _storage.read(key: 'seller_quick_password');

  Future<void> writeSellerQuickPhone(String phone) =>
      _storage.write(key: 'seller_quick_phone', value: phone);
  Future<String?> readSellerQuickPhone() =>
      _storage.read(key: 'seller_quick_phone');

  Future<void> clearSellerQuickLogin() async {
    await Future.wait([
      _storage.delete(key: 'seller_quick_phone'),
      _storage.delete(key: 'seller_quick_password'),
      _storage.delete(key: 'seller_quick_pin'),
    ]);
  }

  Future<void> writePin(String pin) => _storage.write(key: 'staff_pin', value: pin);
  Future<String?> readPin() => _storage.read(key: 'staff_pin');
  Future<void> deletePin() => _storage.delete(key: 'staff_pin');

  // POS staff session (server-side RBAC)
  Future<void> writePosSessionToken(String token) =>
      _storage.write(key: 'pos_session_token', value: token);
  Future<String?> readPosSessionToken() => _storage.read(key: 'pos_session_token');
  Future<void> deletePosSessionToken() => _storage.delete(key: 'pos_session_token');

  Future<void> writePosSessionMeta({
    required int staffId,
    required String staffName,
    required String staffRole,
    DateTime? expiresAt,
  }) async {
    await Future.wait([
      _storage.write(key: 'pos_session_staff_id', value: staffId.toString()),
      _storage.write(key: 'pos_session_staff_name', value: staffName),
      _storage.write(key: 'pos_session_staff_role', value: staffRole),
      if (expiresAt != null)
        _storage.write(
          key: 'pos_session_expires_at',
          value: expiresAt.toUtc().toIso8601String(),
        )
      else
        _storage.delete(key: 'pos_session_expires_at'),
    ]);
  }

  Future<int?> readPosSessionStaffId() async {
    final raw = await _storage.read(key: 'pos_session_staff_id');
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  Future<String?> readPosSessionStaffName() =>
      _storage.read(key: 'pos_session_staff_name');

  Future<String?> readPosSessionStaffRole() =>
      _storage.read(key: 'pos_session_staff_role');

  Future<DateTime?> readPosSessionExpiresAt() async {
    final raw = await _storage.read(key: 'pos_session_expires_at');
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim())?.toUtc();
  }

  Future<void> deletePosSessionMeta() async {
    await Future.wait([
      _storage.delete(key: 'pos_session_staff_id'),
      _storage.delete(key: 'pos_session_staff_name'),
      _storage.delete(key: 'pos_session_staff_role'),
      _storage.delete(key: 'pos_session_expires_at'),
    ]);
  }

  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
  Future<String?> read({required String key}) => _storage.read(key: key);
  Future<void> delete({required String key}) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();
}
