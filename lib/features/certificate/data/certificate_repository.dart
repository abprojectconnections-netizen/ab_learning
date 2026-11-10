// lib/features/certificate/data/certificate_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/certificate_model.dart';

abstract class CertificateRepository {
  Future<List<CertificateModel>> getMyCertificates();
  Future<CertificateModel?> verifyByCode(String code);

  /// Asks the server to issue the certificate if the learner is eligible
  /// (all lessons completed, all quizzes passed). Returns true if issued now.
  Future<bool> claimCertificate(String courseId);
}

class FirebaseCertificateRepository implements CertificateRepository {
  FirebaseCertificateRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  @override
  Future<List<CertificateModel>> getMyCertificates() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to view certificates.');
    final result = await _firestore
        .collection('certificates')
        .where('studentId', isEqualTo: uid)
        .orderBy('issuedAt', descending: true)
        .get();
    return result.docs.map((doc) {
      final d = doc.data();
      return CertificateModel(
        id: doc.id,
        courseId: d['courseId'] as String? ?? '',
        courseTitle: d['courseTitle'] as String? ?? '',
        learnerName: d['learnerName'] as String? ?? '',
        issuedAt: (d['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        verificationCode: d['verificationCode'] as String? ?? doc.id,
      );
    }).toList();
  }

  @override
  Future<CertificateModel?> verifyByCode(String code) async {
    if (code.isEmpty) return null;
    final doc =
        await _firestore.collection('certificate_verifications').doc(code).get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    return CertificateModel(
      id: doc.id,
      courseTitle: d['courseTitle'] as String? ?? '',
      learnerName: d['learnerName'] as String? ?? '',
      issuedAt: (d['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verificationCode: doc.id,
    );
  }

  @override
  Future<bool> claimCertificate(String courseId) async {
    final response = await _functions
        .httpsCallable('claimCertificate')
        .call<Map<Object?, Object?>>({'courseId': courseId});
    return response.data['issued'] == true;
  }
}
