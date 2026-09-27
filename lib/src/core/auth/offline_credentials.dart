import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';

/// Device-local verifiers, provisioned only after successful server login.
/// Never stores the password/PIN itself; explicit logout clears this record.
class OfflineCredentials {
  OfflineCredentials(this.storage);
  final SecureStorage storage;
  static const key = 'offline_seller_credentials_v1';

  static const _iterations = 100000;

  Future<Map<String, dynamic>?> account(String identifier) async {
    if ((await storage.readAccessToken())?.isNotEmpty != true ||
        await storage.read(key: 'login_type') == 'staff') {
      return null;
    }
    final raw = await storage.read(key: key);
    if (raw == null) return null;
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      return record['identifier'] == identifier ? record : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String identifier,
    String secret, {
    required bool pin,
  }) async {
    final record =
        await account(identifier) ??
        <String, dynamic>{'identifier': identifier};
    final salt = base64Encode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final hash = await compute(_derive, [secret, salt]);
    record[pin ? 'pin' : 'password'] = {'salt': salt, 'hash': hash};
    record['attempts'] = 0;
    record.remove('lockedUntil');
    await storage.write(key: key, value: jsonEncode(record));
  }

  Future<bool> verify(
    String identifier,
    String secret, {
    required bool pin,
  }) async {
    final record = await account(identifier);
    if (record == null) return false;
    final until = DateTime.tryParse(record['lockedUntil']?.toString() ?? '');
    if (until != null && DateTime.now().isBefore(until)) {
      throw Exception('Too many attempts. Try again in 30 seconds.');
    }
    final verifier = record[pin ? 'pin' : 'password'];
    if (verifier is! Map) return false;
    final salt = verifier['salt'];
    final expected = verifier['hash'];
    if (salt is! String || expected is! String) return false;
    final actual = await compute(_derive, [secret, salt]);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    final valid = difference == 0;
    final attempts = valid ? 0 : ((record['attempts'] as int?) ?? 0) + 1;
    record['attempts'] = attempts;
    if (attempts >= 5) {
      record['lockedUntil'] = DateTime.now()
          .add(const Duration(seconds: 30))
          .toIso8601String();
      record['attempts'] = 0;
    }
    await storage.write(key: key, value: jsonEncode(record));
    return valid;
  }
}

// PBKDF2-HMAC-SHA256, performed away from the UI isolate.
String _derive(List<String> input) {
  final hmac = Hmac(sha256, utf8.encode(input[0]));
  var block = hmac.convert([...base64Decode(input[1]), 0, 0, 0, 1]).bytes;
  final output = List<int>.from(block);
  for (var round = 1; round < OfflineCredentials._iterations; round++) {
    block = hmac.convert(block).bytes;
    for (var i = 0; i < output.length; i++) {
      output[i] ^= block[i];
    }
  }
  return base64Encode(output);
}
