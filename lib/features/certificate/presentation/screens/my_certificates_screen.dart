import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/certificate_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/certificate_card.dart';
import '../../../../core/theme/app_spacing.dart';

class MyCertificatesScreen extends ConsumerWidget {
  const MyCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(myCertificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ใบประกาศนียบัตรของฉัน')),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(
            message: 'โหลดใบประกาศไม่สำเร็จ',
            onRetry: () => ref.invalidate(myCertificatesProvider)),
        data: (certs) => certs.isEmpty
          ? const AppEmptyState(message: 'ยังไม่มีใบประกาศนียบัตร เรียนให้จบคอร์ส 100% และผ่าน Quiz เพื่อรับใบนี้')
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: certs.length,
              itemBuilder: (c, i) {
                final cert = certs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CertificateCard(
                    courseTitle: cert.courseTitle,
                    learnerName: cert.learnerName,
                    issuedAt: cert.issuedAt,
                    verificationCode: cert.verificationCode,
                    state: CertificateCardState.ready,
                    // PDF export is not implemented; share the verifiable code.
                    onDownload: () async {
                      await Clipboard.setData(ClipboardData(text: cert.verificationCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกรหัสตรวจสอบแล้ว')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
      ),
    );
  }
}