import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'roller_screen.dart';

/// Home scaffold with 4 bottom tabs: Create, Projects, Search, Account.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _initialProjectId;

  final _screens = <Widget>[
    const CreateScreen(),
    const ProjectsScreen(),
    const SearchScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _determineLanding();
  }

  Future<void> _determineLanding() async {
    final list = await ProjectService.myProjectsStream(limit: 1).first;
    if (list.isNotEmpty) {
      setState(() {
        _currentIndex = 1;
        _initialProjectId = list.first.id;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RollerScreen()),
          );
        },
        child: const Icon(Icons.color_lens),
      ),
    );
  }
}
