import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/quiz_model.dart';
import '../providers/quiz_providers.dart';
import '../../../../core/state/app_store.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/quiz_question_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';


class QuizTakingScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String quizId;
  const QuizTakingScreen({super.key, required this.courseId, required this.quizId});

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    
    // ตรวจคำตอบแบบจำลอง (ถ้าตอบข้อแรกถูก ให้ได้คะแนน 100%)
    // สมมติข้อ 1 correctIndex = 0
    int correctCount = 0;
    const totalQ = 2; // อิงตาม Mock Quiz มี 2 ข้อ
    
    if (_answers['q1'] == 0) correctCount++;
    if (_answers['q2'] == 1) correctCount++;
    
    final scorePercent = ((correctCount / totalQ) * 100).round();

    // บันทึกผลสอบลง AppStore กลาง
    final passed = ref.read(appStoreProvider.notifier).submitQuizAndCheck(widget.courseId, scorePercent);

    ref.read(lastQuizResultProvider.notifier).state = QuizResult(scorePercent: scorePercent, passed: passed);

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      context.go(RoutePaths.quizResult.replaceFirst(':courseId', widget.courseId).replaceFirst(':quizId', widget.quizId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizByIdProvider(widget.quizId));
    return Scaffold(
      appBar: AppBar(title: const Text('แบบทดสอบท้ายบท')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดแบบทดสอบไม่สำเร็จ', onRetry: () => ref.invalidate(quizByIdProvider(widget.quizId))),
        data: (quiz) {
          final q = quiz.questions[_currentIndex];
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('คำถาม ${_currentIndex + 1}/${quiz.questions.length}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: QuizQuestionCard(
                    questionText: q.questionText,
                    options: q.options,
                    selectedIndex: _answers[q.id],
                    onSelect: (i) => setState(() => _answers[q.id] = i),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentIndex > 0)
                      AppButton(
                        label: 'ก่อนหน้า',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => setState(() => _currentIndex--),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_currentIndex < quiz.questions.length - 1)
                      AppButton(
                        label: 'ถัดไป',
                        onPressed: () => setState(() => _currentIndex++),
                      )
                    else
                      AppButton(
                        label: 'ส่งคำตอบ',
                        isLoading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}