import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/course_card.dart';
import '../../../../core/widgets/course_grid.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../providers/course_providers.dart';

class CourseMarketplaceScreen extends ConsumerStatefulWidget {
  const CourseMarketplaceScreen({super.key});

  @override
  ConsumerState<CourseMarketplaceScreen> createState() =>
      _CourseMarketplaceScreenState();
}

class _CourseMarketplaceScreenState
    extends ConsumerState<CourseMarketplaceScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final categories = categoriesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => [],
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 48,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF642E5A),
                    Color(0xFFB450FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'พัฒนาทักษะสู่อนาคตที่ดีกว่า',
                    style: AppTextStyles.h1.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'เรียนรู้จากผู้เชี่ยวชาญ คอร์สคุณภาพเพื่อการเติบโตในสายอาชีพ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final category = isAll ? null : categories[index - 1];

                    final isSelected = isAll
                        ? _selectedCategoryId == null
                        : _selectedCategoryId == category!.id;

                    return ChoiceChip(
                      label: Text(
                        isAll ? 'ทั้งหมด' : category!.name,
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = category?.id;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          coursesAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: CourseGrid(
                  itemCount: 8,
                  itemBuilder: (_, __) => const CourseCard.skeleton(),
                ),
              ),
            ),
            error: (error, stackTrace) => SliverFillRemaining(
              child: AppErrorState(
                message: 'โหลดคอร์สไม่สำเร็จ',
                onRetry: () {
                  ref.invalidate(publishedCoursesProvider);
                },
              ),
            ),
            data: (courses) {
              final filteredCourses = _selectedCategoryId == null
                  ? courses
                  : courses
                      .where(
                        (course) => course.categoryId == _selectedCategoryId,
                      )
                      .toList();

              if (filteredCourses.isEmpty) {
                return const SliverFillRemaining(
                  child: AppEmptyState(
                    message: 'ยังไม่มีคอร์สในหมวดนี้',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: CourseGrid(
                    itemCount: filteredCourses.length,
                    itemBuilder: (_, index) => CourseCard(
                      course: filteredCourses[index],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
