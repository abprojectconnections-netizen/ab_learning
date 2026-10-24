// lib/features/certificate/data/certificate_repository.dart
import '../domain/certificate_model.dart';

abstract class CertificateRepository {
  Future<List<CertificateModel>> getMyCertificates();
  Future<CertificateModel?> verifyByCode(String code);
}

class MockCertificateRepository implements CertificateRepository {
  @override
  Future<List<CertificateModel>> getMyCertificates() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      CertificateModel(id: 'cert-1', courseTitle: 'Flutter Intro', learnerName: 'สมหญิง ใจดี', issuedAt: DateTime(2025, 1, 10), verificationCode: 'AB-0001-2025'),
    ];
  }

  @override
  Future<CertificateModel?> verifyByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (code == 'AB-0001-2025') {
      return CertificateModel(id: 'cert-1', courseTitle: 'Flutter Intro', learnerName: 'สมหญิง ใจดี', issuedAt: DateTime(2025, 1, 10), verificationCode: code);
    }
    return null; // ไม่พบ -> UI แสดง error state
  }
}