import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/project_repository.dart';
import '../services/media_import_service.dart';
import '../ui/vicys_design.dart';
import 'editor_screen.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({required this.repository, super.key});
  final ProjectRepository repository;

  @override
  State<MediaLibraryScreen> createState() => MediaLibraryScreenState();
}

class MediaLibraryScreenState extends State<MediaLibraryScreen> {
  final MediaImportService _importService = MediaImportService();
  final TextEditingController _searchController = TextEditingController();
  var _query = '';
  late Future<List<MediaProject>> _projects = widget.repository.list();

  @override
  void initState() {
    super.initState();
    unawaited(_recoverLostMedia());
  }

  /// Reloads local projects after capture, import or editor navigation.
  void refresh() => setState(() => _projects = widget.repository.list());

  /// Imports selected device media into durable storage and opens its editor.
  Future<void> importMedia() async {
    try {
      final media = await _importService.importFromGallery();
      if (media.isEmpty) return;
      final kind = media.any((item) => item.kind == ProjectKind.video)
          ? ProjectKind.video
          : ProjectKind.image;
      final project = await widget.repository.create(
        kind,
        title: media.first.originalName,
        sourcePaths: media.map((item) => item.path).toList(growable: false),
      );
      await _open(project);
    } catch (_) {
      _showError('Không thể nhập media. File gốc của bạn vẫn an toàn.');
    }
  }

  /// Restores picker output after Android recreates the application Activity.
  Future<void> _recoverLostMedia() async {
    try {
      final media = await _importService.recoverLostData();
      if (media.isEmpty) return;
      final kind = media.any((item) => item.kind == ProjectKind.video)
          ? ProjectKind.video
          : ProjectKind.image;
      await widget.repository.create(
        kind,
        title: media.first.originalName,
        sourcePaths: media.map((item) => item.path).toList(growable: false),
      );
      if (mounted) refresh();
    } catch (_) {
      _showError('Không thể phục hồi media đã chọn trước đó.');
    }
  }

  /// Creates a blank project of [kind] and opens the matching editor.
  Future<void> create(ProjectKind kind) async {
    final project = await widget.repository.create(kind);
    await _open(project);
  }

  Future<void> _open(MediaProject project) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditorScreen(
        project: project,
        repository: widget.repository,
      ),
    ));
    refresh();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        _LibraryHeader(onImport: importMedia),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Tìm trong thư viện',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const _LibraryTabs(),
        Expanded(
          child: FutureBuilder<List<MediaProject>>(
            future: _projects,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _LibraryError(onRetry: refresh);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final projects = snapshot.data!
                  .where((project) =>
                      project.title.toLowerCase().contains(_query))
                  .toList(growable: false);
              if (projects.isEmpty) {
                return _EmptyLibrary(
                  searching: _query.isNotEmpty,
                  onImport: importMedia,
                  onCreatePhoto: () => create(ProjectKind.image),
                  onCreateVideo: () => create(ProjectKind.video),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => refresh(),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    childAspectRatio: .76,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (_, index) => _MediaTile(
                    project: projects[index],
                    onTap: () => _open(projects[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ]);
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () {},
            icon: const Icon(
              Icons.settings_outlined,
              color: VicysColors.primary,
            ),
          ),
          const Expanded(child: Center(child: VicysWordmark())),
          TextButton(
            onPressed: onImport,
            child: const Text('Chọn'),
          ),
          IconButton(
            tooltip: 'Hồ sơ',
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ]),
      );
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          _TabLabel(label: 'Tất cả', selected: true),
          _TabLabel(label: 'Album'),
          _TabLabel(label: 'Gần đây'),
        ]),
      );
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 30),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: selected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: VicysColors.primary,
                    width: 3,
                  ),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected
                ? VicysColors.primary
                : VicysColors.outline,
          ),
        ),
      );
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.project, required this.onTap});
  final MediaProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = project.sourcePaths.firstOrNull;
    return Semantics(
      button: true,
      label: 'Mở ${project.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(fit: StackFit.expand, children: [
            if (path != null && project.kind == ProjectKind.image)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, __, ___) => const _TilePlaceholder(),
              )
            else
              const _TilePlaceholder(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xaa000000)],
                  stops: [.55, 1],
                ),
              ),
            ),
            if (project.kind == ProjectKind.video)
              const Center(
                child: CircleAvatar(
                  backgroundColor: Color(0x99000000),
                  child: Icon(Icons.play_arrow),
                ),
              ),
            Positioned(
              left: 7,
              right: 7,
              bottom: 7,
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: VicysColors.surfaceHigh,
        child: Center(
          child: Icon(Icons.image_outlined, color: VicysColors.outline),
        ),
      );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.searching,
    required this.onImport,
    required this.onCreatePhoto,
    required this.onCreateVideo,
  });

  final bool searching;
  final VoidCallback onImport;
  final VoidCallback onCreatePhoto;
  final VoidCallback onCreateVideo;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              searching
                  ? Icons.search_off_outlined
                  : Icons.photo_library_outlined,
              size: 60,
              color: VicysColors.outline,
            ),
            const SizedBox(height: 14),
            Text(
              searching
                  ? 'Không tìm thấy dự án'
                  : 'Thư viện đang trống',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              const Text(
                'Nhập media hoặc bắt đầu một canvas mới.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Nhập từ thiết bị'),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                  onPressed: onCreatePhoto,
                  child: const Text('Ảnh mới'),
                ),
                TextButton(
                  onPressed: onCreateVideo,
                  child: const Text('Video mới'),
                ),
              ]),
            ],
          ]),
        ),
      );
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 52),
          const SizedBox(height: 12),
          const Text('Không thể mở thư viện. Dữ liệu vẫn an toàn.'),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
