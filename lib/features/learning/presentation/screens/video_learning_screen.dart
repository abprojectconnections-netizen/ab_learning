import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/state/app_store.dart';
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
    final appState = ref.watch(appStoreProvider);
    
    // ตรวจสอบสิทธิ์การเข้าเรียน (ถ้ายังไม่ซื้อ และไม่ใช่คอร์สฟรี/preview ให้บล็อก)
    final isEnrolled = appState.enrolledCourseIds.contains(courseId);

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
          final currentProgress = appState.courseProgress[courseId] ?? 0.0;

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VideoPlayerWidget(
                        videoUrl: canWatch
                            ? 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'
                            : null,
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
                              onPressed: () {
                                // จำลองกดเรียนจบ 1 บท เพิ่ม progress ทีละ 50% (2 บทจบ)
                                final nextProgress = (currentProgress + 50.0) > 100.0 ? 100.0 : (currentProgress + 50.0);
                                ref.read(appStoreProvider.notifier).updateProgress(courseId, nextProgress);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('อัปเดตความคืบหน้าเป็น ${nextProgress.toStringAsFixed(0)}%')),
                                );
                              },
                            ),
                            const SizedBox(width: AppSpacing.md),
                            AppButton(
                              label: 'ทำ Quiz ท้ายบท',
                              icon: Icons.quiz,
                              onPressed: () => context.push(RoutePaths.quizTaking.replaceFirst(':courseId', courseId).replaceFirst(':quizId', 'quiz-1')),
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