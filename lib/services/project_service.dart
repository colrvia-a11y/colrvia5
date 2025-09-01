// lib/services/project_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/analytics_service.dart';
import 'sync_queue_service.dart';

class ProjectService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String? get _uid => _auth.currentUser?.uid;
  static CollectionReference get _col => _db.collection('projects');
  static final SyncQueueService _queue = SyncQueueService.instance
    ..registerHandler('createProject', (p) async {
      await create(
        title: p['title'] as String,
        paletteId: p['paletteId'] as String?,
        roomType: p['roomType'] as String?,
        styleTag: p['styleTag'] as String?,
        vibeWords: List<String>.from(p['vibeWords'] as List? ?? []),
      );
    });

  static Stream<List<ProjectDoc>> myProjectsStream({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _col
        .where('ownerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
      // Log error but return empty stream to prevent crashes
      debugPrint('ProjectService: Error fetching projects: $error');
      return <QuerySnapshot>[];
    }).map((s) => s.docs.map((d) => ProjectDoc.fromSnap(d)).toList());
  }

  static Future<ProjectDoc> create({
    required String title,
    String? paletteId,
    String? roomType,
    String? styleTag,
    List<String> vibeWords = const [],
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in required to create projects');
    }

    try {
      final now = DateTime.now();
      final ref = await _col.add({
        'ownerId': uid,
        'title': title,
        'paletteIds': paletteId != null ? [paletteId] : [],
        'activePaletteId': paletteId,
        'colorStoryId': null,
        'roomType': roomType,
        'styleTag': styleTag,
        'vibeWords': vibeWords,
        'funnelStage': 'build',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      final snap = await ref.get();
      return ProjectDoc.fromSnap(snap);
    } catch (e) {
      await _queue.enqueue('createProject', {
        'title': title,
        'paletteId': paletteId,
        'roomType': roomType,
        'styleTag': styleTag,
        'vibeWords': vibeWords,
      });
      throw Exception('Failed to create project: $e');
    }
  }

  static Future<void> attachPalette(String projectId, String paletteId,
      {bool setActive = true}) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in required to update projects');
    }

    try {
      await _col.doc(projectId).update({
        'paletteIds': FieldValue.arrayUnion([paletteId]),
        if (setActive) 'activePaletteId': paletteId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to attach palette: $e');
    }
  }

  static Future<void> setStory(String projectId, String colorStoryId) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in required to update projects');
    }

    try {
      await _col.doc(projectId).update({
        'colorStoryId': colorStoryId,
        'funnelStage': 'story',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set story: $e');
    }
  }

  static Future<void> setFunnelStage(
      String projectId, FunnelStage stage) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in required to update projects');
    }

    try {
      await _col.doc(projectId).update({
        'funnelStage': funnelStageToString(stage),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Track stage change
      AnalyticsService.instance.logProjectStageChanged(projectId, stage);
    } catch (e) {
      throw Exception('Failed to update stage: $e');
    }
  }

  static Future<ProjectDoc?> fetch(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProjectDoc.fromSnap(snap);
  }

  static Future<void> addPaletteHistory(
      String projectId, String kind, List<String> palette) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in required to update projects');
    }

    try {
      await _col.doc(projectId).collection('paletteHistory').add({
        'kind': kind,
        'palette': palette,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ProjectService: Failed to append palette history: $e');
    }
  }
}
