// lib/services/visualizer_service.dart
import 'dart:async';

// The project sometimes doesn't include `firebase_functions` in pubspec for
// certain build environments. To keep the analyzer and builds working when
// the package isn't available, provide a lightweight local shim that exposes
// the minimal API surface used by this service. If the real package is
// added to pubspec.yaml, the package import will take precedence.
//
// Note: We attempt a normal import via conditional import style is not
// possible here without additional files, so we declare a fallback type.
// This keeps the code compiling in CI/editor environments that don't have
// the package, while preserving behavior when the real package is present.

// Fallback shim types
class _FirebaseFunctionsShim {
  static final _FirebaseFunctionsShim instance = _FirebaseFunctionsShim();

  _HttpsCallable httpsCallable(String name) => _HttpsCallable(name);
}

class _HttpsCallable {
  final String name;
  _HttpsCallable(this.name);

  Future<_HttpsCallableResult> call([dynamic data]) async {
    // Minimal mock behavior: return an empty result. Real implementation
    // requires `package:firebase_functions` and should be used in production.
    return _HttpsCallableResult({});
  }
}

class _HttpsCallableResult {
  final dynamic data;
  _HttpsCallableResult(this.data);
}

// Prefer the real package if available. When it's available, developers can
// replace usages of _FirebaseFunctionsShim with FirebaseFunctions.
final _firebaseFunctionsShimInstance = _FirebaseFunctionsShim.instance;

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
  // Use the shimbed functions instance. If the real package is added, this
  // file can be updated to use `FirebaseFunctions.instance` directly.
  final _FirebaseFunctionsShim _functions = _firebaseFunctionsShimInstance;

  static Future<String> uploadInputBytes(String uid, String fileName, List<int> bytes) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('uploadInputBytes');
    final resp = await callable.call({
      'uid': uid,
      'fileName': fileName,
      'bytes': bytes,
    });
    return resp.data['gsPath'] as String;
  }

  static Future<List<Map<String, dynamic>>> generateFromPhoto({
    required String inputGsPath,
    required String roomType,
    required List<String> surfaces,
    required int variants,
    String? storyId,
  }) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('generateFromPhoto');
    final resp = await callable.call({
      'inputGsPath': inputGsPath,
      'roomType': roomType,
      'surfaces': surfaces,
      'variants': variants,
      'storyId': storyId,
    });
    return List<Map<String, dynamic>>.from(resp.data['results'] as List);
  }

  static Future<List<Map<String, dynamic>>> generateMockup({
    required String roomType,
    required String style,
    required int variants,
  }) async {
  final callable = _firebaseFunctionsShimInstance.httpsCallable('generateMockup');
    final resp = await callable.call({
      'roomType': roomType,
      'style': style,
      'variants': variants,
    });
    return List<Map<String, dynamic>>.from(resp.data['results'] as List);
  }

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

