// lib/features/certificate/presentation/screens/certificate_verify_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/certificate_providers.dart';
import '../../domain/certificate_model.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class CertificateVerifyScreen extends ConsumerStatefulWidget {
  const CertificateVerifyScreen({super.key});
  @override
  ConsumerState<CertificateVerifyScreen> createState() => _CertificateVerifyScreenState();
}

class _CertificateVerifyScreenState extends ConsumerState<CertificateVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  CertificateModel? _result;
  bool _notFound = false;

  Future<void> _check() async {
    setState(() { _loading = true; _notFound = false; _result = null; });
    final cert = await ref.read(certificateRepositoryProvider).verifyByCode(_codeCtrl.text.trim());
    setState(() { _loading = false; _result = cert; _notFound = cert == null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบใบประกาศนียบัตร')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFormField(label: 'กรอกรหัสใบประกาศนียบัตร', controller: _codeCtrl),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'ตรวจสอบ',
                  isLoading: _loading,
                  fullWidth: true,
                  onPressed: _loading ? null : _check,
                ),
                if (_notFound)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Text('ไม่พบใบประกาศนียบัตรนี้ในระบบ', style: TextStyle(color: Colors.red)),
                  ),
                if (_result != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Column(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 48),
                        const SizedBox(height: AppSpacing.sm),
                        Text('ใบนี้ถูกต้อง', style: AppTextStyles.h3),
                        Text('ออกให้: ${_result!.learnerName}', style: AppTextStyles.bodyMedium),
                        Text('คอร์ส: ${_result!.courseTitle}', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}