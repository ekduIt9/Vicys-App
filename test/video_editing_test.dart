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
}
