// lib/features/video_upload/data/video_upload_repository.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

const kMaxVideoBytes = 500 * 1024 * 1024; // mirrors storage.rules

class VideoUploadProgress {
  final int transferred;
  final int total;
  const VideoUploadProgress(this.transferred, this.total);
  double get fraction => total == 0 ? 0 : transferred / total;
}

abstract class VideoUploadRepository {
  /// Uploads to lesson_videos/{courseId}/{lessonId} and records the path in
  /// the lesson document (`videoRef`). Emits progress; completes when stored.
  Stream<VideoUploadProgress> uploadLessonVideo({
    required String courseId,
    required String lessonId,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> setPreview(String courseId, String lessonId, bool isPreview);

  /// Short-lived signed URL, issued only after the server checks access.
  Future<String> getVideoAccessUrl(String courseId, String lessonId);
}

class FirebaseVideoUploadRepository implements VideoUploadRepository {
  FirebaseVideoUploadRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _storage = storage,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _lesson(String courseId, String lessonId) =>
      _firestore.collection('courses').doc(courseId).collection('lessons').doc(lessonId);

  @override
  Stream<VideoUploadProgress> uploadLessonVideo({
    required String courseId,
    required String lessonId,
    required Uint8List bytes,
    required String contentType,
  }) async* {
    if (bytes.length >= kMaxVideoBytes) {
      throw ArgumentError('Video must be smaller than 500 MB.');
    }
    final path = 'lesson_videos/$courseId/$lessonId';
    final task = _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    await for (final snapshot in task.snapshotEvents) {
      yield VideoUploadProgress(snapshot.bytesTransferred, snapshot.totalBytes);
    }
    await task; // surfaces upload errors
    await _lesson(courseId, lessonId).update({
      'videoRef': path,
      'videoProvider': 'firebase_storage',
    });
  }

  @override
  Future<void> setPreview(String courseId, String lessonId, bool isPreview) {
    return _lesson(courseId, lessonId).update({'isPreview': isPreview});
  }

  @override
  Future<String> getVideoAccessUrl(String courseId, String lessonId) async {
    final response = await _functions
        .httpsCallable('getVideoAccessUrl')
        .call<Map<Object?, Object?>>({'courseId': courseId, 'lessonId': lessonId});
    return response.data['url'] as String;
  }
}
