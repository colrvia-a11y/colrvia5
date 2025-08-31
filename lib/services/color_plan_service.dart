import 'package:color_canvas/services/story_engine.dart';
import 'package:color_canvas/services/immersive_narrative_engine.dart';

/// Facade for color plan generation and helpers.
class ColorPlanService {
  ColorPlanService._();
  static final StoryEngine _storyEngine = StoryEngine();
  static final ImmersiveNarrativeEngine _narrative = ImmersiveNarrativeEngine();

  /// Generate a color plan. This is a thin wrapper around the existing
  /// story engine while the backend is migrated from "Story" to "Color Plan".
  static Future<Map<String, dynamic>> generate({
    required Map<String, dynamic> palette,
    String room = '',
    Map<String, dynamic>? constraints,
  }) async {
    // TODO: replace with real implementation once backend is updated.
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'id': 'temp',
      'name': 'Draft Plan',
      'palette': palette,
      'room': room,
      'constraints': constraints ?? {},
    };
  }
}
