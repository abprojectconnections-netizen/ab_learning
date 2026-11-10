// lib/features/quiz/domain/quiz_model.dart
class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  const QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
  });
}

class QuizModel {
  final String id;
  final String courseId;
  final String lectureId;
  final String title;
  final int passThresholdPercent;
  final List<QuizQuestion> questions;
  const QuizModel({
    required this.id,
    required this.courseId,
    required this.lectureId,
    required this.title,
    required this.passThresholdPercent,
    required this.questions,
  });
}

class QuizResult {
  final int scorePercent;
  final bool passed;
  final bool certificateIssued;
  const QuizResult({
    required this.scorePercent,
    required this.passed,
    this.certificateIssued = false,
  });
}

/// Editable quiz (instructor only). The correct answer is only ever returned
/// to the course owner by the getQuizForEditing function.
class QuestionDraft {
  final String text;
  final List<String> options;
  final int correctIndex;
  const QuestionDraft({
    required this.text,
    required this.options,
    required this.correctIndex,
  });
}

class QuizDraft {
  final String? id;
  final String lectureId;
  final String title;
  final int passThresholdPercent;
  final List<QuestionDraft> questions;
  const QuizDraft({
    this.id,
    required this.lectureId,
    required this.title,
    required this.passThresholdPercent,
    required this.questions,
  });
}
