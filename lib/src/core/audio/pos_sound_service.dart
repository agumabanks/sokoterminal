import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// POS Sound Service — Steve Jobs standard auditory feedback.
///
/// Generates lightweight sine-wave WAVs in-memory so there are zero
/// asset files to ship and zero risk of missing sound resources.
class PosSoundService {
  static final PosSoundService _instance = PosSoundService._internal();
  factory PosSoundService() => _instance;
  PosSoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;

  void setMuted(bool muted) => _muted = muted;

  Future<void> playClick() async {
    await _playTone(frequency: 1760, durationMs: 40, volume: 0.15);
  }

  Future<void> playAddToCart() async {
    await _playTone(frequency: 1200, durationMs: 80, volume: 0.22);
  }

  Future<void> playSuccess() async {
    // Two-tone "ding" (charge sound inspired)
    await _playTone(frequency: 1050, durationMs: 90, volume: 0.35);
    await Future.delayed(const Duration(milliseconds: 60));
    await _playTone(frequency: 880, durationMs: 180, volume: 0.35);
  }

  /// Cinematic studio reveal — ascending tones over ~3.5s.
  Future<void> playStudioReveal() async {
    const steps = [
      (freq: 220, ms: 500, vol: 0.12),
      (freq: 330, ms: 450, vol: 0.16),
      (freq: 440, ms: 420, vol: 0.20),
      (freq: 554, ms: 400, vol: 0.24),
      (freq: 659, ms: 520, vol: 0.28),
      (freq: 880, ms: 700, vol: 0.32),
    ];
    for (final step in steps) {
      await _playTone(
        frequency: step.freq,
        durationMs: step.ms,
        volume: step.vol,
      );
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  Future<void> playError() async {
    await _playTone(frequency: 300, durationMs: 220, volume: 0.30);
  }

  Future<void> _playTone({
    required int frequency,
    required int durationMs,
    required double volume,
  }) async {
    if (_muted) return;
    try {
      final bytes = _generateSineWav(
        frequency: frequency,
        durationMs: durationMs,
      );
      await _player.setVolume(volume);
      await _player.play(BytesSource(bytes));
    } catch (e) {
      if (kDebugMode) debugPrint('[PosSoundService] play error: $e');
    }
  }

  Uint8List _generateSineWav({
    required int frequency,
    required int durationMs,
    int sampleRate = 22050,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2; // 16-bit mono
    final fileSize = 44 + dataSize;

    final bb = BytesBuilder();

    // RIFF header
    bb.add(Uint8List.fromList('RIFF'.codeUnits));
    bb.add(_u32(fileSize));
    bb.add(Uint8List.fromList('WAVE'.codeUnits));

    // fmt subchunk
    bb.add(Uint8List.fromList('fmt '.codeUnits));
    bb.add(_u32(16)); // Subchunk1Size
    bb.add(_u16(1)); // AudioFormat PCM
    bb.add(_u16(1)); // NumChannels
    bb.add(_u32(sampleRate));
    bb.add(_u32(sampleRate * 2)); // ByteRate
    bb.add(_u16(2)); // BlockAlign
    bb.add(_u16(16)); // BitsPerSample

    // data subchunk
    bb.add(Uint8List.fromList('data'.codeUnits));
    bb.add(_u32(dataSize));

    const attackMs = 8;
    const releaseMs = 20;
    final attackSamples = (sampleRate * attackMs / 1000).round();
    final releaseSamples = (sampleRate * releaseMs / 1000).round();

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      var sample = sin(2 * pi * frequency * t);

      // Simple AD envelope to avoid clicking
      double envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i > numSamples - releaseSamples) {
        envelope = (numSamples - i) / releaseSamples;
      }
      sample *= envelope;

      final value = (sample * 32767).round().clamp(-32768, 32767);
      bb.add(_s16(value));
    }

    return Uint8List.fromList(bb.toBytes());
  }

  Uint8List _u16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    return Uint8List.view(b.buffer);
  }

  Uint8List _s16(int v) {
    final b = ByteData(2)..setInt16(0, v, Endian.little);
    return Uint8List.view(b.buffer);
  }

  Uint8List _u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    return Uint8List.view(b.buffer);
  }
}
