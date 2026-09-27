import 'dart:async';
import 'package:flutter/services.dart';

/// Publishes only a short-lived signed shop proof. The seller token stays in Terminal.
class TerminalIdentityPublisher {
  TerminalIdentityPublisher({required this.fetch, Future<void> Function(String,int)? publish})
      : publish = publish ?? _publishNative {
    if (publish == null) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'refresh') return refreshNow();
        throw MissingPluginException();
      });
    }
  }
  final Future<String> Function() fetch;
  final Future<void> Function(String,int) publish;
  Timer? _timer;
  int _generation=0;
  bool _active=false;
  static const _channel=MethodChannel('soko/amara_identity');
  static Future<void> _publishNative(String proof,int generation) async {
    try { await _channel.invokeMethod('publish', {'assertion':proof,'generation':generation}); }
    on MissingPluginException { /* non-Android */ }
    on PlatformException { /* keep checkout available; Amara rejects missing proof */ }
  }
  Future<void> setAuthenticated(bool active) async {
    _timer?.cancel();_active=active;
    final generation=DateTime.now().microsecondsSinceEpoch > _generation ? DateTime.now().microsecondsSinceEpoch : _generation+1;
    _generation=generation;
    await publish('',generation);
    if (!active || generation!=_generation) return;
    _timer=Timer.periodic(const Duration(seconds:60), (_) => _refresh(generation));
    await _refresh(generation);
  }
  Future<bool> refreshNow() async {
    if (!_active) return false;
    return _refresh(_generation);
  }
  Future<bool> _refresh(int generation) async {
    try {
      final proof=await fetch();
      if (_active && generation==_generation) {
        await publish(proof,generation);
        return proof.isNotEmpty;
      }
      return false;
    } catch (_) { if(generation==_generation) await publish('',generation); return false; }
  }
  void dispose() {_active=false;_generation++;_timer?.cancel();}
}
