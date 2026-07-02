/// Sound source routed through one mixer channel.
enum InstrumentType { piano, guitar, bass, synth, drums }

/// Oscillator shapes supported by the lightweight preview synth.
enum WaveShape { sine, triangle, saw, square, noise }

/// One playable pitch and its intended synthesis voice.
class InstrumentNote {
  const InstrumentNote({
    required this.label,
    required this.frequency,
    required this.instrument,
  });

  final String label;
  final double frequency;
  final InstrumentType instrument;
}

/// Immutable channel and master gain snapshot.
class MixerState {
  const MixerState({
    this.piano = .8,
    this.guitar = .8,
    this.bass = .75,
    this.drums = .85,
    this.master = .85,
    this.drive = .15,
  });

  final double piano;
  final double guitar;
  final double bass;
  final double drums;
  final double master;
  final double drive;

  /// Returns the channel gain routed to [instrument].
  double volumeFor(InstrumentType instrument) => switch (instrument) {
        InstrumentType.piano => piano,
        InstrumentType.guitar => guitar,
        InstrumentType.bass || InstrumentType.synth => bass,
        InstrumentType.drums => drums,
      };

  /// Creates a new mixer snapshot while preserving unspecified channels.
  MixerState copyWith({
    double? piano,
    double? guitar,
    double? bass,
    double? drums,
    double? master,
    double? drive,
  }) =>
      MixerState(
        piano: piano ?? this.piano,
        guitar: guitar ?? this.guitar,
        bass: bass ?? this.bass,
        drums: drums ?? this.drums,
        master: master ?? this.master,
        drive: drive ?? this.drive,
      );
}

/// Mutable grid used by the live step sequencer.
class StepPattern {
  StepPattern({int tracks = 4, int steps = 16})
      : cells = List.generate(tracks, (_) => List.filled(steps, false));

  final List<List<bool>> cells;

  int get trackCount => cells.length;
  int get stepCount => cells.first.length;

  /// Flips one cell; invalid indices intentionally surface as range errors.
  void toggle(int track, int step) {
    cells[track][step] = !cells[track][step];
  }
}
