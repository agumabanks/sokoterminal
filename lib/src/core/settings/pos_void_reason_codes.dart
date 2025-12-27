import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PosVoidReasonCodesCache {
  static const prefsKey = 'pos.void_reason_codes.v1';

  static const defaultCodes = <String>[
    'MISTAKE',
    'CUSTOMER_CANCELLED',
    'DUPLICATE_SALE',
    'PRICE_ERROR',
  ];

  static List<String> read(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) return List<String>.from(defaultCodes);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final out = <String>[];
        final seen = <String>{};
        for (final v in decoded) {
          final s = v.toString().trim().toUpperCase();
          if (s.isEmpty) continue;
          if (seen.add(s)) out.add(s);
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return List<String>.from(defaultCodes);
  }

  static Future<void> write(SharedPreferences prefs, List<String> codes) async {
    final out = <String>[];
    final seen = <String>{};
    for (final v in codes) {
      final s = v.toString().trim().toUpperCase();
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    await prefs.setString(prefsKey, jsonEncode(out));
  }

  static Future<void> reset(SharedPreferences prefs) async {
    await prefs.remove(prefsKey);
  }
}

