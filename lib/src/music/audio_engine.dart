import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'music_models.dart';

/// Serializable synthesis parameters passed to the render isolate.
class SynthRequest {
  const SynthRequest({
    required this.frequency,
    required this.durationMs,
    required this.shape,
    required this.volume,
    required this.drive,
  });

  final double frequency;
  final int durationMs;
  final WaveShape shape;
  final double volume;
  final double drive;
}

/// Low-latency polyphonic preview engine backed by generated PCM WAV buffers.
class MusicAudioEngine {
  final Set<AudioPlayer> _voices = {};
  static const maxVoices = 16;

  /// Synthesizes a note off the UI isolate and plays it as one disposable voice.
  Future<void> playNote(
    InstrumentNote note,
    MixerState mixer, {
    int durationMs = 520,
  }) async {
    if (_voices.length >= maxVoices) {
      final oldest = _voices.first;
      _voices.remove(oldest);
      await oldest.dispose();
    }
    final bytes = await Isolate.run(() => _encodeWav(SynthRequest(
          frequency: note.frequency,
          durationMs: durationMs,
          shape: _shapeFor(note.instrument),
          volume: mixer.volumeFor(note.instrument) * mixer.master,
          drive: mixer.drive,
        )));
    final player = AudioPlayer();
    _voices.add(player);
    player.onPlayerComplete.first.then((_) async {
      _voices.remove(player);
      await player.dispose();
    });
    await player.play(BytesSource(bytes));
  }

  /// Stops and releases every active native audio voice.
  Future<void> dispose() async {
    final voices = _voices.toList(growable: false);
    _voices.clear();
    for (final voice in voices) {
      await voice.dispose();
    }
  }

  static WaveShape _shapeFor(InstrumentType instrument) => switch (instrument) {
        InstrumentType.piano => WaveShape.triangle,
        InstrumentType.guitar => WaveShape.saw,
        InstrumentType.bass => WaveShape.square,
        InstrumentType.synth => WaveShape.saw,
        InstrumentType.drums => WaveShape.noise,
      };
}

/// Renders one short mono voice without touching plugin or UI state.
Uint8List _encodeWav(SynthRequest request) {
  const sampleRate = 22050;
  final samples = sampleRate * request.durationMs ~/ 1000;
  final pcm = Int16List(samples);
  var seed = 7;
  for (var index = 0; index < samples; index++) {
    final time = index / sampleRate;
    final phase = 2 * pi * request.frequency * time;
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final noise = seed / 0x7fffffff * 2 - 1;
    final raw = switch (request.shape) {
      WaveShape.sine => sin(phase),
      WaveShape.triangle => 2 / pi * asin(sin(phase)),
      WaveShape.saw => 2 * (request.frequency * time % 1) - 1,
      WaveShape.square => sin(phase) >= 0 ? 1.0 : -1.0,
      WaveShape.noise => noise,
    };
    final envelope = pow(1 - index / samples, request.shape == WaveShape.noise ? 5 : 2);
    final driven = _softClip(raw * (1 + request.drive * 5));
    pcm[index] = (driven * envelope * request.volume * 26000)
        .clamp(-32768, 32767)
        .round();
  }
  return _wavContainer(pcm, sampleRate);
}

double _softClip(double value) {
  final positive = exp(value);
  final negative = exp(-value);
  return (positive - negative) / (positive + negative);
}

/// Wraps signed mono PCM in a standards-compatible in-memory WAV container.
Uint8List _wavContainer(Int16List pcm, int sampleRate) {
  final dataLength = pcm.lengthInBytes;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.view(bytes.buffer);
  void text(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < pcm.length; index++) {
    data.setInt16(44 + index * 2, pcm[index], Endian.little);
  }
  return bytes;
}
