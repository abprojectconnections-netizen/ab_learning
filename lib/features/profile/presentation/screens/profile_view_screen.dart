// lib/features/profile/presentation/screens/profile_view_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/router/role_guard.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final roleLabel = switch (auth.role) {
      UserRole.guest => 'Guest',
      UserRole.learner => 'Learner',
      UserRole.instructor => 'Instructor',
      UserRole.corporateAdmin => 'Corporate Admin',
      UserRole.corporateManager => 'Corporate Manager',
      UserRole.employer => 'Employer',
      UserRole.admin => 'Administration',
      UserRole.superAdmin => 'Super Admin',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: AppSpacing.md),
            Text('UID: ${auth.uid ?? "-"}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('Role: $roleLabel', style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'แก้ไขโปรไฟล์',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(RoutePaths.profileEdit),
            ),
          ],
        ),
      ),
    );
  }
}
