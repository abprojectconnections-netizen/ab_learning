// lib/features/course_detail/presentation/screens/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/state/app_store.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseByIdProvider(courseId));
    final appState = ref.watch(appStoreProvider);
    final isEnrolled = appState.enrolledCourseIds.contains(courseId);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(message: 'โหลดข้อมูลคอร์สไม่สำเร็จ', onRetry: () => ref.invalidate(courseByIdProvider(courseId))),
        data: (course) {
          if (course == null) return const AppErrorState(message: 'ไม่พบคอร์สนี้ในระบบ');

          return CustomScrollView(
            slivers: [
              // App Bar แบบยุบได้พร้อมรูปภาพปก
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        course.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppColors.gray300),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black54, Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // เนื้อหารายละเอียดคอร์ส
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ฝั่งซ้าย: ข้อมูลหลัก
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('คอร์สยอดนิยม', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(height: 12),
                            Text(course.title, style: AppTextStyles.h1.copyWith(fontSize: 26)),
                            const SizedBox(height: 8),
                            Text(course.description, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gray600)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: AppColors.gray500),
                                const SizedBox(width: 6),
                                Text('ผู้สอน: ${course.instructorName}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 24),
                                const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text('${course.avgRating.toStringAsFixed(1)} (รีวิวเพียบ)', style: AppTextStyles.bodyMedium),
                              ],
                            ),
                            const Divider(height: 48),
                            Text('เนื้อหาภายในคอร์ส', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            ...course.sections.map((section) => Card(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.gray200),
                              ),
                              child: ExpansionTile(
                                title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                children: section.lectures.map((lecture) => ListTile(
                                  dense: true,
                                  leading: Icon(lecture.isPreview ? Icons.play_circle_outline : Icons.lock_outline, color: AppColors.primary),
                                  title: Text(lecture.title),
                                  trailing: lecture.isPreview ? const Text('ดูตัวอย่างฟรี', style: TextStyle(color: AppColors.primary, fontSize: 12)) : null,
                                )).toList(),
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // ฝั่งขวา: กล่องราคาและปุ่มสั่งซื้อ (Sticky Card ด้านข้าง)
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '฿${course.price.toStringAsFixed(0)}',
                                style: AppTextStyles.h1.copyWith(color: AppColors.primary, fontSize: 32),
                              ),
                              const SizedBox(height: 16),
                              const Text('✓ เข้าถึงเนื้อหาได้ตลอดชีพ\n✓ ใบประกาศนียบัตรหลังเรียนจบ\n✓ แบบทดสอบวัดความรู้', style: TextStyle(height: 1.6, color: AppColors.gray600)),
                              const SizedBox(height: 24),
                              
                              // เช็คว่าซื้อแล้วหรือยัง ถ้าซื้อแล้วเปลี่ยนปุ่มเป็น "เข้าสู่บทเรียน"
                              AppButton(
                                label: isEnrolled ? 'เข้าสู่บทเรียน' : 'สั่งซื้อคอร์สนี้',
                                fullWidth: true,
                                icon: isEnrolled ? Icons.school : Icons.shopping_cart_checkout,
                                onPressed: () {
                                  if (isEnrolled) {
                                    context.push(RoutePaths.videoLearning.replaceFirst(':courseId', course.id).replaceFirst(':lectureId', 'l1'));
                                  } else {
                                    context.push(RoutePaths.checkout.replaceFirst(':courseId', course.id));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}