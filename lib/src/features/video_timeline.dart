import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/models.dart';
import '../core/video_editing.dart';
import '../ui/vicys_design.dart';

/// Lightweight timeline transport and source-clip selector.
class VideoTimeline extends StatelessWidget {
  const VideoTimeline({
    required this.project,
    required this.position,
    required this.duration,
    required this.selectedClip,
    required this.onSelectedClip,
    required this.onSeek,
    required this.onTogglePlayback,
    required this.onUndo,
    required this.onRedo,
    super.key,
  });

  final MediaProject project;
  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;
  final int selectedClip;
  final ValueChanged<int> onSelectedClip;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlayback;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) => Container(
        height: 250,
        decoration: const BoxDecoration(
          color: VicysColors.surfaceLow,
          border: Border(top: BorderSide(color: Color(0x14ffffff))),
        ),
        child: Column(
          children: [
            _TransportBar(
              position: position,
              duration: duration,
              onSeek: onSeek,
              onTogglePlayback: onTogglePlayback,
              onUndo: onUndo,
              onRedo: onRedo,
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  final composition = VideoComposition.fromProject(project);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    children: [
                      if (composition.text != null)
                        _LayerRow(
                          label: 'TEXT',
                          value: composition.text!,
                          color: VicysColors.secondary,
                        ),
                      if (composition.sticker != null)
                        _LayerRow(
                          label: 'STICKER',
                          value: composition.sticker!,
                          color: VicysColors.primary,
                        ),
                      _VideoTrack(
                        project: project,
                        selectedClip: selectedClip,
                        onSelectedClip: onSelectedClip,
                      ),
                      if (composition.audioPath != null)
                        _LayerRow(
                          label: 'AUDIO',
                          value: path.basename(composition.audioPath!),
                          color: VicysColors.tertiary,
                        ),
                      if (composition.transition != VideoTransition.none)
                        _LayerRow(
                          label: 'FX',
                          value: composition.transition.name,
                          color: VicysColors.primary,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _VideoTrack extends StatelessWidget {
  const _VideoTrack({
    required this.project,
    required this.selectedClip,
    required this.onSelectedClip,
  });

  final MediaProject project;
  final int selectedClip;
  final ValueChanged<int> onSelectedClip;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: Row(
          children: [
            const SizedBox(
              width: 62,
              child: MonoLabel(
                'VIDEO',
                fontSize: 9,
                color: VicysColors.outline,
              ),
            ),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: project.sourcePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => _ClipTile(
                  label: path.basename(project.sourcePaths[index]),
                  selected: index == selectedClip,
                  onTap: () => onSelectedClip(index),
                ),
              ),
            ),
          ],
        ),
      );
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: MonoLabel(label, fontSize: 8, color: VicysColors.outline),
            ),
            Expanded(
              child: Container(
                height: 25,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  border: Border.all(color: color.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      );
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onTogglePlayback,
    required this.onUndo,
    required this.onRedo,
  });

  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlayback;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
        valueListenable: duration,
        builder: (context, total, _) => ValueListenableBuilder<Duration>(
          valueListenable: position,
          builder: (context, current, _) {
            final maximum = total.inMilliseconds.clamp(1, 1 << 31).toDouble();
            final value =
                current.inMilliseconds.clamp(0, maximum.toInt()).toDouble();
            return SizedBox(
              height: 58,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Phát hoặc tạm dừng',
                    onPressed: onTogglePlayback,
                    icon: const Icon(Icons.play_arrow),
                  ),
                  Text(
                    '${_time(current)} / ${_time(total)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: value,
                      max: maximum,
                      onChanged: (milliseconds) => onSeek(
                        Duration(milliseconds: milliseconds.round()),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hoàn tác',
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Làm lại',
                    onPressed: onRedo,
                    icon: const Icon(Icons.redo, size: 20),
                  ),
                ],
              ),
            );
          },
        ),
      );

  static String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VicysColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? VicysColors.primary : VicysColors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_outlined, color: VicysColors.primary),
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
