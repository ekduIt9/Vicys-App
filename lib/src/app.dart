import 'package:flutter/material.dart';

import 'core/models.dart';
import 'data/project_repository.dart';
import 'features/editor_screen.dart';

class StudioSocialApp extends StatelessWidget {
  const StudioSocialApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Studio Social',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xff8b5cf6),
          scaffoldBackgroundColor: const Color(0xff0b0b0f),
          useMaterial3: true,
        ),
        home: const MainShell(),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ProjectRepository repository = LocalProjectRepository();
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProjectsPage(repository: repository),
      const CameraPage(),
      const FeedPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: selectedIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Dự án'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Khám phá'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({required this.repository, super.key});
  final ProjectRepository repository;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late Future<List<MediaProject>> projects = widget.repository.list();

  Future<void> create(ProjectKind kind) async {
    final project = await widget.repository.create(kind);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditorScreen(project: project, repository: widget.repository),
    ));
    setState(() => projects = widget.repository.list());
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Studio của bạn', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Tạo, chỉnh sửa và chia sẻ câu chuyện của riêng bạn.'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () => create(ProjectKind.image),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chỉnh ảnh'),
            )),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.tonalIcon(
              onPressed: () => create(ProjectKind.video),
              icon: const Icon(Icons.movie_outlined),
              label: const Text('Dựng video'),
            )),
          ]),
          const SizedBox(height: 24),
          Text('Gần đây', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(child: FutureBuilder<List<MediaProject>>(
            future: projects,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('Chưa có dự án. Hãy tạo tác phẩm đầu tiên!'));
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: .85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final project = snapshot.data![index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => EditorScreen(project: project, repository: widget.repository),
                        ));
                        setState(() => projects = widget.repository.list());
                      },
                      child: Column(children: [
                        Expanded(child: ColoredBox(
                          color: const Color(0xff27272f),
                          child: Center(child: Icon(
                            project.kind == ProjectKind.image ? Icons.image : Icons.movie,
                            size: 48,
                          )),
                        )),
                        ListTile(
                          title: Text(project.title, maxLines: 1),
                          subtitle: Text('Phiên bản ${project.revision}'),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          )),
        ]),
      );
}

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const ColoredBox(
          color: Color(0xff18181e),
          child: Center(child: Icon(Icons.camera_alt_outlined, size: 96, color: Colors.white24)),
        ),
        const Positioned(top: 20, left: 20, right: 20, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Icon(Icons.flash_off), Text('9:16'), Icon(Icons.timer_outlined)],
        )),
        Positioned(bottom: 32, left: 0, right: 0, child: Column(children: [
          const Text('Camera native sẽ được kết nối tại đây'),
          const SizedBox(height: 18),
          Container(width: 76, height: 76, decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5))),
          const SizedBox(height: 18),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Chip(label: Text('ẢNH')), SizedBox(width: 8), Chip(label: Text('VIDEO')),
          ]),
        ])),
      ]);
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final posts = [
      SocialPost(id: '1', author: '@minhstudio', caption: 'Một buổi chiều rất tím ✨',
          kind: ProjectKind.video, createdAt: nullDate, likes: 128, comments: 14),
      SocialPost(id: '2', author: '@lan.photo', caption: 'Chân dung với ánh sáng tự nhiên',
          kind: ProjectKind.image, createdAt: nullDate, likes: 86, comments: 9),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text('Đang theo dõi', style: Theme.of(context).textTheme.headlineMedium),
        );
        final post = posts[index - 1];
        return Card(margin: const EdgeInsets.only(bottom: 18), clipBehavior: Clip.antiAlias, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(post.author),
              trailing: const Icon(Icons.more_horiz)),
            AspectRatio(aspectRatio: post.kind == ProjectKind.video ? 9 / 12 : 1,
              child: ColoredBox(color: const Color(0xff27272f),
                child: Center(child: Icon(post.kind == ProjectKind.video ? Icons.play_circle : Icons.image, size: 64)))),
            Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.favorite_border), const SizedBox(width: 6), Text('${post.likes}'),
                const SizedBox(width: 18), const Icon(Icons.chat_bubble_outline), const SizedBox(width: 6), Text('${post.comments}'),
                const Spacer(), const Icon(Icons.bookmark_border)]),
              const SizedBox(height: 10), Text(post.caption),
            ])),
          ],
        ));
      },
    );
  }
}

final nullDate = DateTime.fromMillisecondsSinceEpoch(0);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
        const SizedBox(height: 12),
        Text('Khách', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const Text('@studio_guest', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Stat(value: '0', label: 'Bài đăng'),
          _Stat(value: '0', label: 'Người theo dõi'),
          _Stat(value: '0', label: 'Đang theo dõi'),
        ]),
        const SizedBox(height: 24),
        FilledButton(onPressed: null, child: Text('Đăng nhập để đồng bộ')),
        const ListTile(leading: Icon(Icons.cloud_outlined), title: Text('Cloud'),
          subtitle: Text('0 MB / 2 GB')),
        const ListTile(leading: Icon(Icons.settings_outlined), title: Text('Cài đặt')),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: Theme.of(context).textTheme.titleLarge), Text(label),
  ]);
}
