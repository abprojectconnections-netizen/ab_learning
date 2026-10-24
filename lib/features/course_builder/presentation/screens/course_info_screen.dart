// lib/features/course_builder/presentation/screens/course_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_spacing.dart';

class CourseInfoScreen extends ConsumerStatefulWidget {
  const CourseInfoScreen({super.key});
  @override
  ConsumerState<CourseInfoScreen> createState() => _CourseInfoScreenState();
}

class _CourseInfoScreenState extends ConsumerState<CourseInfoScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _categoryId;
  bool _saving = false;

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final id = await ref.read(courseRepositoryProvider).createCourse(
          title: _titleCtrl.text,
          description: _descCtrl.text,
          price: double.tryParse(_priceCtrl.text) ?? 0,
          categoryId: _categoryId ?? '',
        );
    setState(() => _saving = false);
    if (mounted) context.push(RoutePaths.curriculumBuilder.replaceFirst(':courseId', id));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างคอร์สใหม่')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            AppFormField(label: 'ชื่อคอร์ส', controller: _titleCtrl),
            const SizedBox(height: AppSpacing.md),
            AppFormField(label: 'คำอธิบาย', controller: _descCtrl),
            const SizedBox(height: AppSpacing.md),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => const Text('โหลดหมวดหมู่ไม่สำเร็จ', style: TextStyle(color: Colors.red)),
              data: (cats) => AppFormField(
                label: 'หมวดหมู่',
                type: AppFormFieldType.select,
                options: cats.map((c) => c.name).toList(),
                selectedOption: cats.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull,
                onSelectOption: (val) {
                  final matched = cats.where((c) => c.name == val).firstOrNull;
                  if (matched != null) setState(() => _categoryId = matched.id);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormField(label: 'ราคา (บาท)', controller: _priceCtrl),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'อัปโหลด Thumbnail',
              icon: Icons.image,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'บันทึกและไปจัดหลักสูตร',
              isLoading: _saving,
              fullWidth: true,
              onPressed: _saving ? null : _saveDraft,
            ),
          ],
        ),
      ),
    );
  }
}