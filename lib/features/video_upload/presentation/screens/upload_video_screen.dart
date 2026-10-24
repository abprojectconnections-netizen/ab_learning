// lib/features/video_upload/presentation/screens/upload_video_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class UploadVideoScreen extends StatefulWidget {
  final String courseId;
  final String lectureId;
  const UploadVideoScreen({super.key, required this.courseId, required this.lectureId});
  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  double _progress = 0;
  bool _uploading = false;
  bool _isPreview = false;

  Future<void> _pickAndUpload() async {
    setState(() { _uploading = true; _progress = 0; });
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _progress = i / 10);
    }
    setState(() => _uploading = false);
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
                  border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(_uploading ? 'กำลังอัปโหลด...' : 'ลากไฟล์มาวาง หรือ กดเพื่อเลือกไฟล์', style: AppTextStyles.bodyMedium),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_uploading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: AppSpacing.sm),
              Text('${(_progress * 100).toStringAsFixed(0)}%', style: AppTextStyles.caption),
            ],
            CheckboxListTile(
              value: _isPreview,
              onChanged: (v) => setState(() => _isPreview = v ?? false),
              title: const Text('ตั้งเป็น Preview ฟรี'),
            ),
            const Spacer(),
            AppButton(
              label: 'เสร็จสิ้น',
              fullWidth: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}