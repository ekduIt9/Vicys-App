import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_engine.dart';
import 'music_models.dart';

/// Root application for the offline PulseForge workstation.
class MusicStudioApp extends StatelessWidget {
  const MusicStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PulseForge',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff9d7bff),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xff0d0d12),
          useMaterial3: true,
        ),
        home: const MusicStudioScreen(),
      );
}

/// Hosts instrument, sequencer and mixer workspaces.
class MusicStudioScreen extends StatefulWidget {
  const MusicStudioScreen({super.key});

  @override
  State<MusicStudioScreen> createState() => _MusicStudioScreenState();
}

class _MusicStudioScreenState extends State<MusicStudioScreen> {
  final engine = MusicAudioEngine();
  final pattern = StepPattern();
  var mixer = const MixerState();
  var page = 0;
  var instrument = InstrumentType.piano;
  var bpm = 128;
  var currentStep = 0;
  var playing = false;
  Timer? timer;

  static const pianoNotes = [
    InstrumentNote(label: 'C4', frequency: 261.63, instrument: InstrumentType.piano),
    InstrumentNote(label: 'D4', frequency: 293.66, instrument: InstrumentType.piano),
    InstrumentNote(label: 'E4', frequency: 329.63, instrument: InstrumentType.piano),
    InstrumentNote(label: 'F4', frequency: 349.23, instrument: InstrumentType.piano),
    InstrumentNote(label: 'G4', frequency: 392, instrument: InstrumentType.piano),
    InstrumentNote(label: 'A4', frequency: 440, instrument: InstrumentType.piano),
    InstrumentNote(label: 'B4', frequency: 493.88, instrument: InstrumentType.piano),
    InstrumentNote(label: 'C5', frequency: 523.25, instrument: InstrumentType.piano),
  ];

  static const guitarNotes = [
    InstrumentNote(label: 'E2', frequency: 82.41, instrument: InstrumentType.guitar),
    InstrumentNote(label: 'A2', frequency: 110, instrument: InstrumentType.guitar),
    InstrumentNote(label: 'D3', frequency: 146.83, instrument: InstrumentType.guitar),
    InstrumentNote(label: 'G3', frequency: 196, instrument: InstrumentType.guitar),
    InstrumentNote(label: 'B3', frequency: 246.94, instrument: InstrumentType.guitar),
    InstrumentNote(label: 'E4', frequency: 329.63, instrument: InstrumentType.guitar),
  ];

  static const synthNotes = [
    InstrumentNote(label: 'SUB', frequency: 55, instrument: InstrumentType.bass),
    InstrumentNote(label: 'WOB', frequency: 65.41, instrument: InstrumentType.synth),
    InstrumentNote(label: 'REESE', frequency: 73.42, instrument: InstrumentType.synth),
    InstrumentNote(label: 'DROP', frequency: 49, instrument: InstrumentType.bass),
  ];

  @override
  void dispose() {
    timer?.cancel();
    engine.dispose();
    super.dispose();
  }

  void toggleTransport() {
    if (playing) {
      timer?.cancel();
      setState(() => playing = false);
      return;
    }
    setState(() => playing = true);
    _schedule();
  }

  void _schedule() {
    timer?.cancel();
    final interval = Duration(milliseconds: (60000 / bpm / 4).round());
    timer = Timer.periodic(interval, (_) {
      _playStep(currentStep);
      if (mounted) {
        setState(() => currentStep = (currentStep + 1) % pattern.stepCount);
      }
    });
  }

