import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VisualizerService {
  static final _f = FirebaseFunctions.instanceFor(region: 'us-central1');
  static final _storage = FirebaseStorage.instance;

  /// Uploads a picked file to gs:// under the user path and returns gsPath
  static Future<String> uploadInputBytes(String uid, String filename, List<int> bytes) async {
    final ref = _storage.ref('visualizer/$uid/inputs/$filename');
    await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/png'));
    final bucket = _storage.bucket;
    return 'gs://$bucket/${ref.fullPath}';
  }

  static Future<List<Map<String, dynamic>>> generateFromPhoto({
    required String inputGsPath,
    required String roomType,
    required List<String> surfaces,
    required List<String> variants,
    String? storyId,
  }) async {
    final callable = _f.httpsCallable('visualizerGenerate');
    final res = await callable.call({
      'inputGsPath': inputGsPath,
      'roomType': roomType,
      'surfaces': surfaces,
      'variantHexes': variants,
      'storyId': storyId,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return List<Map<String, dynamic>>.from(data['results'] as List);
  }

  static Future<List<Map<String, dynamic>>> generateMockup({
    required String roomType,
    required String style,
    required List<String> variants,
  }) async {
    final callable = _f.httpsCallable('visualizerMockup');
    final res = await callable.call({ 'roomType': roomType, 'style': style, 'variants': variants });
    final data = Map<String, dynamic>.from(res.data as Map);
    return List<Map<String, dynamic>>.from(data['results'] as List);
  }
}