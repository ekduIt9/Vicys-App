import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_engine.dart';
import 'backing_track_service.dart';
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
  final backing = BackingTrackService();
  final pattern = StepPattern();
  var mixer = const MixerState();
  var page = 0;
  var instrument = InstrumentType.piano;
  var bpm = 128;
  var currentStep = 0;
  var playing = false;
  var importingTrack = false;
  BackingTrack? track;
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
    InstrumentNote(label: 'D5', frequency: 587.33, instrument: InstrumentType.piano),
    InstrumentNote(label: 'E5', frequency: 659.25, instrument: InstrumentType.piano),
    InstrumentNote(label: 'F5', frequency: 698.46, instrument: InstrumentType.piano),
    InstrumentNote(label: 'G5', frequency: 783.99, instrument: InstrumentType.piano),
    InstrumentNote(label: 'A5', frequency: 880, instrument: InstrumentType.piano),
    InstrumentNote(label: 'B5', frequency: 987.77, instrument: InstrumentType.piano),
    InstrumentNote(label: 'C6', frequency: 1046.5, instrument: InstrumentType.piano),
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
    backing.dispose();
    super.dispose();
  }

  Future<void> importTrack() async {
    if (importingTrack) return;
    setState(() => importingTrack = true);
    try {
      final imported = await backing.importFromDevice();
      if (mounted && imported != null) setState(() => track = imported);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở bài nhạc. Hãy chọn MP3, WAV hoặc M4A khác.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => importingTrack = false);
    }
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
          leadingWidth: 52,
          leading: PopupMenuButton<int>(
            tooltip: 'Mở menu',
            initialValue: page,
            onSelected: (value) => setState(() => page = value),
            icon: const Icon(Icons.menu_rounded),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: Icon(Icons.piano),
                  title: Text('Nhạc cụ'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: Icon(Icons.grid_on),
                  title: Text('Sequencer'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Mix & Master'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
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
              backing: backing,
              track: track,
              importingTrack: importingTrack,
              onImportTrack: importTrack,
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
    required this.backing,
    required this.track,
    required this.importingTrack,
    required this.onImportTrack,
  });

  final InstrumentType instrument;
  final ValueChanged<InstrumentType> onInstrumentChanged;
  final MixerState mixer;
  final MusicAudioEngine engine;
  final List<InstrumentNote> pianoNotes;
  final List<InstrumentNote> guitarNotes;
  final List<InstrumentNote> synthNotes;
  final BackingTrackService backing;
  final BackingTrack? track;
  final bool importingTrack;
  final VoidCallback onImportTrack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BackingTrackPanel(
          service: backing,
          track: track,
          importing: importingTrack,
          onImport: onImportTrack,
        ),
        const SizedBox(height: 16),
        SegmentedButton<InstrumentType>(
          segments: const [
            ButtonSegment(value: InstrumentType.piano, label: Text('Piano'), icon: Icon(Icons.piano)),
            ButtonSegment(value: InstrumentType.guitar, label: Text('Guitar'), icon: Icon(Icons.music_note)),
            ButtonSegment(value: InstrumentType.synth, label: Text('Dubstep'), icon: Icon(Icons.graphic_eq)),
          ],
          selected: {instrument},
          onSelectionChanged: (value) => onInstrumentChanged(value.first),
        ),
        const SizedBox(height: 16),
        switch (instrument) {
          InstrumentType.guitar => _GuitarStudio(
              notes: guitarNotes,
              engine: engine,
              mixer: mixer,
            ),
          InstrumentType.bass || InstrumentType.synth => _DubstepDeck(
              notes: synthNotes,
              engine: engine,
              mixer: mixer,
            ),
          _ => _PianoStudio(
              notes: pianoNotes,
              engine: engine,
              mixer: mixer,
              backing: backing,
            ),
        },
      ],
    );
  }
}

class _PianoStudio extends StatelessWidget {
  const _PianoStudio({
    required this.notes,
    required this.engine,
    required this.mixer,
    required this.backing,
  });

  final List<InstrumentNote> notes;
  final MusicAudioEngine engine;
  final MixerState mixer;
  final BackingTrackService backing;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff090b12), Color(0xff151826)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: Color(0xff35d6ff)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PIANO • BEAT GUIDE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      'Tap phím để chơi theo',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              StreamBuilder<bool>(
                stream: backing.isPlaying,
                initialData: false,
                builder: (context, snapshot) => _BeatGuide(
                  active: snapshot.data == true,
                  height: 190,
                  laneCount: notes.length,
                ),
              ),
              _PianoKeyboard(
                notes: notes,
                onPlay: (note) => engine.playNote(note, mixer),
              ),
            ],
          ),
        ),
      );
}

