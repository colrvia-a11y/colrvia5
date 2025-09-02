// lib/services/deliverable_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Placeholder for server-side PDF export integration.
/// Call `exportGuide(projectId)` to set `journey.artifacts.guideUrl` when server is ready.
class DeliverableService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> saveGuideUrl(String projectId, String url) async {
    await _db.collection('projects').doc(projectId).set({
      'journey': {
        'artifacts': {'guideUrl': url}
      }
    }, SetOptions(merge: true));
  }

  /// TODO: integrate with a callable function or HTTPS endpoint.
  static Future<String?> exportGuide(String projectId) async {
    debugPrint('DeliverableService.exportGuide: stub called for $projectId');
    // Return null to indicate not yet available
    return null;
  }
}