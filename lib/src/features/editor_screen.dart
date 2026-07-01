import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/project_repository.dart';
import '../services/services.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.project, required this.repository, super.key});
  final MediaProject project;
  final ProjectRepository repository;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditHistory history = EditHistory(widget.project);
  late final AutosaveController autosave = AutosaveController(widget.repository);
  final renderService = DemoRenderService();

  void apply(String type) {
    setState(() => history.apply(EditOperation(type: type)));
    autosave.schedule(history.project);
  }

  Future<void> export() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đang xuất'),
        content: StreamBuilder<double>(
          stream: renderService.export(history.project),
          builder: (context, snapshot) {
            final progress = snapshot.data ?? 0;
            if (progress == 1) {
              Future<void>.delayed(Duration.zero, () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hoàn thành bản xuất demo')),
                );
              });
            }
            return LinearProgressIndicator(value: progress);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    autosave.dispose();
    widget.repository.save(history.project);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = history.project.kind == ProjectKind.image
        ? const [('Cắt', Icons.crop), ('Màu', Icons.tune), ('Filter', Icons.filter_vintage),
            ('Chữ', Icons.text_fields), ('Sticker', Icons.emoji_emotions_outlined), ('Vẽ', Icons.brush)]
        : const [('Cắt', Icons.content_cut), ('Tách', Icons.call_split), ('Tốc độ', Icons.speed),
            ('Màu', Icons.tune), ('Chữ', Icons.text_fields), ('Nhạc', Icons.music_note), ('Chuyển cảnh', Icons.auto_awesome)];
    return Scaffold(
      appBar: AppBar(
        title: Text(history.project.title),
        actions: [
          IconButton(onPressed: history.canUndo ? () => setState(history.undo) : null, icon: const Icon(Icons.undo)),
          IconButton(onPressed: history.canRedo ? () => setState(history.redo) : null, icon: const Icon(Icons.redo)),
          TextButton(onPressed: export, child: const Text('Xuất')),
        ],
      ),
      body: Column(children: [
        Expanded(child: Center(child: AspectRatio(
          aspectRatio: history.project.kind == ProjectKind.image ? 1 : 9 / 16,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xff202027), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Icon(
              history.project.kind == ProjectKind.image ? Icons.image_outlined : Icons.play_circle_outline,
              size: 80, color: Colors.white24,
            )),
          ),
        ))),
        if (history.project.kind == ProjectKind.video)
          Container(height: 74, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xff25252d), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [Icon(Icons.play_arrow), SizedBox(width: 8),
              Expanded(child: LinearProgressIndicator(value: .28)), SizedBox(width: 8), Text('00:08 / 00:30')])),
        SizedBox(height: 92, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: tools.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => InkWell(
            onTap: () => apply(tools[index].$1),
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 68, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(tools[index].$2), const SizedBox(height: 6), Text(tools[index].$1, maxLines: 1),
            ])),
          ),
        )),
      ]),
    );
  }
}
