// lib/features/quiz/data/quiz_repository.dart
import '../domain/quiz_model.dart';

abstract class QuizRepository {
  Future<QuizModel> getQuiz(String quizId);
  Future<QuizResult> submitQuiz(String quizId, Map<String, int> answers); // TODO: Production ต้องเรียก Cloud Function submitQuiz() เท่านั้น
}

class MockQuizRepository implements QuizRepository {
  @override
  Future<QuizModel> getQuiz(String quizId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return QuizModel(
      id: quizId,
      lectureId: 'l2',
      passThresholdPercent: 70,
      questions: const [
        QuizQuestion(id: 'q1', questionText: 'Flutter ใช้ภาษาอะไร?', options: ['Dart', 'Java', 'Swift', 'Kotlin'], correctIndex: 0),
        QuizQuestion(id: 'q2', questionText: 'Firebase คืออะไร?', options: ['Database อย่างเดียว', 'Backend-as-a-Service', 'Framework UI', 'ภาษาโปรแกรม'], correctIndex: 1),
      ],
    );
  }

  @override
  Future<QuizResult> submitQuiz(String quizId, Map<String, int> answers) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Mock: สุ่มว่าผ่านหรือไม่ เพื่อ demo UI ทั้ง 2 สถานะ
    const score = 85;
    return const QuizResult(scorePercent: score, passed: score >= 70);
  }
}