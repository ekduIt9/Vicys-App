import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../core/models.dart';
import '../ui/vicys_design.dart';

class VideoTimeline extends StatefulWidget {
  const VideoTimeline({
    required this.project,
    required this.onOperation,
    super.key,
  });

  final MediaProject project;
  final ValueChanged<String> onOperation;

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

class _VideoTimelineState extends State<VideoTimeline> {
  double _position = .22;
  int _selectedClip = 0;

  @override
  Widget build(BuildContext context) => Container(
        height: 240,
        decoration: const BoxDecoration(
          color: VicysColors.surfaceLow,
          border: Border(top: BorderSide(color: Color(0x14ffffff))),
        ),
        child: Column(children: [
          SizedBox(
            height: 42,
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.horizontal_rule, color: VicysColors.primary),
              const SizedBox(width: 5),
              const MonoLabel(
                'Main track',
                color: VicysColors.primary,
                fontSize: 9,
              ),
              Expanded(
                child: Slider(
                  value: _position,
                  onChanged: (value) => setState(() => _position = value),
                ),
              ),
              IconButton(
                onPressed: () => widget.onOperation('timeline_undo'),
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton(
                onPressed: () => widget.onOperation('timeline_redo'),
                icon: const Icon(Icons.redo, size: 20),
              ),
            ]),
          ),
          const SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MonoLabel('00:00', fontSize: 9),
                MonoLabel('00:05', fontSize: 9),
                MonoLabel('00:10', fontSize: 9),
                MonoLabel('00:15', fontSize: 9),
              ],
            ),
          ),
          Expanded(
            child: Stack(children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                children: [
                  _Track(
                    label: 'TEXT',
                    child: _TrackBlock(
                      label: 'T  Văn bản',
                      color: VicysColors.secondary,
                      width: 120,
                      onTap: () => widget.onOperation('select_text_track'),
                    ),
                  ),
                  _Track(
                    label: 'OVERLAY',
                    child: _TrackBlock(
                      label: '◇  Filter',
                      color: VicysColors.primary,
                      width: 92,
                      onTap: () => widget.onOperation('select_overlay_track'),
                    ),
                  ),
                  _Track(
                    label: 'VIDEO',
                    height: 52,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          widget.project.sourcePaths.isEmpty
                              ? 1
                              : widget.project.sourcePaths.length,
                          _buildClip,
                        ),
                      ),
                    ),
                  ),
                  _Track(
                    label: 'AUDIO',
                    height: 38,
                    child: _AudioWaveform(
                      onTap: () => widget.onOperation('select_audio_track'),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 74 + _position * 220,
                top: 0,
                bottom: 0,
                child: const IgnorePointer(child: _Playhead()),
              ),
            ]),
          ),
        ]),
      );

  Widget _buildClip(int index) => GestureDetector(
        onTap: () => setState(() => _selectedClip = index),
        child: Container(
          width: 148,
          margin: const EdgeInsets.only(right: 5),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: VicysColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: index == _selectedClip
                  ? VicysColors.primary
                  : VicysColors.outlineVariant,
              width: index == _selectedClip ? 2 : 1,
            ),
          ),
          alignment: Alignment.bottomLeft,
          child: MonoLabel(
            widget.project.sourcePaths.isEmpty
                ? 'CLIP TRỐNG'
                : path.basename(widget.project.sourcePaths[index]),
            fontSize: 9,
            color: VicysColors.primary,
          ),
        ),
      );
}

class _Track extends StatelessWidget {
  const _Track({
    required this.label,
    required this.child,
    this.height = 30,
  });

  final String label;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Row(children: [
          SizedBox(
            width: 64,
            child: MonoLabel(
              label,
              fontSize: 8,
              color: VicysColors.outline,
            ),
          ),
          Expanded(child: child),
        ]),
      );
}

class _TrackBlock extends StatelessWidget {
  const _TrackBlock({
    required this.label,
    required this.color,
    required this.width,
    required this.onTap,
  });

  final String label;
  final Color color;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: width,
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withValues(alpha: .55)),
            ),
            child: Text(label, style: TextStyle(fontSize: 10, color: color)),
          ),
        ),
      );
}

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: VicysColors.tertiary.withValues(alpha: .08),
            border: Border.all(
              color: VicysColors.tertiary.withValues(alpha: .35),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: List.generate(
              28,
              (index) => Container(
                width: 2,
                height: 6 + (index * 7 % 19).toDouble(),
                margin: const EdgeInsets.only(left: 3),
                color: VicysColors.tertiary.withValues(alpha: .7),
              ),
            ),
          ),
        ),
      );
}

class _Playhead extends StatelessWidget {
  const _Playhead();

  @override
  Widget build(BuildContext context) => Column(children: [
        Transform.rotate(
          angle: .78,
          child: Container(
            width: 12,
            height: 12,
            color: VicysColors.primary,
          ),
        ),
        Expanded(child: Container(width: 2, color: VicysColors.primary)),
      ]);
}
