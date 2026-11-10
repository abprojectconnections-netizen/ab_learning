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

  /// Save course draft and navigate to curriculum builder.
  Future<void> _saveDraft() async {
    // Prevent duplicate submissions.
    if (_saving) return;

    // Validate input.
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText) ?? 0;

    if (title.isEmpty) {
      _showMessage('กรุณากรอกชื่อคอร์ส');
      return;
    }

    if (_categoryId == null || _categoryId!.isEmpty) {
      _showMessage('กรุณาเลือกหมวดหมู่คอร์ส');
      return;
    }

    if (price < 0) {
      _showMessage('กรุณาระบุราคาที่ถูกต้อง');
      return;
    }

    setState(() => _saving = true);

    try {
      final id = await ref.read(courseRepositoryProvider).createCourse(
            title: title,
            description: description,
            price: price,
            categoryId: _categoryId!,
          );

      if (!mounted) return;

      setState(() => _saving = false);

      // Navigate after successfully creating the course.
      await context.push(
        RoutePaths.curriculumBuilder.replaceFirst(':courseId', id),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('ไม่สามารถบันทึกคอร์สได้ กรุณาลองอีกครั้ง');

      debugPrint('Course creation error: $error');
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  /// Display a message to the user.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างคอร์สใหม่'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            AppFormField(
              label: 'ชื่อคอร์ส',
              controller: _titleCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormField(
              label: 'คำอธิบาย',
              controller: _descCtrl,
            ),
            const SizedBox(height: AppSpacing.md),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text(
                'โหลดหมวดหมู่ไม่สำเร็จ',
                style: TextStyle(color: Colors.red),
              ),
              data: (categories) => AppFormField(
                label: 'หมวดหมู่',
                type: AppFormFieldType.select,
                options: categories.map((category) => category.name).toList(),
                selectedOption: categories
                    .where((category) => category.id == _categoryId)
                    .map((category) => category.name)
                    .firstOrNull,
                onSelectOption: (value) {
                  final matched = categories
                      .where((category) => category.name == value)
                      .firstOrNull;

                  if (matched != null) {
                    setState(() => _categoryId = matched.id);
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppFormField(
              label: 'ราคา (บาท)',
              controller: _priceCtrl,
            ),
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
