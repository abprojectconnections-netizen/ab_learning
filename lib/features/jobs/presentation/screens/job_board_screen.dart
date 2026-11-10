// lib/features/jobs/presentation/screens/job_board_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_board_providers.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';

class JobBoardScreen extends ConsumerStatefulWidget {
  const JobBoardScreen({super.key});
  @override
  ConsumerState<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends ConsumerState<JobBoardScreen> {
  final Set<String> _applying = {};

  Future<void> _apply(String jobId) async {
    setState(() => _applying.add(jobId));
    try {
      await ref.read(jobBoardRepositoryProvider).apply(jobId);
      ref.invalidate(appliedJobIdsProvider);
      _toast('ส่งใบสมัครแล้ว');
    } catch (_) {
      _toast('สมัครไม่สำเร็จ ตำแหน่งอาจปิดรับแล้ว');
      ref.invalidate(openJobsProvider);
    } finally {
      if (mounted) setState(() => _applying.remove(jobId));
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(openJobsProvider);
    final applied = ref.watch(appliedJobIdsProvider).valueOrNull ?? const <String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('ตำแหน่งงานที่เปิดรับ')),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => AppErrorState(
            message: 'โหลดตำแหน่งงานไม่สำเร็จ',
            onRetry: () => ref.invalidate(openJobsProvider)),
        data: (items) => items.isEmpty
            ? const AppEmptyState(message: 'ยังไม่มีตำแหน่งงานที่เปิดรับ')
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final job = items[i];
                  final done = applied.contains(job.id);
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.work_outline)),
                    title: Text(job.title),
                    subtitle: Text(job.location),
                    trailing: done
                        ? const Chip(label: Text('สมัครแล้ว'))
                        : FilledButton(
                            onPressed: _applying.contains(job.id) ? null : () => _apply(job.id),
                            child: _applying.contains(job.id)
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('สมัคร'),
                          ),
                  );
                },
              ),
      ),
    );
  }
}
