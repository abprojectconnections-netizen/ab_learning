// lib/features/quiz/data/quiz_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/quiz_model.dart';

abstract class QuizRepository {
  Future<QuizModel> getQuiz(String quizId);

  /// First quiz of a course, or null when the instructor has not added one.
  Future<QuizModel?> getQuizForCourse(String courseId);

  /// Grading happens server-side (submitQuiz callable); answer keys are never
  /// readable by the client.
  Future<QuizResult> submitQuiz(String quizId, Map<String, int> answers);

  /// Instructor: the course's quiz including answers, or null if none exists.
  Future<QuizDraft?> loadForEditing(String courseId);

  /// Instructor: validates and stores the quiz and its answer key server-side.
  Future<String> saveQuiz(String courseId, QuizDraft draft);
}

class FirebaseQuizRepository implements QuizRepository {
  FirebaseQuizRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  QuizModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final questions = (data['questions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((q) => QuizQuestion(
              id: q['id'] as String,
              questionText: q['text'] as String? ?? '',
              options: (q['options'] as List<dynamic>? ?? const [])
                  .map((o) => o.toString())
                  .toList(),
            ))
        .toList();
    return QuizModel(
      id: doc.id,
      courseId: data['courseId'] as String? ?? '',
      lectureId: data['lectureId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      passThresholdPercent:
          (data['passThresholdPercent'] as num?)?.toInt() ?? 70,
      questions: questions,
    );
  }

  @override
  Future<QuizModel> getQuiz(String quizId) async {
    final doc = await _firestore.collection('quizzes').doc(quizId).get();
    if (!doc.exists) throw StateError('Quiz was not found.');
    return _fromDoc(doc);
  }

  @override
  Future<QuizModel?> getQuizForCourse(String courseId) async {
    final result = await _firestore
        .collection('quizzes')
        .where('courseId', isEqualTo: courseId)
        .orderBy('createdAt')
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    return _fromDoc(result.docs.first);
  }

  @override
  Future<QuizDraft?> loadForEditing(String courseId) async {
    final response = await _functions
        .httpsCallable('getQuizForEditing')
        .call<Map<Object?, Object?>>({'courseId': courseId});
    final quiz = response.data['quiz'] as Map<Object?, Object?>?;
    if (quiz == null) return null;
    return QuizDraft(
      id: quiz['id'] as String?,
      lectureId: quiz['lectureId'] as String? ?? '',
      title: quiz['title'] as String? ?? '',
      passThresholdPercent: (quiz['passThresholdPercent'] as num?)?.toInt() ?? 70,
      questions: (quiz['questions'] as List<Object?>? ?? const [])
          .cast<Map<Object?, Object?>>()
          .map((q) => QuestionDraft(
                text: q['text'] as String? ?? '',
                options: (q['options'] as List<Object?>? ?? const [])
                    .map((o) => o.toString())
                    .toList(),
                correctIndex: (q['correctIndex'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
    );
  }

  @override
  Future<String> saveQuiz(String courseId, QuizDraft draft) async {
    final response = await _functions
        .httpsCallable('saveQuiz')
        .call<Map<Object?, Object?>>({
      'courseId': courseId,
      if (draft.id != null) 'quizId': draft.id,
      'lectureId': draft.lectureId,
      'title': draft.title,
      'passThresholdPercent': draft.passThresholdPercent,
      'questions': [
        for (final q in draft.questions)
          {'text': q.text, 'options': q.options, 'correctIndex': q.correctIndex},
      ],
    });
    return response.data['quizId'] as String;
  }

  @override
  Future<QuizResult> submitQuiz(String quizId, Map<String, int> answers) async {
    final response = await _functions
        .httpsCallable('submitQuiz')
        .call<Map<Object?, Object?>>({'quizId': quizId, 'answers': answers});
    final data = response.data;
    return QuizResult(
      scorePercent: (data['scorePercent'] as num).toInt(),
      passed: data['passed'] == true,
      certificateIssued: data['certificateIssued'] == true,
    );
  }
}
