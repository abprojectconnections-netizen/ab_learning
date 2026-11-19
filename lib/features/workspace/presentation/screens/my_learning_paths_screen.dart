import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../providers/workspace_providers.dart';

/// Learning paths assigned by the member's organization, with links to each course.
class MyLearningPathsScreen extends ConsumerWidget {
  const MyLearningPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(myLearningPathsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('แผนการเรียนขององค์กร')),
      body: paths.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myLearningPathsProvider),
            child: const Text('โหลดไม่สำเร็จ ลองอีกครั้ง'),
          ),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('ยังไม่มีแผนการเรียนจากองค์กรของคุณ'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final path in list)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(path.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (path.description.isNotEmpty) Text(path.description),
                            const SizedBox(height: 8),
                            if (path.courseIds.isEmpty)
                              const Text('ยังไม่ได้กำหนดคอร์สในแผนนี้')
                            else
                              for (final id in path.courseIds)
                                _CourseTile(courseId: id),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CourseTile extends ConsumerWidget {
  const _CourseTile({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseByIdProvider(courseId));
    return course.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (c) => c == null
          ? const SizedBox.shrink()
          : ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(c.title),
              onTap: () => context.push('/courses/${c.id}'),
            ),
    );
  }
}
