// lib/core/widgets/app_data_table.dart
import 'package:flutter/material.dart';
import 'empty_state.dart';
import 'error_state.dart';

/// Wrapper รอบ DataTable ที่จัดการ loading/empty/populated/error ให้อัตโนมัติ
class AppDataTable<T> extends StatelessWidget {
  final AsyncSnapshot<List<T>>? snapshot; // ใช้เมื่อข้อมูลมาจาก Future/Stream โดยตรง
  final List<T>? items; // หรือส่ง list ที่โหลดเสร็จแล้วมาตรง ๆ
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;

  const AppDataTable({
    super.key,
    this.items,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage = 'ไม่มีข้อมูล',
    required this.columns,
    required this.rowBuilder,
    this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) return AppErrorState(message: errorMessage!, onRetry: onRetry);
    final data = items ?? [];
    if (data.isEmpty) return AppEmptyState(message: emptyMessage);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: data.map(rowBuilder).toList(),
      ),
    );
  }
}