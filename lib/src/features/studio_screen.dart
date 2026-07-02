import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/project_repository.dart';
import '../ui/vicys_design.dart';
import 'editor_screen.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({
    required this.repository,
    required this.openLibrary,
    super.key,
  });

  final ProjectRepository repository;
  final VoidCallback openLibrary;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          const Row(children: [
            Expanded(child: VicysWordmark()),
            Icon(Icons.auto_awesome, color: VicysColors.primary),
          ]),
          const SizedBox(height: 26),
          Text(
            'Tạo chất riêng.',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chụp, chỉnh sửa và kể câu chuyện theo cách của bạn.',
            style: TextStyle(color: VicysColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _CreateCard(
            title: 'Photo Studio',
            description: 'Filter, màu sắc, blur và vignette không phá hủy.',
            icon: Icons.auto_fix_high,
            color: VicysColors.secondary,
            onTap: () async {
              final project =
                  await repository.create(ProjectKind.image);
              if (!context.mounted) return;
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => EditorScreen(
                  project: project,
                  repository: repository,
                ),
              ));
            },
          ),
          const SizedBox(height: 12),
          _CreateCard(
            title: 'Video Studio',
            description: 'Timeline nhiều lớp cho clip, text và audio.',
            icon: Icons.movie_edit_outlined,
            color: VicysColors.primary,
            onTap: openLibrary,
          ),
          const SizedBox(height: 22),
          const MonoLabel('Khám phá công cụ'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeatureChip(Icons.filter_vintage, 'Filters'),
              _FeatureChip(Icons.text_fields, 'Text'),
              _FeatureChip(Icons.music_note, 'Audio'),
              _FeatureChip(Icons.layers_outlined, 'Overlay'),
              _FeatureChip(Icons.speed, 'Speed'),
              _FeatureChip(Icons.auto_awesome, 'Effects'),
            ],
          ),
        ],
      );
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: VicysColors.onSurfaceVariant,
                    ),
                  ),
                ],
              )),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ]),
          ),
        ),
      );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 18, color: VicysColors.primary),
        label: Text(label),
        backgroundColor: VicysColors.surfaceLow,
        side: const BorderSide(color: Color(0x18ffffff)),
      );
}
