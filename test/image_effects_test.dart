import 'package:flutter_test/flutter_test.dart';
import 'package:studio_social/src/core/image_effects.dart';
import 'package:studio_social/src/core/models.dart';

void main() {
  test('effect operation survives project serialization', () {
    final now = DateTime.utc(2026, 7, 2);
    final settings = const ImageEffectSettings().copyWith(
      preset: ImagePreset.vintage,
      brightness: .25,
      vignette: .6,
    );
    final project = MediaProject(
      id: 'image-project',
      title: 'Portrait',
      kind: ProjectKind.image,
      createdAt: now,
      updatedAt: now,
      operations: [settings.toOperation()],
    );

    final restored = ImageEffectSettings.fromProject(
      MediaProject.decode(project.encode()),
    );

    expect(restored.preset, ImagePreset.vintage);
    expect(restored.brightness, .25);
    expect(restored.vignette, .6);
  });

  test('invalid effect values are clamped safely', () {
    final settings = ImageEffectSettings.fromParameters({
      'brightness': 5,
      'contrast': -9,
      'blur': 99,
      'vignette': -4,
    });

    expect(settings.brightness, 1);
    expect(settings.contrast, -1);
    expect(settings.blur, 10);
    expect(settings.vignette, 0);
  });

  test('combined color matrix has Flutter expected dimensions', () {
    final matrix = const ImageEffectSettings(
      preset: ImagePreset.vivid,
      brightness: .1,
      contrast: .2,
      warmth: -.3,
    ).colorMatrix;

    expect(matrix, hasLength(20));
    expect(matrix.every((value) => value.isFinite), isTrue);
  });
}
