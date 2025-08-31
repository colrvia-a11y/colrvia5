import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/models/color_plan.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;
  final users = await db.collection('users').get();
  for (final u in users.docs) {
    final projects = await u.reference.collection('projects').get();
    for (final p in projects.docs) {
      final stories = await p.reference.collection('colorStories').get();
      for (final s in stories.docs) {
        final data = s.data();
        final planRef = p.reference.collection('colorPlans').doc();
        final plan = ColorPlan.fromJson(planRef.id, {
          'projectId': p.id,
          'name': data['name'] ?? 'Plan',
          'vibe': data['vibe'] ?? '',
          'paletteColorIds': (data['palette'] ?? []).cast<String>(),
          'placementMap': (data['placements'] ?? []),
          'cohesionTips': (data['tips'] ?? []),
          'accentRules': (data['accents'] ?? []),
          'doDont': (data['doDont'] ?? []),
          'sampleSequence': (data['sequence'] ?? []),
          'roomPlaybook': (data['rooms'] ?? []),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
        await planRef.set(plan.toJson());
        print('Migrated story ${s.id} -> plan ${planRef.id}');
      }
    }
  }
}
