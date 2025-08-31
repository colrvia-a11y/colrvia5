import 'package:flutter/material.dart';
import '../models/project.dart';
import 'roller_screen.dart';
import 'color_plan_screen.dart';
import 'visualizer_screen.dart';

/// Basic overview of a project with quick links to core tools.
class ProjectOverviewScreen extends StatelessWidget {
  final ProjectDoc project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(project.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Palette'),
            subtitle: const Text('Edit in Roller'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RollerScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Color Plan'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ColorPlanScreen(projectId: project.id)),
              );
            },
          ),
          ListTile(
            title: const Text('Visualizer'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VisualizerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
