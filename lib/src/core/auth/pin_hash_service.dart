import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../storage/secure_storage.dart';

/// Hashes staff PINs before storing them in the local SQLite database.
/// Uses SHA-256 with a per-device salt stored in secure storage.
class PinHashService {
  PinHashService({required SecureStorage storage}) : _storage = storage;

  final SecureStorage _storage;

  /// Generates a new random salt if one doesn't exist.
  Future<String> _ensureSalt() async {
    final existing = await _storage.readPinHashSalt();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    final salt = base64Encode(bytes);
    await _storage.writePinHashSalt(salt);
    return salt;
  }

  /// Returns the SHA-256 hash of [pin] with the device salt.
  Future<String> hash(String pin) async {
    final salt = await _ensureSalt();
    final bytes = utf8.encode(salt + pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a [pin] against a stored [hash].
  Future<bool> verify(String pin, String hash) async {
    final computed = await this.hash(pin);
    return computed == hash;
  }
}
