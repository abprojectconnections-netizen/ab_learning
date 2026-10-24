// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/router/role_guard.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/theme/app_spacing.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).signIn(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      if (!mounted) return;
      final role = guardRoleFor(user.role);
      for (var attempt = 0;
          attempt < 30 && ref.read(authStateProvider).role != role;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      if (!mounted) return;
      final requestedRoute =
          GoRouterState.of(context).uri.queryParameters['redirect'];
      context.go(requestedRoute ?? homePathForRole(role));
    } catch (e) {
      setState(() => _error = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าสู่ระบบ')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFormField(
                    label: 'อีเมล',
                    controller: _emailCtrl,
                    type: AppFormFieldType.email),
                const SizedBox(height: AppSpacing.md),
                AppFormField(
                    label: 'รหัสผ่าน',
                    controller: _passCtrl,
                    type: AppFormFieldType.password),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    label: 'ลืมรหัสผ่าน?',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => context.push(RoutePaths.forgotPassword),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                AppButton(
                  label: 'เข้าสู่ระบบ',
                  isLoading: _loading,
                  fullWidth: true,
                  onPressed: _loading ? null : _submit,
                ),
                AppButton(
                  label: 'ยังไม่มีบัญชี? สมัครสมาชิก',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.register),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
