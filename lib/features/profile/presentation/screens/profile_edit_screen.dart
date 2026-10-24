// lib/features/profile/presentation/screens/profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/router/role_guard.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/avatar_upload.dart';
import '../../../../core/theme/app_spacing.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isInstructor = auth.role == UserRole.instructor;
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const AvatarUpload(state: AvatarUploadState.empty),
            const SizedBox(height: AppSpacing.xl),
            AppFormField(label: 'ชื่อที่แสดง', controller: _nameCtrl),
            const SizedBox(height: AppSpacing.md),
            if (isInstructor) ...[
              AppFormField(label: 'แนะนำตัว (Bio)', controller: _bioCtrl),
              const SizedBox(height: AppSpacing.md),
              const AppFormField(label: 'เลขบัญชีธนาคาร (สำหรับถอนเงิน)'),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'บันทึก',
              isLoading: _saving,
              fullWidth: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}