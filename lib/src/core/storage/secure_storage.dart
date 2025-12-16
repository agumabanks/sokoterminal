import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<String?> readAccessToken() => _storage.read(key: 'access_token');
  Future<void> writePin(String pin) => _storage.write(key: 'staff_pin', value: pin);
  Future<String?> readPin() => _storage.read(key: 'staff_pin');
  Future<void> deletePin() => _storage.delete(key: 'staff_pin');
  Future<void> clearAll() => _storage.deleteAll();
}
