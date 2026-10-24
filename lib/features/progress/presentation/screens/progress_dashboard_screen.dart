// lib/features/progress/presentation/screens/progress_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../learning/presentation/providers/progress_providers.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(myEnrolledCoursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('การเรียนของฉัน')),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดข้อมูลไม่สำเร็จ', onRetry: () => ref.invalidate(myEnrolledCoursesProvider)),
        data: (courses) {
          if (courses.isEmpty) {
            return AppEmptyState(
              message: 'ยังไม่มีคอร์สที่กำลังเรียน',
              ctaLabel: 'ไปเลือกคอร์สเรียน',
              onCta: () => context.go(RoutePaths.home),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: courses.length,
            itemBuilder: (c, i) {
              final item = courses[i];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  leading: Image.network(item.thumbnailUrl, width: 80, height: 60, fit: BoxFit.cover),
                  title: Text(item.title, style: AppTextStyles.bodyLarge),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: AppProgressBar(percent: item.percentComplete),
                  ),
                  onTap: () => context.push(RoutePaths.videoLearning.replaceFirst(':courseId', item.courseId).replaceFirst(':lectureId', 'l1')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}