import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/certificate_repository.dart';
import '../../domain/certificate_model.dart';

final certificateRepositoryProvider = Provider<CertificateRepository>((ref) {
  return FirebaseCertificateRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final myCertificatesProvider = FutureProvider.autoDispose<List<CertificateModel>>((ref) {
  return ref.watch(certificateRepositoryProvider).getMyCertificates();
});
