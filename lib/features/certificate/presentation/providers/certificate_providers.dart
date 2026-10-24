// lib/features/certificate/presentation/providers/certificate_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/certificate_repository.dart';
import '../../domain/certificate_model.dart';

final certificateRepositoryProvider = Provider<CertificateRepository>((ref) => MockCertificateRepository());

final myCertificatesProvider = FutureProvider.autoDispose<List<CertificateModel>>((ref) {
  return ref.watch(certificateRepositoryProvider).getMyCertificates();
});