import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OfflineMediaCache {
  OfflineMediaCache._();

  static final OfflineMediaCache instance = OfflineMediaCache._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
    ),
  );
  final Map<String, Future<File?>> _inflight = {};
  Directory? _cacheDir;

  Future<File?> resolve(String urlOrPath, {bool downloadIfMissing = true}) async {
    final raw = urlOrPath.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    final scheme = (uri?.scheme ?? '').toLowerCase();
    final isNetwork = scheme == 'http' || scheme == 'https';

    if (!isNetwork) {
      final localPath = scheme == 'file' ? uri!.toFilePath() : raw;
      final file = File(localPath);
      return file.existsSync() ? file : null;
    }

    final cacheFile = await _cacheFileForUrl(raw);
    if (cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
      return cacheFile;
    }
    if (!downloadIfMissing) return null;

    return _inflight.putIfAbsent(raw, () async {
      try {
        final tmp = File('${cacheFile.path}.tmp');
        if (tmp.existsSync()) {
          await tmp.delete();
        }
        await _dio.download(raw, tmp.path);
        if (!tmp.existsSync() || tmp.lengthSync() == 0) {
          return null;
        }
        if (cacheFile.existsSync()) {
          await cacheFile.delete();
        }
        await tmp.rename(cacheFile.path);
        return cacheFile;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(raw);
      }
    });
  }

  Future<void> prefetchAll(Iterable<String> urls) async {
    final unique = urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    const batchSize = 4;
    for (var i = 0; i < unique.length; i += batchSize) {
      final batch = unique.sublist(
        i,
        i + batchSize > unique.length ? unique.length : i + batchSize,
      );
      await Future.wait(batch.map((url) => resolve(url)));
    }
  }

  Future<File> _cacheFileForUrl(String url) async {
    final dir = await _ensureCacheDir();
    final uri = Uri.tryParse(url);
    var ext = p.extension(uri?.path ?? '').toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(ext)) {
      ext = '.img';
    }
    final fileName = '${_fnv1a64(url)}$ext';
    return File(p.join(dir.path, fileName));
  }

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'media_cache'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _fnv1a64(String input) {
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
