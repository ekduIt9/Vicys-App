import 'package:flutter_test/flutter_test.dart';
import 'package:studio_social/src/core/models.dart';
import 'package:studio_social/src/core/video_editing.dart';

void main() {
  final now = DateTime(2026);

  MediaProject projectWith(List<EditOperation> operations) => MediaProject(
        id: 'video-1',
        title: 'Video',
        kind: ProjectKind.video,
        createdAt: now,
        updatedAt: now,
        sourcePaths: const ['/media/source.mp4'],
        operations: operations,
      );

  test('video operations rebuild the latest effective clip settings', () {
    final project = projectWith([
      createTrimOperation(
        clipIndex: 0,
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 8),
      ),
      createSpeedOperation(clipIndex: 0, speed: 1.5),
      createVolumeOperation(clipIndex: 0, volume: .4),
      createSpeedOperation(clipIndex: 0, speed: 2),
    ]);

    final clip = VideoClipEdit.fromProject(project, 0);

    expect(clip.trimStart, const Duration(seconds: 1));
    expect(clip.trimEnd, const Duration(seconds: 8));
    expect(clip.speed, 2);
    expect(clip.volume, .4);
  });

  test('invalid trim, speed and volume values are rejected', () {
    expect(
      () => createTrimOperation(
        clipIndex: 0,
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 1),
      ),
      throwsArgumentError,
    );
    expect(
      () => createSpeedOperation(clipIndex: 0, speed: 5),
      throwsArgumentError,
    );
    expect(
      () => createVolumeOperation(clipIndex: 0, volume: -1),
      throwsArgumentError,
    );
  });

  test('composition rebuilds visual, audio and canvas settings', () {
    final project = projectWith([
      createVideoSettingOperation(
        VideoEditOperation.filter,
        VideoFilter.cinematic.name,
      ),
      createVideoSettingOperation(VideoEditOperation.text, 'Vicys'),
      createVideoSettingOperation(VideoEditOperation.sticker, '✨'),
      createVideoSettingOperation(VideoEditOperation.audio, '/audio/music.mp3'),
      createVideoSettingOperation(
        VideoEditOperation.transition,
        VideoTransition.fade.name,
      ),
      createVideoSettingOperation(VideoEditOperation.canvas, 16 / 9),
    ]);

    final composition = VideoComposition.fromProject(project);

    expect(composition.filter, VideoFilter.cinematic);
    expect(composition.text, 'Vicys');
    expect(composition.sticker, '✨');
    expect(composition.audioPath, '/audio/music.mp3');
    expect(composition.transition, VideoTransition.fade);
    expect(composition.aspectRatio, closeTo(16 / 9, .001));
  });

  test('unknown composition values safely use defaults', () {
    final project = projectWith([
      createVideoSettingOperation(VideoEditOperation.filter, 'missing'),
      createVideoSettingOperation(VideoEditOperation.transition, 'missing'),
      createVideoSettingOperation(VideoEditOperation.canvas, -1),
    ]);

    final composition = VideoComposition.fromProject(project);

    expect(composition.filter, VideoFilter.original);
    expect(composition.transition, VideoTransition.none);
    expect(composition.aspectRatio, closeTo(9 / 16, .001));
  });

  test('nullable overlay and audio operations remove previous values', () {
    final project = projectWith([
      createVideoSettingOperation(VideoEditOperation.text, 'Title'),
      createVideoSettingOperation(VideoEditOperation.audio, '/audio/a.mp3'),
      createVideoSettingOperation(VideoEditOperation.text, null),
      createVideoSettingOperation(VideoEditOperation.audio, null),
    ]);

    final composition = VideoComposition.fromProject(project);

    expect(composition.text, isNull);
    expect(composition.audioPath, isNull);
  });

  test('sticker position is normalized and latest drag wins', () {
    final project = projectWith([
      createStickerOperation(sticker: '✨', x: -.5, y: 2),
      createStickerOperation(sticker: '✨', x: .25, y: .75),
    ]);

    final composition = VideoComposition.fromProject(project);

    expect(composition.sticker, '✨');
    expect(composition.stickerX, .25);
    expect(composition.stickerY, .75);
  });
}
