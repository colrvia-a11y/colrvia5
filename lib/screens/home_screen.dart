import 'package:flutter/material.dart';
import '../firestore/firestore_data_schema.dart';
import '../services/user_prefs_service.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'roller_screen.dart';
import 'package:color_canvas/widgets/via_overlay.dart';

/// Home scaffold with 4 bottom tabs: Create, Projects, Search, Account.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  /// Called by SearchScreen to load a paint into the RollerScreen.
  /// This method navigates to RollerScreen with the selected paint ready to be added.
  void onPaintSelectedFromSearch(Paint paint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RollerScreen(
          initialPaintIds: [paint.id],
        ),
      ),
    );
  }

  int _currentIndex = 0;

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
    // REGION: CODEX-ADD adaptive-landing
    final prefs = await UserPrefsService.fetch();
    setState(() => _currentIndex = prefs.firstRunCompleted ? 1 : 0);
    // END REGION: CODEX-ADD adaptive-landing
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
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ViaOverlay(contextLabel: 'FAB');
            },
          );
        },
        child: const Icon(Icons.chat_bubble_outline), // Changed icon to reflect chat/AI
      ),
    );
  }
}
