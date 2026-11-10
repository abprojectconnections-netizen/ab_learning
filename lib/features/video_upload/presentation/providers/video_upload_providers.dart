import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/video_upload_repository.dart';

final videoUploadRepositoryProvider = Provider<VideoUploadRepository>((ref) {
  return FirebaseVideoUploadRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
    functions: FirebaseFunctions.instance,
  );
});

typedef LessonKey = ({String courseId, String lessonId});

/// Signed playback URL for a lesson; null when the lesson has no video yet.
final videoAccessUrlProvider =
    FutureProvider.autoDispose.family<String?, LessonKey>((ref, key) async {
  try {
    return await ref
        .watch(videoUploadRepositoryProvider)
        .getVideoAccessUrl(key.courseId, key.lessonId);
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'failed-precondition') return null;
    rethrow;
  }
});
