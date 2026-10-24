// lib/features/quiz/domain/quiz_model.dart
class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex; // ฝั่ง client ไม่ควรรู้ค่านี้จริงใน Production — Mock ใช้เพื่อ demo เท่านั้น
  const QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });
}

class QuizModel {
  final String id;
  final String lectureId;
  final int passThresholdPercent;
  final List<QuizQuestion> questions;
  const QuizModel({
    required this.id,
    required this.lectureId,
    required this.passThresholdPercent,
    required this.questions,
  });
}

class QuizResult {
  final int scorePercent;
  final bool passed;
  const QuizResult({required this.scorePercent, required this.passed});
}