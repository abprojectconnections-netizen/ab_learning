// lib/features/course_builder/presentation/screens/curriculum_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';

class CurriculumBuilderScreen extends ConsumerWidget {
  final String courseId;
  const CurriculumBuilderScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseByIdProvider(courseId));
    return Scaffold(
      appBar: AppBar(title: const Text('จัดหลักสูตร')),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const AppErrorState(message: 'โหลดข้อมูลไม่สำเร็จ'),
        data: (course) {
          final sections = course?.sections ?? [];
          final canPublish = sections.isNotEmpty && sections.any((s) => s.lectures.isNotEmpty);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    AppButton(
                      label: 'เพิ่ม Section',
                      icon: Icons.add,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => ref.read(courseRepositoryProvider).addSection(courseId, 'Section ใหม่'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...sections.map((s) => Card(
                          child: ExpansionTile(
                            title: Text(s.title),
                            trailing: const Icon(Icons.drag_handle),
                            children: [
                              ...s.lectures.map((l) => ListTile(
                                    title: Text(l.title),
                                    subtitle: Text(l.videoRef == null ? 'ยังไม่อัปโหลดวิดีโอ' : 'อัปโหลดแล้ว'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.upload_file),
                                      onPressed: () => context.push(RoutePaths.uploadVideo.replaceFirst(':courseId', courseId).replaceFirst(':lectureId', l.id)),
                                    ),
                                  )),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: AppButton(
                                  label: 'เพิ่ม Lecture',
                                  icon: Icons.add,
                                  variant: AppButtonVariant.ghost,
                                  onPressed: () => ref.read(courseRepositoryProvider).addLecture(courseId, s.id, 'บทเรียนใหม่'),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AppButton(
                  label: 'เผยแพร่คอร์ส',
                  fullWidth: true,
                  onPressed: !canPublish
                      ? null
                      : () async {
                          await ref.read(courseRepositoryProvider).publishCourse(courseId);
                          if (context.mounted) context.go(RoutePaths.instructorDashboard);
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}