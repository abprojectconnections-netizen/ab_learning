// lib/features/quiz/presentation/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/quiz_providers.dart';
import '../../../../core/router/route_paths.dart';

class QuizResultScreen extends ConsumerWidget {
  final String courseId;
  final String quizId;
  const QuizResultScreen({super.key, required this.courseId, required this.quizId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(lastQuizResultProvider);
    if (result == null) {
      return const Scaffold(body: Center(child: Text('ไม่พบผลคะแนน กรุณาทำแบบทดสอบใหม่')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ผลคะแนน')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(result.passed ? Icons.check_circle : Icons.cancel, size: 64, color: result.passed ? Colors.green : Colors.red),
            const SizedBox(height: 12),
            Text('${result.scorePercent}%', style: Theme.of(context).textTheme.headlineMedium),
            Text(result.passed ? 'ผ่านเกณฑ์' : 'ไม่ผ่านเกณฑ์ ลองใหม่อีกครั้ง'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.videoLearning.replaceFirst(':courseId', courseId).replaceFirst(':lectureId', 'l2')),
              child: const Text('กลับไปเรียนต่อ'),
            ),
          ],
        ),
      ),
    );
  }
}