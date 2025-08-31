// lib/services/visualizer_service.dart
import 'dart:async';
import 'package:firebase_functions/firebase_functions.dart';

class VisualizerJob {
  final String jobId;
  final String status;
  final String? previewUrl;
  final String? resultUrl;
  VisualizerJob({required this.jobId, required this.status, this.previewUrl, this.resultUrl});
  factory VisualizerJob.fromMap(Map<String, dynamic> m) => VisualizerJob(
        jobId: m['jobId'],
        status: m['status'],
        previewUrl: m['previewUrl'],
        resultUrl: m['resultUrl'],
      );
}

class VisualizerService {
  final _functions = FirebaseFunctions.instance;

  Future<VisualizerJob> renderFast(String imageUrl, List<String> paletteColorIds) async {
    final callable = _functions.httpsCallable('renderFast');
    final resp = await callable.call({'imageUrl': imageUrl, 'palette': paletteColorIds});
    return VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<VisualizerJob> renderHq(String imageUrl, List<String> paletteColorIds) async {
    final callable = _functions.httpsCallable('renderHq');
    final resp = await callable.call({'imageUrl': imageUrl, 'palette': paletteColorIds});
    return VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
  }

  Stream<VisualizerJob> watchJob(String jobId) async* {
    final callable = _functions.httpsCallable('getJob');
    while (true) {
      final resp = await callable.call({'jobId': jobId});
      yield VisualizerJob.fromMap(Map<String, dynamic>.from(resp.data as Map));
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}

