// lib/features/search/presentation/screens/search_results_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../../../core/widgets/course_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/app_form_field.dart';
import '../../../../core/widgets/course_grid.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});
  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: AppFormField(
          label: 'ค้นหาคอร์ส...',
          controller: _queryCtrl,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text('พิมพ์คำค้นหาเพื่อเริ่มค้นหา'))
          : resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => AppErrorState(message: 'ค้นหาไม่สำเร็จ', onRetry: () => ref.invalidate(searchResultsProvider(_query))),
              data: (results) {
                if (results.isEmpty) return AppEmptyState(message: "ไม่พบผลลัพธ์สำหรับ '$_query'");
                // return GridView.builder(
                //   padding: const EdgeInsets.all(AppSpacing.lg),
                //   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
                //   itemCount: results.length,
                //   itemBuilder: (c, i) => CourseCard(course: results[i]),
                // );

                return CourseGrid(itemCount: results.length, itemBuilder: (_, i) => CourseCard(course: results[i]));

              },
            ),
    );
  }
}