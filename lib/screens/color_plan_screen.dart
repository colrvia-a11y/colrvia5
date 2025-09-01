import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../models/color_plan.dart';
import '../services/color_plan_service.dart';
import '../services/analytics_service.dart';
=======
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/models/color_story.dart' as model;
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/ai_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
// ...existing code...
import 'color_plan_detail_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/utils/color_utils.dart';
// REGION: CODEX-ADD color-plan-screen-imports
import 'package:color_canvas/models/color_plan.dart';
// END REGION: CODEX-ADD color-plan-screen-imports
>>>>>>> 23841be2546629ccb041fa44367169f7b1649397

class ColorPlanScreen extends StatefulWidget {
  final String projectId;
  final List<String>? paletteColorIds;

  const ColorPlanScreen({super.key, required this.projectId, this.paletteColorIds});

  @override
  State<ColorPlanScreen> createState() => _ColorPlanScreenState();
}

class _ColorPlanScreenState extends State<ColorPlanScreen> {
  final _svc = ColorPlanService();
  ColorPlan? _plan;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (widget.paletteColorIds == null || widget.paletteColorIds!.isEmpty) {
      setState(() => _error = 'No palette selected');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plan = await _svc.createPlan(
        projectId: widget.projectId,
        paletteColorIds: widget.paletteColorIds!,
        context: {'lightingProfile': 'auto'},
      );

      // Telemetry
      AnalyticsService.instance.logEvent('plan_generated', {
        'project_id': widget.projectId,
        'palette_color_count': plan.paletteColorIds.length,
        'has_placement_map': plan.placementMap.isNotEmpty,
        'has_playbook': plan.roomPlaybook.isNotEmpty,
      });

      setState(() => _plan = plan);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Color Plan')), body: Center(child: Text(_error!)));
  if (_plan == null) return Scaffold(appBar: AppBar(title: const Text('Color Plan')), body: const Center(child: Text('No plan generated')));

    final plan = _plan!;
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(plan.vibe, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _Section(
            title: 'Placement Map',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.placementMap.map((p) => Text('${p.area}: ${p.colorId}')).toList(),
            ),
          ),
          _Section(
            title: 'Cohesion Tips',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.cohesionTips.map((t) => Text('• $t')).toList(),
            ),
          ),
          _Section(
            title: 'Accent Rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.accentRules.map((a) => Text('• ${a.context}: ${a.guidance}')).toList(),
            ),
          ),
          _Section(
            title: 'Do / Don\'t',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.doDont.map((d) => Text('✓ ${d.doText}   ✗ ${d.dontText}')).toList(),
            ),
          ),
          _Section(
            title: 'Sample Sequence',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.sampleSequence.map((s) => Text('• $s')).toList(),
            ),
          ),
          _Section(
            title: 'Room-by-Room Playbook',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.roomPlaybook.map((r) => Text('${r.roomType}: ${r.notes}')).toList(),
            ),
          ),
        ],
      ),
    );
  }
<<<<<<< HEAD
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
=======

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
          const Spacer(),
          if (_currentStep < 3)
            FilledButton(
              onPressed: _canGenerate() ? _nextStep : null,
              child: const Text('Next'),
            )
          else
            FilledButton(
              onPressed: _canGenerate() ? _generateColorStory : null,
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate Story'),
            ),
>>>>>>> 23841be2546629ccb041fa44367169f7b1649397
        ],
      ),
    );
  }
<<<<<<< HEAD
=======

// REGION: CODEX-ADD color-plan-screen
  Widget _buildPlanPreview(ColorPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.placementMap.isNotEmpty)
          Text('Placements: ' +
              plan.placementMap
                  .map((p) => '${p.area}-${p.colorId}')
                  .join(', ')),
        if (plan.cohesionTips.isNotEmpty)
          Text('Cohesion: ' + plan.cohesionTips.join('; ')),
        if (plan.accentRules.isNotEmpty)
          Text('Accent: ' +
              plan.accentRules
                  .map((a) => '${a.context}: ${a.guidance}')
                  .join('; ')),
        if (plan.doDont.isNotEmpty)
          Text(
              'Do: ${plan.doDont.first.doText}\nDon\'t: ${plan.doDont.first.dontText}'),
        if (plan.sampleSequence.isNotEmpty)
          Text('Sequence: ' + plan.sampleSequence.join(' -> ')),
        if (plan.roomPlaybook.isNotEmpty)
          Text('Rooms: ' +
              plan.roomPlaybook.map((r) => r.roomType).join(', ')),
      ],
    );
  }
// END REGION: CODEX-ADD color-plan-screen

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
>>>>>>> 23841be2546629ccb041fa44367169f7b1649397
}
