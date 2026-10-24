// lib/features/auth/presentation/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    await ref.read(authRepositoryProvider).sendPasswordReset(_emailCtrl.text);
    setState(() { _loading = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลืมรหัสผ่าน')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _sent
                ? Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมล ${_emailCtrl.text} แล้ว กรุณาตรวจสอบกล่องจดหมาย', style: AppTextStyles.bodyMedium)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppFormField(label: 'อีเมลที่ใช้สมัคร', controller: _emailCtrl, type: AppFormFieldType.email),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'ส่งลิงก์รีเซ็ตรหัสผ่าน',
                        isLoading: _loading,
                        fullWidth: true,
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}