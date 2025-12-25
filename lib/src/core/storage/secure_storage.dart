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

  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
  Future<String?> read({required String key}) => _storage.read(key: key);
  Future<void> delete({required String key}) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();
}
