import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ab_learning/features/profile/presentation/providers/profile_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_spacing.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขข้อมูลส่วนตัว')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(profile.avatarUrl),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อ-นามสกุล',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'บันทึกการเปลี่ยนแปลง',
              fullWidth: true,
              onPressed: () {
                ref
                    .read(profileProvider.notifier)
                    .updateProfile(_nameController.text, profile.avatarUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ')),
                );
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
