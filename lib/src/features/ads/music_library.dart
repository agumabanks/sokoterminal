/// Music library service — resolves bundled royalty-free music tracks.
///
/// The old VideoAdGenerator/Renderer shipped with an empty musicPath string,
/// producing silent ads. This service manages a set of bundled audio loops
/// that get copied to app storage on first use and resolved by genre.
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'video_ad_spec.dart';

class MusicLibrary {
  MusicLibrary._();
  static final MusicLibrary instance = MusicLibrary._();

  Directory? _dir;

  /// Get the local directory where tracks are cached.
  Future<Directory> get cacheDir async {
    if (_dir != null) return _dir!;
    final supportDir = await getApplicationSupportDirectory();
    _dir = Directory('${supportDir.path}/music');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  /// Ensure a specific track exists on disk, copying from assets if needed.
  Future<String?> resolveTrack(AdMusicGenre genre) async {
    final dir = await cacheDir;
    final assetPath = 'assets/music/${_genreFileName(genre)}_loop.m4a';
    final fileName = '${_genreFileName(genre)}_loop.m4a';
    final localFile = File('${dir.path}/$fileName');

    if (await localFile.exists() && localFile.lengthSync() > 0) {
      return localFile.path;
    }

    // Copy from bundle
    try {
      final data = await rootBundle.load(assetPath);
      await localFile.writeAsBytes(data.buffer.asUint8List());
      return localFile.path;
    } catch (_) {
      // Asset not bundled — return null (silent ad)
      return null;
    }
  }

  /// Ensure a specific named track exists on disk.
  Future<String?> resolveNamedTrack(String assetName) async {
    final dir = await cacheDir;
    final localFile = File('${dir.path}/$assetName');

    if (await localFile.exists() && localFile.lengthSync() > 0) {
      return localFile.path;
    }

    try {
      final data = await rootBundle.load('assets/music/$assetName');
      await localFile.writeAsBytes(data.buffer.asUint8List());
      return localFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Check if music assets are bundled (graceful fallback for when no assets exist).
  Future<bool> hasBundledAssets() async {
    try {
      final data = await rootBundle.load('assets/music/afrobeats_loop.m4a');
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

  /// Get the path to a font file (extracted from bundle if needed).
  Future<String> extractFont() async {
    final dir = await getApplicationSupportDirectory();
    final fontFile = File('${dir.path}/Montserrat-Bold.ttf');
    if (await fontFile.exists() && fontFile.lengthSync() > 0) {
      return fontFile.path;
    }
    final data = await rootBundle.load('assets/fonts/Montserrat-Bold.ttf');
    await fontFile.writeAsBytes(data.buffer.asUint8List());
    return fontFile.path;
  }

  String _genreFileName(AdMusicGenre genre) {
    return switch (genre) {
      AdMusicGenre.afrobeats => 'afrobeats',
      AdMusicGenre.bongoFlava => 'bongo',
      AdMusicGenre.gengetone => 'gengetone',
      AdMusicGenre.gospel => 'gospel',
      AdMusicGenre.traditional => 'traditional',
      AdMusicGenre.hipHop => 'hiphop',
      AdMusicGenre.pop => 'pop',
      AdMusicGenre.electronic => 'electronic',
    };
  }
}
