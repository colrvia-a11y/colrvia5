import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/models/color_plan.dart';
import 'package:color_canvas/services/painter_pack_service.dart';

void main() {
  group('PainterPackService', () {
    test('buildPdf generates non-empty PDF', () async {
      final service = PainterPackService();
      final now = DateTime.now();
      final plan = ColorPlan(
        id: 'test-plan',
        name: 'Test Plan',
        vibe: 'Modern and minimal',
        projectId: 'test-project',
        paletteColorIds: ['color1', 'color2'],
        placementMap: [
          PlanPlacement(
            colorId: 'color1',
            area: 'Living Room Walls',
            sheen: 'Matte',
          ),
          PlanPlacement(
            colorId: 'color2',
            area: 'Kitchen Cabinets',
            sheen: 'Semi-Gloss',
          ),
        ],
        doDont: [
          DoDontEntry(
            doText: 'Use even coats',
            dontText: 'Skip primer',
          ),
        ],
        cohesionTips: ['Use a consistent sheen pattern'],
        accentRules: [
          AccentRule(
            context: 'Accent walls',
            guidance: 'Use darker shades sparingly',
          ),
        ],
        sampleSequence: ['Prime', 'First coat', 'Second coat'],
        roomPlaybook: [
          RoomPlaybookItem(
            roomType: 'Living Room',
            placements: [],
            notes: 'Keep it bright and airy',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final pdf = await service.buildPdf(plan, {
        'color1': {'Matte': 'SW1234'},
        'color2': {'Semi-Gloss': 'SW5678'},
      });

      expect(pdf.length, greaterThan(0));
    });
  });
}