class _PianoKeyboard extends StatelessWidget {
  const _PianoKeyboard({required this.notes, required this.onPlay});
  final List<InstrumentNote> notes;
  final ValueChanged<InstrumentNote> onPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 138,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyWidth = constraints.maxWidth / notes.length;
            final blackAfter = List.generate(notes.length - 1, (index) => index)
                .where((index) => !const {2, 6}.contains(index % 7));
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(notes.length, (index) {
                    final note = notes[index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Material(
                          color: const Color(0xfff8f8fb),
                          child: InkWell(
                            onTap: () => onPlay(note),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  note.label,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                ...blackAfter.map((index) {
                  return Positioned(
                    left: keyWidth * (index + 1) - keyWidth * .28,
                    top: 0,
                    width: keyWidth * .56,
                    height: 84,
                    child: Material(
                      elevation: 5,
                      color: const Color(0xff15151a),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                      child: InkWell(
                        onTap: () => onPlay(notes[index + 1]),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
}

class _GuitarStudio extends StatelessWidget {
  const _GuitarStudio({
    required this.notes,
    required this.engine,
    required this.mixer,
  });

  final List<InstrumentNote> notes;
  final MusicAudioEngine engine;
  final MixerState mixer;

  void _playChord(List<int> indexes) {
    for (final index in indexes) {
      engine.playNote(notes[index], mixer, durationMs: 900);
    }
  }

  @override
  Widget build(BuildContext context) {
    const chords = <String, List<int>>{
      'G': [0, 2, 4],
      'D': [1, 2, 5],
      'Am': [1, 3, 4],
      'C': [0, 3, 5],
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xff2a1208), Color(0xff9a5425), Color(0xff261007)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.music_note, color: Color(0xffffa33a)),
              SizedBox(width: 8),
              Text(
                'REAL GUITAR',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Spacer(),
              Text('CHORD • STRUM', style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 290,
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: chords.entries
                        .map(
                          (chord) => Material(
                            color: const Color(0xff262a31),
                            borderRadius: BorderRadius.circular(9),
                            child: InkWell(
                              onTap: () => _playChord(chord.value),
                              borderRadius: BorderRadius.circular(9),
                              child: SizedBox(
                                width: 50,
                                height: 48,
                                child: Center(
                                  child: Text(
                                    chord.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: const _GuitarBoardPainter()),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(notes.length, (index) {
                          final note = notes[index];
                          return Expanded(
                            child: InkWell(
                              onTap: () => engine.playNote(
                                note,
                                mixer,
                                durationMs: 850,
                              ),
                              child: Row(
                                children: [
                                  const Spacer(),
                                  Container(
                                    width: 42,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.primaries[
                                          index % Colors.primaries.length],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      note.label,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuitarBoardPainter extends CustomPainter {
  const _GuitarBoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final board = Paint()..color = const Color(0xdd321a10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(14),
      ),
      board,
    );
    final fret = Paint()
      ..color = const Color(0xffc7a176)
      ..strokeWidth = 2;
    for (var i = 1; i < 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fret);
    }
    for (var i = 0; i < 6; i++) {
      final y = size.height * (i + .5) / 6;
      final string = Paint()
        ..color = const Color(0xfff2dbc0)
        ..strokeWidth = .8 + i * .28;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), string);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DubstepDeck extends StatefulWidget {
  const _DubstepDeck({
    required this.notes,
    required this.engine,
    required this.mixer,
  });

  final List<InstrumentNote> notes;
  final MusicAudioEngine engine;
  final MixerState mixer;

  @override
  State<_DubstepDeck> createState() => _DubstepDeckState();
}

class _DubstepDeckState extends State<_DubstepDeck> {
  final cells = List.generate(6, (_) => List.filled(8, false));

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff071525), Color(0xff0d1328), Color(0xff30104d)],
          ),
          border: Border.all(color: const Color(0xff14dff0), width: .6),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.blur_circular, color: Color(0xff14e6f1)),
                const SizedBox(width: 8),
                const Text(
                  'DUBSTEP LAB',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: const Color(0xff121824),
                  child: const Text(
                    '128 BPM',
                    style: TextStyle(color: Color(0xff40ecff)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: CustomPaint(
                painter: const _WaveformPainter(),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 650;
                final pads = _NeonPads(
                  onTap: (index) => widget.engine.playNote(
                    widget.notes[index % widget.notes.length],
                    widget.mixer,
                    durationMs: 420,
                  ),
                );
                final grid = _PatternGrid(
                  cells: cells,
                  onToggle: (row, column) => setState(
                    () => cells[row][column] = !cells[row][column],
                  ),
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: constraints.maxWidth * .34, child: pads),
                          const SizedBox(width: 14),
                          Expanded(child: grid),
                        ],
                      )
                    : Column(
                        children: [
                          pads,
                          const SizedBox(height: 14),
                          grid,
                        ],
                      );
              },
            ),
          ],
        ),
      );
}

class _NeonPads extends StatelessWidget {
  const _NeonPads({required this.onTap});
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
        ),
        itemCount: 16,
        itemBuilder: (context, index) => Material(
          color: index % 3 == 0
              ? const Color(0xff58efff)
              : const Color(0xff173c5a),
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(7),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index % 3 == 0 ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
}

class _PatternGrid extends StatelessWidget {
  const _PatternGrid({required this.cells, required this.onToggle});
  final List<List<bool>> cells;
  final void Function(int row, int column) onToggle;

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(cells.length, (row) {
          final activeColor = Colors.primaries[(row * 2) % Colors.primaries.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(cells[row].length, (column) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: InkWell(
                        onTap: () => onToggle(row, column),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color: cells[row][column]
                                ? activeColor
                                : const Color(0xff06101e),
                            border: Border.all(
                              color: activeColor.withValues(alpha: .8),
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      );
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffff559f)
      ..strokeWidth = 3;
    for (var i = 0; i < 36; i++) {
      final x = size.width * i / 35;
      final amplitude = 6 + ((i * 17) % 29).toDouble();
      canvas.drawLine(
        Offset(x, (size.height - amplitude) / 2),
        Offset(x, (size.height + amplitude) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackingTrackPanel extends StatelessWidget {
  const _BackingTrackPanel({
    required this.service,
    required this.track,
    required this.importing,
    required this.onImport,
  });

  final BackingTrackService service;
  final BackingTrack? track;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xff191724),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.library_music, color: Color(0xff33d6e8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BACKING TRACK',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                        ),
                        Text(
                          track?.name ?? 'Thêm bài nhạc để đánh theo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: importing ? null : onImport,
                    icon: importing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(track == null ? 'Thêm nhạc' : 'Đổi bài'),
                  ),
                ],
              ),
              if (track != null)
                _TrackTransport(service: service),
            ],
          ),
        ),
      );
}

class _TrackTransport extends StatelessWidget {
  const _TrackTransport({required this.service});
  final BackingTrackService service;

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
        stream: service.duration,
        initialData: service.durationValue,
        builder: (context, durationSnapshot) => StreamBuilder<Duration>(
          stream: service.position,
          initialData: service.positionValue,
          builder: (context, positionSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final maximum =
                duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
            final current =
                position.inMilliseconds.clamp(0, maximum.toInt()).toDouble();
            return Row(
              children: [
                StreamBuilder<bool>(
                  stream: service.isPlaying,
                  initialData: false,
                  builder: (context, snapshot) => IconButton.filled(
                    onPressed: service.toggle,
                    icon: Icon(
                      snapshot.data == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: current,
                    max: maximum,
                    onChanged: (value) => service.seek(
                      Duration(milliseconds: value.round()),
                    ),
                  ),
                ),
                Text(
                  '${_clock(position)} / ${_clock(duration)}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            );
          },
        ),
      );

  static String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _BeatGuide extends StatefulWidget {
  const _BeatGuide({
    required this.active,
    this.height = 58,
    this.laneCount = 8,
  });
  final bool active;
  final double height;
  final int laneCount;

  @override
  State<_BeatGuide> createState() => _BeatGuideState();
}

class _BeatGuideState extends State<_BeatGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didUpdateWidget(covariant _BeatGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.active ? controller.repeat() : controller.stop();
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) controller.repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            painter: _BeatGuidePainter(controller.value, widget.laneCount),
          ),
        ),
      );
}

class _BeatGuidePainter extends CustomPainter {
  const _BeatGuidePainter(this.progress, this.laneCount);
  final double progress;
  final int laneCount;

  @override
  void paint(Canvas canvas, Size size) {
    final laneWidth = size.width / laneCount;
    for (var lane = 0; lane < laneCount; lane++) {
      final paint = Paint()
        ..color = lane.isEven
            ? const Color(0xff33d6e8)
            : const Color(0xffffbd3f);
      final phase = (progress + lane * .17) % 1;
      final top = phase * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lane * laneWidth + 3, top, laneWidth - 6, 18),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BeatGuidePainter oldDelegate) =>
      oldDelegate.progress != progress;
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
