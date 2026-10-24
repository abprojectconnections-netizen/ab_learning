// lib/features/quiz/presentation/providers/quiz_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quiz_repository.dart';
import '../../domain/quiz_model.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) => MockQuizRepository());

final quizByIdProvider = FutureProvider.autoDispose.family<QuizModel, String>((ref, quizId) {
  return ref.watch(quizRepositoryProvider).getQuiz(quizId);
});

final lastQuizResultProvider = StateProvider<QuizResult?>((ref) => null);