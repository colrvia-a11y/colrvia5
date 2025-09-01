import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/color_plan.dart';
import 'analytics_service.dart';

/// Service for managing color plans in Firestore and generating new ones via Cloud Functions.
class ColorPlanService {
  static final _instance = ColorPlanService._();
  factory ColorPlanService() => _instance;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  ColorPlanService._();

  CollectionReference<Map<String, dynamic>> _plansCol(String uid, String projectId) =>
      _db.collection('users').doc(uid).collection('projects').doc(projectId).collection('colorPlans');

  // REGION: CODEX-ADD color-plan-service
  /// Creates a new color plan by invoking the generateColorPlanV2 cloud function
  /// and storing the result in Firestore.
  Future<ColorPlan> createPlan({
    required String projectId,
    required List<String> paletteColorIds,
    String? vibe,
    Map<String, dynamic>? context,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to create a color plan');
    }

    final callable = _functions.httpsCallable('generateColorPlanV2');
    final resp = await callable.call({
      'projectId': projectId,
      'paletteColorIds': paletteColorIds,
      'vibe': vibe,
      'context': context ?? {},
    });

    final data = Map<String, dynamic>.from(resp.data as Map);
    final doc = _plansCol(uid, projectId).doc();
    final now = DateTime.now();
    final plan = ColorPlan.fromJson(doc.id, {
      ...data,
      'projectId': projectId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    await doc.set(plan.toJson());
    await AnalyticsService().planGenerated(projectId, doc.id);
    return plan;
  }

  /// Lists all color plans for a project, ordered by creation date descending.
  Future<List<ColorPlan>> listPlans(String projectId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to list color plans');
    }

    final snap = await _plansCol(uid, projectId).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => ColorPlan.fromJson(d.id, d.data())).toList();
  }

  /// Gets a specific color plan by ID.
  Future<ColorPlan?> getPlan(String projectId, String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to get a color plan');
    }

    final doc = await _plansCol(uid, projectId).doc(planId).get();
    if (!doc.exists) return null;
    return ColorPlan.fromJson(doc.id, doc.data()!);
  }

  /// Updates specific fields of a color plan.
  Future<void> updatePlan(String projectId, String planId, Map<String, dynamic> patch) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to update a color plan');
    }

    patch['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _plansCol(uid, projectId).doc(planId).update(patch);
  }

  /// Deletes a color plan.
  Future<void> deletePlan(String projectId, String planId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Must be logged in to delete a color plan');
    }

    await _plansCol(uid, projectId).doc(planId).delete();
  }
  // END REGION: CODEX-ADD color-plan-service
}

extension _ColorPlanAnalytics on AnalyticsService {
  Future<void> planGenerated(String projectId, String planId) async {
    await logEvent('plan_generated', {
      'project_id': projectId,
      'plan_id': planId,
    });
  }
}
