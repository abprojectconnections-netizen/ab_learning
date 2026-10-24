import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/app_store.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/certificate_card.dart';
import '../../../../core/theme/app_spacing.dart';

class MyCertificatesScreen extends ConsumerWidget {
  const MyCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ดึงใบประกาศจาก Store กลางที่ออกให้อัตโนมัติเมื่อเรียนจบ 100% + Quiz ผ่าน
    final certs = ref.watch(appStoreProvider).certificates;

    return Scaffold(
      appBar: AppBar(title: const Text('ใบประกาศนียบัตรของฉัน')),
      body: certs.isEmpty
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
                    onDownload: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('จำลองการดาวน์โหลดไฟล์ PDF สำเร็จ')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}