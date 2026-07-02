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
  final List<_VoiceSlot> _voices = List.generate(
    maxVoices,
    (_) => _VoiceSlot(AudioPlayer()),
  );
  final Map<String, Future<Uint8List>> _sampleCache = {};
  static const maxVoices = 8;
  static const maxCachedSamples = 64;
  var _playOrder = 0;
  var _disposed = false;

  /// Synthesizes and caches a note off the UI isolate, then plays it through a
  /// bounded reusable voice pool. When all voices are busy, the oldest voice is
  /// stopped and reused. Calls after [dispose] are ignored.
  Future<void> playNote(
    InstrumentNote note,
    MixerState mixer, {
    int durationMs = 520,
  }) async {
    if (_disposed) return;
    final request = SynthRequest(
      frequency: note.frequency,
      durationMs: durationMs,
      shape: _shapeFor(note.instrument),
      volume: (mixer.volumeFor(note.instrument) * mixer.master)
          .clamp(0, 1)
          .toDouble(),
      drive: mixer.drive.clamp(0, 1).toDouble(),
    );
    final cacheKey = _cacheKey(request);
    if (_sampleCache.length >= maxCachedSamples &&
        !_sampleCache.containsKey(cacheKey)) {
      _sampleCache.clear();
    }
    late final Uint8List bytes;
    try {
      bytes = await _sampleCache.putIfAbsent(
        cacheKey,
        () => Isolate.run(() => _encodeWav(request)),
      );
    } catch (_) {
      _sampleCache.remove(cacheKey);
      return;
    }
    if (_disposed) return;

    _VoiceSlot? available;
    for (final voice in _voices) {
      if (!voice.busy) {
        available = voice;
        break;
      }
    }
    final slot = available ??
        _voices.reduce((a, b) => a.order <= b.order ? a : b);
    slot.busy = true;
    slot.order = ++_playOrder;
    final generation = ++slot.generation;

    if (slot.started) {
      try {
        await slot.player.stop();
      } catch (_) {
        // A completed native voice can already be stopped; it remains reusable.
      }
    }
    if (_disposed || generation != slot.generation) return;
    try {
      await slot.player.play(BytesSource(bytes));
      slot.started = true;
    } catch (_) {
      if (generation == slot.generation) slot.busy = false;
      return;
    }
    Timer(Duration(milliseconds: durationMs + 120), () {
      if (generation == slot.generation) slot.busy = false;
    });
  }

  /// Stops and releases every active native audio voice.
  Future<void> dispose() async {
    _disposed = true;
    _sampleCache.clear();
    for (final voice in _voices) {
      voice.generation++;
      voice.busy = false;
      await voice.player.dispose();
    }
  }

  static String _cacheKey(SynthRequest request) =>
      '${request.frequency.toStringAsFixed(2)}:'
      '${request.durationMs}:${request.shape.index}:'
      '${request.volume.toStringAsFixed(2)}:${request.drive.toStringAsFixed(2)}';

  static WaveShape _shapeFor(InstrumentType instrument) => switch (instrument) {
        InstrumentType.piano => WaveShape.triangle,
        InstrumentType.guitar => WaveShape.saw,
        InstrumentType.bass => WaveShape.square,
        InstrumentType.synth => WaveShape.saw,
        InstrumentType.drums => WaveShape.noise,
      };
}

class _VoiceSlot {
  _VoiceSlot(this.player);

  final AudioPlayer player;
  var busy = false;
  var started = false;
  var order = 0;
  var generation = 0;
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
