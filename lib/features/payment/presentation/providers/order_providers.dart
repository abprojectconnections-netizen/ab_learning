// lib/features/payment/presentation/providers/order_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../data/firebase_order_repository.dart';
import '../../data/order_repository.dart';
import '../../domain/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return FirebaseOrderRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    functions: FirebaseFunctions.instance,
  );
});

final orderByIdProvider =
    FutureProvider.autoDispose.family<OrderModel, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).getOrderById(orderId);
});
