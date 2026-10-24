// lib/features/certificate/domain/certificate_model.dart
class CertificateModel {
  final String id;
  final String courseTitle;
  final String learnerName;
  final DateTime issuedAt;
  final String verificationCode;
  const CertificateModel({
    required this.id,
    required this.courseTitle,
    required this.learnerName,
    required this.issuedAt,
    required this.verificationCode,
  });
}