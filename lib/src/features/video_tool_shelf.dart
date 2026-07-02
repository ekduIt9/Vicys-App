import 'package:flutter/material.dart';

import '../ui/vicys_design.dart';

/// Main editor categories shown in the supplied bottom shelf.
enum VideoToolCategory { edit, effects, stickers, audio, text }

/// CapCut-style two-level tool shelf matching the supplied editor reference.
class VideoToolShelf extends StatefulWidget {
  const VideoToolShelf({required this.onToolSelected, super.key});

  final ValueChanged<String> onToolSelected;

  @override
  State<VideoToolShelf> createState() => _VideoToolShelfState();
}

class _VideoToolShelfState extends State<VideoToolShelf> {
  VideoToolCategory selectedCategory = VideoToolCategory.edit;

  static const categories = <VideoToolCategory, (String, IconData)>{
    VideoToolCategory.edit: ('Sửa', Icons.edit),
    VideoToolCategory.effects: ('Hiệu ứng', Icons.auto_awesome),
    VideoToolCategory.stickers: ('Sticker', Icons.sticky_note_2_outlined),
    VideoToolCategory.audio: ('Âm thanh', Icons.music_note),
    VideoToolCategory.text: ('Chữ', Icons.title),
  };

  static const tools = <VideoToolCategory, List<(String, IconData)>>{
    VideoToolCategory.edit: [
      ('Cắt', Icons.content_cut),
      ('Tách', Icons.call_split),
      ('Tốc độ', Icons.speed),
      ('Âm lượng', Icons.volume_up_outlined),
      ('Canvas', Icons.aspect_ratio),
    ],
    VideoToolCategory.effects: [
      ('Màu', Icons.filter_vintage),
      ('Chuyển cảnh', Icons.animation),
    ],
    VideoToolCategory.stickers: [
      ('Sticker', Icons.emoji_emotions_outlined),
    ],
    VideoToolCategory.audio: [
      ('Nhạc', Icons.library_music_outlined),
      ('Âm lượng', Icons.volume_up_outlined),
    ],
    VideoToolCategory.text: [
      ('Chữ', Icons.text_fields),
    ],
  };

  @override
  Widget build(BuildContext context) => Material(
        color: VicysColors.surfaceLow,
        child: SizedBox(
          height: 142,
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: tools[selectedCategory]!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tool = tools[selectedCategory]![index];
                    return _ShelfButton(
                      label: tool.$1,
                      icon: tool.$2,
                      onTap: () => widget.onToolSelected(tool.$1),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 66,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: VideoToolCategory.values.map((category) {
                    final item = categories[category]!;
                    final selected = category == selectedCategory;
                    return _ShelfButton(
                      label: item.$1,
                      icon: item.$2,
                      selected: selected,
                      onTap: () => setState(() => selectedCategory = category),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ShelfButton extends StatelessWidget {
  const _ShelfButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 58, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? VicysColors.primary : VicysColors.outline,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        selected ? VicysColors.primary : VicysColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
