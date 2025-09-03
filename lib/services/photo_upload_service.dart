import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:color_canvas/services/auth_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

class PhotoUploadService {
  PhotoUploadService._();
  static final PhotoUploadService instance = PhotoUploadService._();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<XFile>> pickPhotos({int max = 6}) async {
    final res = await _picker.pickMultiImage();
    if (res.isEmpty) return [];
    return res.take(max).toList();
  }

  Future<String> _ensureInterviewId() async {
    final journey = JourneyService.instance;
    String? id = journey.state.value?.artifacts['interviewId'] as String?;
    id ??= const Uuid().v4();
    await journey.setArtifact('interviewId', id);
    return id;
  }

  /// Uploads all files, calling onProgress with 0..1 overall progress
  Future<List<String>> uploadAll(
    List<XFile> files, {
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return const <String>[];
    final user = await AuthService.instance.ensureSignedIn();
    final interviewId = await _ensureInterviewId();

    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      double perFileProgress = 0;
      final url = await _uploadOne(
        uid: user.uid,
        interviewId: interviewId,
        file: files[i],
        onPerFileProgress: (p) {
          perFileProgress = p;
          final overall =
              ((i + perFileProgress) / files.length).clamp(0, 1).toDouble();
          onProgress?.call(overall);
        },
      );
      urls.add(url);
      onProgress?.call(((i + 1) / files.length).clamp(0, 1).toDouble());
    }
    return urls;
  }

  Future<String> _uploadOne({
    required String uid,
    required String interviewId,
    required XFile file,
    required void Function(double) onPerFileProgress,
  }) async {
    final bytes = await _compress(file);
    final id = const Uuid().v4();
    final path = 'users/$uid/intake/$interviewId/$id.jpg';
    final ref = _storage.ref(path);

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    uploadTask.snapshotEvents.listen((ev) {
      final p = ev.totalBytes == 0 ? 0.0 : ev.bytesTransferred / ev.totalBytes;
      onPerFileProgress(p);
    });

    await uploadTask.whenComplete(() {});
    final url = await ref.getDownloadURL();
    return url;
  }

  Future<Uint8List> _compress(XFile xf) async {
    final input = await xf.readAsBytes();
    final out = await FlutterImageCompress.compressWithList(
      input,
      quality: 85,
      minWidth: 2560,
      minHeight: 2560,
      keepExif: true,
      format: CompressFormat.jpeg,
    );
    return Uint8List.fromList(out);
  }
}
