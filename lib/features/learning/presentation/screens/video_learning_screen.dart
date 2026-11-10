import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../certificate/presentation/providers/certificate_providers.dart';
import '../../../quiz/presentation/providers/quiz_providers.dart';
import '../../../video_upload/presentation/providers/video_upload_providers.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../providers/progress_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/video_player_widget.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';

class VideoLearningScreen extends ConsumerWidget {
  final String courseId;
  final String lectureId;
  const VideoLearningScreen({super.key, required this.courseId, required this.lectureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseByIdProvider(courseId));

    // ตรวจสอบสิทธิ์การเข้าเรียนจาก enrollments ใน Firestore
    final isEnrolled = ref.watch(isEnrolledProvider(courseId));

    return Scaffold(
      appBar: AppBar(title: const Text('ห้องเรียนออนไลน์')),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดคอร์สไม่สำเร็จ', onRetry: () => ref.invalidate(courseByIdProvider(courseId))),
        data: (course) {
          if (course == null) return const AppErrorState(message: 'ไม่พบคอร์สนี้');

          final lecture = course.sections
              .expand((s) => s.lectures)
              .firstWhere((l) => l.id == lectureId, orElse: () => course.sections.first.lectures.first);

          // ถ้ายังไม่ได้ซื้อ และบทเรียนนี้ไม่ใช่ preview -> แสดงสถานะล็อก
          final canWatch = isEnrolled || lecture.isPreview;
          final currentProgress = ref.watch(courseCompletionPercentProvider(courseId)).valueOrNull ?? 0.0;

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LessonPlayer(
                        courseId: courseId,
                        lessonId: lecture.id,
                        canWatch: canWatch,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppProgressBar(percent: currentProgress),
                      const SizedBox(height: AppSpacing.md),
                      if (canWatch) ...[
                        Row(
                          children: [
                            AppButton(
                              label: '✓ บันทึกบทเรียนนี้ว่าเรียนจบแล้ว',
                              variant: AppButtonVariant.secondary,
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(progressRepositoryProvider)
                                      .updateLastWatched(courseId, lecture.id, 100);
                                  ref.invalidate(courseProgressProvider(courseId));
                                  final percent = await ref.read(
                                      courseCompletionPercentProvider(courseId).future);
                                  // Server decides eligibility (all lessons + quizzes).
                                  final issued = percent >= 100 &&
                                      await ref
                                          .read(certificateRepositoryProvider)
                                          .claimCertificate(courseId);
                                  if (issued) ref.invalidate(myCertificatesProvider);
                                  messenger.showSnackBar(SnackBar(
                                      content: Text('อัปเดตความคืบหน้าเป็น ${percent.toStringAsFixed(0)}%')));
                                } catch (_) {
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('บันทึกความคืบหน้าไม่สำเร็จ')));
                                }
                              },
                            ),
                            const SizedBox(width: AppSpacing.md),
                            if (ref.watch(courseQuizProvider(courseId)).valueOrNull
                                case final quiz?)
                              AppButton(
                                label: 'ทำ Quiz ท้ายบท',
                                icon: Icons.quiz,
                                onPressed: () => context.push(RoutePaths.quizTaking
                                    .replaceFirst(':courseId', courseId)
                                    .replaceFirst(':quizId', quiz.id)),
                              ),
                          ],
                        ),
                      ] else ...[
                        const Text('คุณยังไม่ได้ซื้อคอร์สนี้ กรุณาชำระเงินก่อนเพื่อปลดล็อกบทเรียนทั้งหมด', style: TextStyle(color: Colors.red)),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'ไปหน้าชำระเงิน',
                          onPressed: () => context.push(RoutePaths.checkout.replaceFirst(':courseId', courseId)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: ListView(
                  children: course.sections.expand((s) => s.lectures).map((l) {
                    final unlocked = isEnrolled || l.isPreview;
                    return ListTile(
                      leading: Icon(l.id == lectureId ? Icons.play_arrow : (unlocked ? Icons.lock_open : Icons.lock)),
                      title: Text(l.title),
                      selected: l.id == lectureId,
                      onTap: unlocked
                          ? () => context.go(RoutePaths.videoLearning.replaceFirst(':courseId', courseId).replaceFirst(':lectureId', l.id))
                          : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาซื้อคอร์สเพื่อปลดล็อกบทเรียนนี้'))),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Resolves a short-lived signed URL (server-checked) for the lesson video.
class _LessonPlayer extends ConsumerWidget {
  const _LessonPlayer({
    required this.courseId,
    required this.lessonId,
    required this.canWatch,
  });
  final String courseId;
  final String lessonId;
  final bool canWatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canWatch) return const VideoPlayerWidget(videoUrl: null);
    final urlAsync = ref.watch(videoAccessUrlProvider((courseId: courseId, lessonId: lessonId)));
    return urlAsync.when(
      loading: () => const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: Text('โหลดวิดีโอไม่สำเร็จ')),
      ),
      data: (url) => url == null
          ? const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: Text('บทเรียนนี้ยังไม่มีวิดีโอ')),
            )
          : VideoPlayerWidget(key: ValueKey(url), videoUrl: url),
    );
  }
}
