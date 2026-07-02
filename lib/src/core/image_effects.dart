import 'dart:math' as math;

import 'models.dart';

enum ImagePreset { original, vivid, mono, vintage, cool }

class ImageEffectSettings {
  const ImageEffectSettings({
    this.preset = ImagePreset.original,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.blur = 0,
    this.vignette = 0,
  });

  static const operationType = 'image_effects';

  final ImagePreset preset;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double blur;
  final double vignette;

  ImageEffectSettings copyWith({
    ImagePreset? preset,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? blur,
    double? vignette,
  }) =>
      ImageEffectSettings(
        preset: preset ?? this.preset,
        brightness: _unit(brightness ?? this.brightness),
        contrast: _unit(contrast ?? this.contrast),
        saturation: _unit(saturation ?? this.saturation),
        warmth: _unit(warmth ?? this.warmth),
        blur: (blur ?? this.blur).clamp(0, 10).toDouble(),
        vignette: (vignette ?? this.vignette).clamp(0, 1).toDouble(),
      );

  /// Restores the latest non-destructive image effect operation in a project.
  ///
  /// Unknown or missing values fall back to neutral settings so older projects
  /// remain readable. This performs no file I/O or pixel processing.
  factory ImageEffectSettings.fromProject(MediaProject project) {
    final matches = project.operations
        .where((operation) => operation.type == operationType);
    if (matches.isEmpty) return const ImageEffectSettings();
    return ImageEffectSettings.fromParameters(matches.last.parameters);
  }

  factory ImageEffectSettings.fromParameters(
    Map<String, Object?> parameters,
  ) {
    final presetName = parameters['preset'] as String?;
    return ImageEffectSettings(
      preset: ImagePreset.values
          .where((value) => value.name == presetName)
          .firstOrNull ??
          ImagePreset.original,
      brightness:
          _number(parameters['brightness']).clamp(-1, 1).toDouble(),
      contrast: _number(parameters['contrast']).clamp(-1, 1).toDouble(),
      saturation:
          _number(parameters['saturation']).clamp(-1, 1).toDouble(),
      warmth: _number(parameters['warmth']).clamp(-1, 1).toDouble(),
      blur: _number(parameters['blur']).clamp(0, 10).toDouble(),
      vignette: _number(parameters['vignette']).clamp(0, 1).toDouble(),
    );
  }

  EditOperation toOperation() => EditOperation(
        type: operationType,
        parameters: {
          'preset': preset.name,
          'brightness': brightness,
          'contrast': contrast,
          'saturation': saturation,
          'warmth': warmth,
          'blur': blur,
          'vignette': vignette,
        },
      );

  /// Builds one 4×5 affine color matrix for GPU preview.
  ///
  /// Preset and manual adjustment matrices are multiplied once per settings
  /// change, not once per frame. Values are clamped by constructors to prevent
  /// invalid color amplification. The source image is never decoded here.
  List<double> get colorMatrix {
    var matrix = _presetMatrix(preset);
    matrix = _multiply(_brightnessMatrix(brightness), matrix);
    matrix = _multiply(_contrastMatrix(contrast), matrix);
    matrix = _multiply(_saturationMatrix(saturation), matrix);
    matrix = _multiply(_warmthMatrix(warmth), matrix);
    return matrix;
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : 0;

  static double _unit(double value) => value.clamp(-1, 1).toDouble();

  static List<double> _presetMatrix(ImagePreset preset) => switch (preset) {
        ImagePreset.original => _identity,
        ImagePreset.vivid => _saturationMatrix(.35),
        ImagePreset.mono => _saturationMatrix(-1),
        ImagePreset.vintage => const [
            .9, .18, .04, 0, 10,
            .08, .82, .04, 0, 4,
            .03, .12, .72, 0, -2,
            0, 0, 0, 1, 0,
          ],
        ImagePreset.cool => const [
            .94, 0, .03, 0, -3,
            0, 1, .04, 0, 0,
            .02, .04, 1.08, 0, 7,
            0, 0, 0, 1, 0,
          ],
      };

  static List<double> _brightnessMatrix(double value) {
    final offset = value * 90;
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset,
      0, 0, 1, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> _contrastMatrix(double value) {
    final scale = math.max(.05, 1 + value).toDouble();
    final offset = 128 * (1 - scale);
    return [
      scale, 0, 0, 0, offset,
      0, scale, 0, 0, offset,
      0, 0, scale, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> _saturationMatrix(double value) {
    final scale = math.max(0, 1 + value).toDouble();
    const red = .2126;
    const green = .7152;
    const blue = .0722;
    final inverse = 1 - scale;
    return [
      inverse * red + scale,
      inverse * green,
      inverse * blue,
      0,
      0,
      inverse * red,
      inverse * green + scale,
      inverse * blue,
      0,
      0,
      inverse * red,
      inverse * green,
      inverse * blue + scale,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _warmthMatrix(double value) {
    final offset = value * 35;
    return [
      1, 0, 0, 0, offset,
      0, 1, 0, 0, offset * .15,
      0, 0, 1, 0, -offset,
      0, 0, 0, 1, 0,
    ];
  }

  /// Composes affine 4×5 matrices using an implicit final identity row.
  static List<double> _multiply(List<double> left, List<double> right) {
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 5; column++) {
        var value = column == 4 ? left[row * 5 + 4] : 0.0;
        for (var index = 0; index < 4; index++) {
          value += left[row * 5 + index] *
              right[index * 5 + column];
        }
        result[row * 5 + column] = value;
      }
    }
    return result;
  }

  static const List<double> _identity = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
