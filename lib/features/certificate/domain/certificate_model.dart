class CertificateModel {
  final String id;
  final String courseId;
  final String courseTitle;
  final String learnerName;
  final DateTime issuedAt;
  final String verificationCode;
  const CertificateModel({
    required this.id,
    this.courseId = '',
    required this.courseTitle,
    required this.learnerName,
    required this.issuedAt,
    required this.verificationCode,
  });
}
