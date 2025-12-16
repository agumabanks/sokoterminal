import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Telemetry {
  Telemetry._(this._file);

  static const String logFileName = 'soko_terminal_telemetry.jsonl';

  static Telemetry? _instance;
  final File _file;

  static Telemetry? get instance => _instance;

  static Future<Telemetry> init() async {
    if (_instance != null) return _instance!;

    final file = await _resolveLogFile();
    _instance = Telemetry._(file);
    await file.create(recursive: true);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(_instance!._recordFlutterError(details));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(_instance!._recordError(error, stack, kind: 'platform_error'));
      return true;
    };

    return _instance!;
  }

  static Future<File> getLogFile() => _resolveLogFile();

  Future<void> event(String name, {Map<String, dynamic>? props}) async {
    await _write({
      'ts': DateTime.now().toUtc().toIso8601String(),
      'kind': 'event',
      'name': name,
      if (props != null) 'props': props,
    });
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? hint,
    Map<String, dynamic>? props,
  }) async {
    await _recordError(error, stack, hint: hint, props: props, kind: 'error');
  }

  Future<void> clear() async {
    try {
      await _file.writeAsString('');
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _recordFlutterError(FlutterErrorDetails details) async {
    await _write({
      'ts': DateTime.now().toUtc().toIso8601String(),
      'kind': 'flutter_error',
      'exception': details.exceptionAsString(),
      'context': details.context?.toDescription(),
      if (details.stack != null) 'stack': details.stack.toString(),
      if (details.library != null) 'library': details.library,
    });
  }

  Future<void> _recordError(
    Object error,
    StackTrace stack, {
    required String kind,
    String? hint,
    Map<String, dynamic>? props,
  }) async {
    await _write({
      'ts': DateTime.now().toUtc().toIso8601String(),
      'kind': kind,
      'error': error.toString(),
      'stack': stack.toString(),
      if (hint != null) 'hint': hint,
      if (props != null) 'props': props,
    });
  }

  Future<void> _write(Map<String, dynamic> line) async {
    try {
      final encoded = jsonEncode(line);
      await _file.writeAsString(
        '$encoded\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Best effort.
    }
  }

  static Future<File> _resolveLogFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$logFileName');
    } catch (_) {
      final dir = await getTemporaryDirectory();
      return File('${dir.path}/$logFileName');
    }
  }
}
