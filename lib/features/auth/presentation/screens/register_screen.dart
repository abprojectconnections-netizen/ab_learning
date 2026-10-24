// lib/features/auth/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/theme/app_spacing.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _agree = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'รหัสผ่านไม่ตรงกัน');
      return;
    }
    if (!_agree) {
      setState(() => _error = 'กรุณายอมรับข้อตกลงก่อน');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).register(email: _emailCtrl.text, password: _passCtrl.text);
      // if (mounted) context.go(RoutePaths.home);
    } catch (e) {
      setState(() => _error = 'สมัครสมาชิกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFormField(label: 'อีเมล', controller: _emailCtrl, type: AppFormFieldType.email),
                const SizedBox(height: AppSpacing.md),
                AppFormField(label: 'รหัสผ่าน', controller: _passCtrl, type: AppFormFieldType.password),
                const SizedBox(height: AppSpacing.md),
                AppFormField(label: 'ยืนยันรหัสผ่าน', controller: _confirmCtrl, type: AppFormFieldType.password),
                CheckboxListTile(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  title: const Text('ฉันยอมรับข้อตกลงการใช้งาน'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
                AppButton(
                  label: 'สมัครสมาชิก',
                  isLoading: _loading,
                  fullWidth: true,
                  onPressed: _loading ? null : _submit,
                ),
                AppButton(
                  label: 'มีบัญชีแล้ว? เข้าสู่ระบบ',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}