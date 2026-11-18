// lib/features/profile/presentation/screens/profile_edit_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/profile_repository.dart';
import '../providers/profile_provider.dart';
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
  bool _prefilled = false;
  bool _uploadingAvatar = false;
  bool _avatarFailed = false;

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(profileRepositoryProvider).deleteMyAccount();
      await ref.read(authRepositoryProvider).signOut();
    } on AccountDeletionBlocked catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบบัญชีไม่สำเร็จ กรุณาลองใหม่')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อที่แสดง')));
      return;
    }
    final isInstructor = ref.read(authStateProvider).role == UserRole.instructor;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
            displayName: name,
            bio: isInstructor ? _bioCtrl.text : null,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() { _uploadingAvatar = true; _avatarFailed = false; });
    try {
      final ext = (file.extension ?? 'jpeg').toLowerCase();
      await ref.read(profileRepositoryProvider).uploadAvatar(
          bytes, 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      ref.invalidate(myProfileProvider);
    } catch (_) {
      if (mounted) setState(() => _avatarFailed = true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isInstructor = auth.role == UserRole.instructor;
    final profile = ref.watch(myProfileProvider);

    profile.whenData((p) {
      if (_prefilled) return;
      _prefilled = true;
      _nameCtrl.text = p.displayName;
      _bioCtrl.text = p.bio ?? '';
    });

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: profile.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  AvatarUpload(
                    imageUrl: profile.valueOrNull?.photoUrl,
                    onTap: _pickAvatar,
                    state: _uploadingAvatar
                        ? AvatarUploadState.uploading
                        : _avatarFailed
                            ? AvatarUploadState.error
                            : profile.valueOrNull?.photoUrl != null
                                ? AvatarUploadState.preview
                                : AvatarUploadState.empty,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppFormField(label: 'ชื่อที่แสดง', controller: _nameCtrl),
                  const SizedBox(height: AppSpacing.md),
                  if (isInstructor) ...[
                    AppFormField(label: 'แนะนำตัว (Bio)', controller: _bioCtrl),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'บันทึก',
                    isLoading: _saving,
                    fullWidth: true,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('ลบบัญชี', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Owns its controller so it is disposed only after the dialog is fully gone.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ลบบัญชีถาวร'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ข้อมูลส่วนตัว การลงทะเบียน ความคืบหน้า และใบประกาศนียบัตรของคุณจะถูกลบและกู้คืนไม่ได้ '
              'พิมพ์ DELETE เพื่อยืนยัน'),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _confirm, autofocus: true),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _confirm.text.trim() == 'DELETE'),
          child: const Text('ลบบัญชี'),
        ),
      ],
    );
  }
}
