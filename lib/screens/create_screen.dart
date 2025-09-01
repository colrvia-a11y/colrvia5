import 'package:flutter/material.dart';
import 'color_plan_screen.dart';
import 'roller_screen.dart';
import 'visualizer_screen.dart';
// REGION: CODEX-ADD onboarding-imports
import '../services/user_prefs_service.dart';
import 'onboarding_screen.dart';
// END REGION: CODEX-ADD onboarding-imports

/// Entry hub for starting new workflows.
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    // REGION: CODEX-ADD onboarding-gate
    final prefs = await UserPrefsService.fetch();
    if (!prefs.firstRunCompleted && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ),
      );
    }
    // END REGION: CODEX-ADD onboarding-gate
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroGrid(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: const [
              SuggestionChip(label: 'Suggest calmer accent'),
              SuggestionChip(label: 'Warm it slightly'),
              SuggestionChip(label: 'Explain sheen'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      children: [
        _CtaTile(
          label: 'Guided Interview',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ColorPlanScreen(projectId: 'temp')),
            );
          },
        ),
        _CtaTile(
          label: 'Design with Roller',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RollerScreen()),
            );
          },
        ),
        _CtaTile(
          label: 'Visualize My Room',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VisualizerScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _CtaTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtaTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Center(child: Text(label)),
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  final String label;
  const SuggestionChip({super.key, required this.label});
  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: () {});
  }
}
