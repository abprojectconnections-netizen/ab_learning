// lib/features/instructor_dashboard/presentation/screens/instructor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class InstructorDashboardScreen extends ConsumerWidget {
  const InstructorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const instructorId = 'instructor-1';
    final coursesAsync = ref.watch(instructorCoursesProvider(instructorId));
    return Scaffold(
      appBar: AppBar(title: const Text('แดชบอร์ดผู้สอน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.courseCreate),
        icon: const Icon(Icons.add),
        label: const Text('สร้างคอร์สใหม่'),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(
            message: 'โหลดข้อมูลไม่สำเร็จ',
            onRetry: () =>
                ref.invalidate(instructorCoursesProvider(instructorId))),
        data: (courses) {
          final totalStudents =
              courses.fold<int>(0, (sum, c) => sum + c.totalStudents);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  _StatCard(label: 'คอร์สทั้งหมด', value: '${courses.length}'),
                  const SizedBox(width: AppSpacing.sm),
                  _StatCard(label: 'นักเรียนรวม', value: '$totalStudents'),
                  const SizedBox(width: AppSpacing.sm),
                  const _StatCard(label: 'ยอดขายเดือนนี้', value: '฿0'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('คอร์สของฉัน', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              ...courses.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Image.network(
                        c.thumbnailUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.black12,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                      title: Text(c.title, style: AppTextStyles.bodyLarge),
                      subtitle: Text(
                          '${c.totalStudents} นักเรียน • ⭐ ${c.avgRating.toStringAsFixed(1)}',
                          style: AppTextStyles.caption),
                      trailing: AppButton(
                        label: 'จัดการ',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => context.push(RoutePaths
                            .curriculumBuilder
                            .replaceFirst(':courseId', c.id)),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Text(value, style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