  void _playStep(int step) {
    const notes = [
      InstrumentNote(label: 'Kick', frequency: 58, instrument: InstrumentType.drums),
      InstrumentNote(label: 'Snare', frequency: 180, instrument: InstrumentType.drums),
      InstrumentNote(label: 'Bass', frequency: 55, instrument: InstrumentType.bass),
      InstrumentNote(label: 'Synth', frequency: 110, instrument: InstrumentType.synth),
    ];
    for (var track = 0; track < pattern.trackCount; track++) {
      if (pattern.cells[track][step]) {
        engine.playNote(notes[track], mixer, durationMs: track < 2 ? 180 : 360);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PULSEFORGE', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('MOBILE MUSIC LAB', style: TextStyle(fontSize: 9, letterSpacing: 2)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: toggleTransport,
              icon: Icon(playing ? Icons.stop : Icons.play_arrow),
              label: Text(playing ? 'STOP' : 'PLAY'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: page,
          children: [
            _InstrumentPage(
              instrument: instrument,
              onInstrumentChanged: (value) => setState(() => instrument = value),
              mixer: mixer,
              engine: engine,
              pianoNotes: pianoNotes,
              guitarNotes: guitarNotes,
              synthNotes: synthNotes,
            ),
            _SequencerPage(
              pattern: pattern,
              currentStep: currentStep,
              bpm: bpm,
              playing: playing,
              onToggle: (track, step) => setState(() => pattern.toggle(track, step)),
              onBpmChanged: (value) {
                setState(() => bpm = value.round());
                if (playing) _schedule();
              },
              onTransport: toggleTransport,
            ),
            _MixerPage(
              mixer: mixer,
              onChanged: (value) => setState(() => mixer = value),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (value) => setState(() => page = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.piano), label: 'Nhạc cụ'),
            NavigationDestination(icon: Icon(Icons.grid_on), label: 'Sequencer'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Mix & Master'),
          ],
        ),
      );
}

class _InstrumentPage extends StatelessWidget {
  const _InstrumentPage({
    required this.instrument,
    required this.onInstrumentChanged,
    required this.mixer,
    required this.engine,
    required this.pianoNotes,
    required this.guitarNotes,
    required this.synthNotes,
  });

  final InstrumentType instrument;
  final ValueChanged<InstrumentType> onInstrumentChanged;
  final MixerState mixer;
  final MusicAudioEngine engine;
  final List<InstrumentNote> pianoNotes;
  final List<InstrumentNote> guitarNotes;
  final List<InstrumentNote> synthNotes;

  @override
  Widget build(BuildContext context) {
    final notes = switch (instrument) {
      InstrumentType.guitar => guitarNotes,
      InstrumentType.bass || InstrumentType.synth => synthNotes,
      _ => pianoNotes,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<InstrumentType>(
          segments: const [
            ButtonSegment(value: InstrumentType.piano, label: Text('Piano'), icon: Icon(Icons.piano)),
            ButtonSegment(value: InstrumentType.guitar, label: Text('Guitar'), icon: Icon(Icons.music_note)),
            ButtonSegment(value: InstrumentType.synth, label: Text('Dubstep'), icon: Icon(Icons.graphic_eq)),
          ],
          selected: {instrument},
          onSelectionChanged: (value) => onInstrumentChanged(value.first),
        ),
        const SizedBox(height: 24),
        Text(
          instrument == InstrumentType.piano
              ? 'GRAND KEYS'
              : instrument == InstrumentType.guitar
                  ? 'ELECTRIC STRINGS'
                  : 'DUBSTEP BASS LAB',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: instrument == InstrumentType.guitar ? 3 : 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: instrument == InstrumentType.piano ? .72 : 1.25,
          ),
          itemCount: notes.length,
          itemBuilder: (_, index) {
            final note = notes[index];
            return _PerformancePad(
              label: note.label,
              piano: instrument == InstrumentType.piano,
              onTap: () => engine.playNote(note, mixer),
            );
          },
        ),
      ],
    );
  }
}

class _PerformancePad extends StatelessWidget {
  const _PerformancePad({required this.label, required this.onTap, this.piano = false});
  final String label;
  final VoidCallback onTap;
  final bool piano;

  @override
  Widget build(BuildContext context) => Material(
        color: piano ? const Color(0xffececf3) : const Color(0xff252137),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: piano ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
}

class _SequencerPage extends StatelessWidget {
  const _SequencerPage({
    required this.pattern,
    required this.currentStep,
    required this.bpm,
    required this.playing,
    required this.onToggle,
    required this.onBpmChanged,
    required this.onTransport,
  });

  final StepPattern pattern;
  final int currentStep;
  final int bpm;
  final bool playing;
  final void Function(int track, int step) onToggle;
  final ValueChanged<double> onBpmChanged;
  final VoidCallback onTransport;

  @override
  Widget build(BuildContext context) {
    const names = ['KICK', 'SNARE', 'BASS', 'SYNTH'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: onTransport,
              icon: Icon(playing ? Icons.stop : Icons.play_arrow),
              label: Text(playing ? 'Stop' : 'Play'),
            ),
            const SizedBox(width: 16),
            Text('$bpm BPM'),
            Expanded(
              child: Slider(value: bpm.toDouble(), min: 70, max: 180, onChanged: onBpmChanged),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...List.generate(pattern.trackCount, (track) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 52, child: Text(names[track], style: const TextStyle(fontSize: 10))),
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: pattern.stepCount,
                      itemBuilder: (_, step) => InkWell(
                        onTap: () => onToggle(track, step),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          decoration: BoxDecoration(
                            color: pattern.cells[track][step]
                                ? const Color(0xff9d7bff)
                                : currentStep == step
                                    ? const Color(0xff4d426b)
                                    : const Color(0xff25242d),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _MixerPage extends StatelessWidget {
  const _MixerPage({required this.mixer, required this.onChanged});
  final MixerState mixer;
  final ValueChanged<MixerState> onChanged;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('MIXER', style: Theme.of(context).textTheme.headlineMedium),
          _Fader(label: 'Piano', value: mixer.piano, onChanged: (v) => onChanged(mixer.copyWith(piano: v))),
          _Fader(label: 'Guitar', value: mixer.guitar, onChanged: (v) => onChanged(mixer.copyWith(guitar: v))),
          _Fader(label: 'Bass / Synth', value: mixer.bass, onChanged: (v) => onChanged(mixer.copyWith(bass: v))),
          _Fader(label: 'Drums', value: mixer.drums, onChanged: (v) => onChanged(mixer.copyWith(drums: v))),
          const Divider(height: 32),
          Text('MASTER', style: Theme.of(context).textTheme.titleLarge),
          _Fader(label: 'Master gain', value: mixer.master, onChanged: (v) => onChanged(mixer.copyWith(master: v))),
          _Fader(label: 'Drive', value: mixer.drive, onChanged: (v) => onChanged(mixer.copyWith(drive: v))),
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_graph),
              title: Text('Master chain'),
              subtitle: Text('Soft clip • limiter • -1 dB ceiling'),
            ),
          ),
        ],
      );
}

class _Fader extends StatelessWidget {
  const _Fader({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(child: Slider(value: value, onChanged: onChanged)),
          SizedBox(width: 42, child: Text('${(value * 100).round()}')),
        ],
      );
}
