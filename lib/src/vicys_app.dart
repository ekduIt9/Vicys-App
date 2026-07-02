import 'package:flutter/material.dart';

import 'data/project_repository.dart';
import 'features/camera_screen.dart';
import 'features/media_library_screen.dart';
import 'features/studio_screen.dart';
import 'ui/vicys_design.dart';

class VicysApp extends StatelessWidget {
  const VicysApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vicys',
        theme: VicysTheme.dark(),
        home: const VicysShell(),
      );
}

class VicysShell extends StatefulWidget {
  const VicysShell({super.key});

  @override
  State<VicysShell> createState() => _VicysShellState();
}

class _VicysShellState extends State<VicysShell> {
  final ProjectRepository _repository = LocalProjectRepository();
  final GlobalKey<MediaLibraryScreenState> _libraryKey = GlobalKey();
  var _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CameraPage(
        repository: _repository,
        active: _selectedIndex == 0,
        onClose: () => setState(() => _selectedIndex = 1),
      ),
      MediaLibraryScreen(
        key: _libraryKey,
        repository: _repository,
      ),
      StudioScreen(
        repository: _repository,
        openLibrary: () => setState(() => _selectedIndex = 1),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: _selectedIndex == 0
          ? null
          : NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) _libraryKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_fix_high),
            label: 'Studio',
          ),
        ],
            ),
    );
  }
}
