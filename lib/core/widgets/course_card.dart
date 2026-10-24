// lib/core/widgets/course_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/marketplace/domain/course_model.dart';
import '../router/route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

const double kCourseCardHeight = 310;

class CourseCard extends StatelessWidget {
  final CourseModel? course;
  final bool isSkeleton;
  const CourseCard({super.key, required this.course}) : isSkeleton = false;
  const CourseCard.skeleton({super.key}) : course = null, isSkeleton = true;

  @override
  Widget build(BuildContext context) {
    if (isSkeleton) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.gray100,
        child: const SizedBox.expand(),
      );
    }
    final c = course!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // ⭐ คลิกแล้วเปิดหน้ารายละเอียดคอร์ส (Course Detail) อย่างถูกต้อง
            final targetPath = RoutePaths.courseDetail.replaceFirst(':courseId', c.id);
            context.push(targetPath);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        c.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.gray200,
                          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.gray400),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('ยอดฮิต', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.gray900),
                          ),
                          const SizedBox(height: 4),
                          Text(c.instructorName, style: AppTextStyles.caption.copyWith(color: AppColors.gray500)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(c.avgRating.toStringAsFixed(1), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            '฿${c.price.toStringAsFixed(0)}',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}