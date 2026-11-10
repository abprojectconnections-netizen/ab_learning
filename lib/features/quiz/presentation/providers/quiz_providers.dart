// lib/features/quiz/presentation/providers/quiz_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quiz_repository.dart';
import '../../domain/quiz_model.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return FirebaseQuizRepository(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instance,
  );
});

final quizByIdProvider = FutureProvider.autoDispose.family<QuizModel, String>((ref, quizId) {
  return ref.watch(quizRepositoryProvider).getQuiz(quizId);
});

final courseQuizProvider = FutureProvider.autoDispose.family<QuizModel?, String>((ref, courseId) {
  return ref.watch(quizRepositoryProvider).getQuizForCourse(courseId);
});

final lastQuizResultProvider = StateProvider<QuizResult?>((ref) => null);
