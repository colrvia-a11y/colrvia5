import 'package:flutter/material.dart';
import '../models/project.dart';
import 'roller_screen.dart';
import 'color_plan_screen.dart';
import 'visualizer_screen.dart';
import '../services/analytics_service.dart';

/// Basic overview of a project with quick links to core tools.
class ProjectOverviewScreen extends StatelessWidget {
  final ProjectDoc project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Get palette IDs from project
  // Use the project's stored palette ids. If a ColorStory object is needed
  // later, it should be fetched separately; ProjectDoc only stores a colorStoryId.
  final List<String> paletteIds = project.paletteIds;
  final bool hasPalette = paletteIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: hasPalette
                    ? () {
                        Navigator.pushNamed(context, '/colorPlan', arguments: {
                          'projectId': project.id,
                          'paletteColorIds': paletteIds
                        });
                        AnalyticsService.instance.logEvent(
                          'cta_plan_clicked',
                          {'source': 'project_overview', 'project_id': project.id},
                        );
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Make a Color Plan'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/visualizer', arguments: {
                    'projectId': project.id, 
                    'paletteColorIds': paletteIds
                  });
                  AnalyticsService.instance.logEvent(
                    'cta_visualize_clicked',
                    {'source': 'project_overview', 'project_id': project.id},
                  );
                },
                icon: const Icon(Icons.image), 
                label: const Text('Visualize'),
              )),
              const SizedBox(width: 8),
              IconButton(
                onPressed: hasPalette
                    ? () {
                        Navigator.pushNamed(context, '/compareColors', arguments: {
                          'projectId': project.id,
                          'paletteColorIds': paletteIds
                        });
                        AnalyticsService.instance.logEvent(
                          'cta_compare_clicked',
                          {'source': 'project_overview', 'project_id': project.id},
                        );
                      }
                    : null,
                icon: const Icon(Icons.compare)
              ),
            ]),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Palette'),
            subtitle: const Text('Edit in Roller'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RollerScreen(projectId: project.id)),
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
