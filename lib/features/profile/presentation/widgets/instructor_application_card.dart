import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/instructor_application_repository.dart';
import '../providers/instructor_application_providers.dart';

/// Lets a learner apply to become an instructor and shows the review status.
class InstructorApplicationCard extends ConsumerStatefulWidget {
  const InstructorApplicationCard({super.key, required this.displayName});

  final String displayName;

  @override
  ConsumerState<InstructorApplicationCard> createState() =>
      _InstructorApplicationCardState();
}

class _InstructorApplicationCardState
    extends ConsumerState<InstructorApplicationCard> {
  final _experience = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _experience.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(instructorApplicationRepositoryProvider).apply(
            displayName: widget.displayName,
            experience: _experience.text,
          );
      ref.invalidate(myInstructorApplicationProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'ส่งใบสมัครไม่สำเร็จ กรุณากรอกประสบการณ์อย่างน้อย 20 ตัวอักษร');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(myInstructorApplicationProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: status.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('โหลดสถานะการสมัครผู้สอนไม่สำเร็จ'),
          data: (s) => switch (s) {
            InstructorApplicationStatus.pending =>
              const Text('ใบสมัครผู้สอนของคุณอยู่ระหว่างการตรวจสอบ'),
            InstructorApplicationStatus.approved =>
              const Text('ใบสมัครผู้สอนได้รับการอนุมัติ ออกจากระบบแล้วเข้าสู่ระบบใหม่เพื่อใช้สิทธิ์ผู้สอน'),
            InstructorApplicationStatus.rejected =>
              const Text('ใบสมัครผู้สอนไม่ได้รับการอนุมัติ'),
            InstructorApplicationStatus.none => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('สมัครเป็นผู้สอน',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _experience,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'ประสบการณ์และสิ่งที่ต้องการสอน',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'กำลังส่ง...' : 'ส่งใบสมัคร'),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
