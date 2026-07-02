import 'package:flutter_test/flutter_test.dart';
import 'package:pulseforge/src/music/music_models.dart';

void main() {
  test('step pattern toggles cells independently', () {
    final pattern = StepPattern();

    pattern.toggle(2, 7);

    expect(pattern.cells[2][7], isTrue);
    expect(pattern.cells[0][7], isFalse);
  });

  test('mixer returns the correct channel volume', () {
    const mixer = MixerState(piano: .2, guitar: .3, bass: .4, drums: .5);

    expect(mixer.volumeFor(InstrumentType.piano), .2);
    expect(mixer.volumeFor(InstrumentType.guitar), .3);
    expect(mixer.volumeFor(InstrumentType.synth), .4);
    expect(mixer.volumeFor(InstrumentType.drums), .5);
  });
}
