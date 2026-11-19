// lib/features/video_upload/presentation/screens/upload_video_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/video_upload_repository.dart';
import '../providers/video_upload_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class UploadVideoScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String lectureId;
  const UploadVideoScreen({super.key, required this.courseId, required this.lectureId});
  @override
  ConsumerState<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends ConsumerState<UploadVideoScreen> {
  double _progress = 0;
  bool _uploading = false;
  bool _isPreview = false;
  String? _message;

  Future<void> _pickAndUpload() async {
    // Mobile streams from disk (no bytes in memory); web needs the bytes.
    final picked = await FilePicker.platform.pickFiles(type: FileType.video, withData: kIsWeb);
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    final filePath = kIsWeb ? null : file.path;
    if (bytes == null && filePath == null) return;
    if (file.size >= kMaxVideoBytes) {
      setState(() => _message = 'ไฟล์ใหญ่เกิน 500 MB');
      return;
    }
    setState(() { _uploading = true; _progress = 0; _message = null; });
    try {
      final ext = (file.extension ?? 'mp4').toLowerCase();
      await for (final p in ref.read(videoUploadRepositoryProvider).uploadLessonVideo(
            courseId: widget.courseId,
            lessonId: widget.lectureId,
            sizeBytes: file.size,
            filePath: filePath,
            bytes: bytes,
            contentType: ext == 'mov' ? 'video/quicktime' : 'video/$ext',
          )) {
        if (mounted) setState(() => _progress = p.fraction);
      }
      if (mounted) setState(() => _message = 'อัปโหลดสำเร็จ');
    } catch (_) {
      if (mounted) setState(() => _message = 'อัปโหลดไม่สำเร็จ (คอร์สต้องอยู่ในสถานะแบบร่าง)');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _togglePreview(bool value) async {
    setState(() => _isPreview = value);
    try {
      await ref
          .read(videoUploadRepositoryProvider)
          .setPreview(widget.courseId, widget.lectureId, value);
    } catch (_) {
      if (mounted) {
        setState(() { _isPreview = !value; _message = 'ตั้งค่า Preview ไม่สำเร็จ'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('อัปโหลดวิดีโอ: บทเรียน ${widget.lectureId}')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            InkWell(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(_uploading ? 'กำลังอัปโหลด...' : 'กดเพื่อเลือกไฟล์วิดีโอ (ไม่เกิน 500 MB)', style: AppTextStyles.bodyMedium),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_uploading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: AppSpacing.sm),
              Text('${(_progress * 100).toStringAsFixed(0)}%', style: AppTextStyles.caption),
            ],
            if (_message != null) Text(_message!, style: AppTextStyles.caption),
            CheckboxListTile(
              value: _isPreview,
              onChanged: _uploading ? null : (v) => _togglePreview(v ?? false),
              title: const Text('ตั้งเป็น Preview ฟรี'),
            ),
            const Spacer(),
            AppButton(
              label: 'เสร็จสิ้น',
              fullWidth: true,
              onPressed: _uploading ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
