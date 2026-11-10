// lib/features/quiz/presentation/screens/quiz_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../marketplace/presentation/providers/course_providers.dart';
import '../../domain/quiz_model.dart';
import '../providers/quiz_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/theme/app_spacing.dart';

class _QuestionControllers {
  _QuestionControllers({String text = '', List<String>? options, this.correct = 0})
      : text = TextEditingController(text: text),
        options = [
          for (final o in options ?? const ['', '']) TextEditingController(text: o),
        ];
  final TextEditingController text;
  final List<TextEditingController> options;
  int correct;

  void dispose() {
    text.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

/// Instructor quiz editor. The answer key is sent to the saveQuiz function,
/// which validates it and stores it where learners can never read it.
class QuizEditorScreen extends ConsumerStatefulWidget {
  final String courseId;
  const QuizEditorScreen({super.key, required this.courseId});
  @override
  ConsumerState<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends ConsumerState<QuizEditorScreen> {
  final _title = TextEditingController();
  final _threshold = TextEditingController(text: '70');
  final List<_QuestionControllers> _questions = [];
  String? _quizId;
  String? _lectureId;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draft = await ref.read(quizRepositoryProvider).loadForEditing(widget.courseId);
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          _quizId = draft.id;
          _lectureId = draft.lectureId;
          _title.text = draft.title;
          _threshold.text = '${draft.passThresholdPercent}';
          for (final q in draft.questions) {
            _questions.add(_QuestionControllers(text: q.text, options: q.options, correct: q.correctIndex));
          }
        }
        if (_questions.isEmpty) _questions.add(_QuestionControllers());
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _threshold.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'กรุณากรอกชื่อแบบทดสอบ';
    final threshold = int.tryParse(_threshold.text.trim());
    if (threshold == null || threshold < 1 || threshold > 100) return 'เกณฑ์ผ่านต้องอยู่ระหว่าง 1-100';
    if (_lectureId == null) return 'กรุณาเลือกบทเรียนที่แบบทดสอบอยู่ท้ายบท';
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.text.text.trim().isEmpty) return 'ข้อ ${i + 1}: กรุณากรอกคำถาม';
      if (q.options.any((o) => o.text.trim().isEmpty)) return 'ข้อ ${i + 1}: กรุณากรอกตัวเลือกให้ครบ';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(quizRepositoryProvider).saveQuiz(
            widget.courseId,
            QuizDraft(
              id: _quizId,
              lectureId: _lectureId!,
              title: _title.text.trim(),
              passThresholdPercent: int.parse(_threshold.text.trim()),
              questions: [
                for (final q in _questions)
                  QuestionDraft(
                    text: q.text.text.trim(),
                    options: [for (final o in q.options) o.text.trim()],
                    correctIndex: q.correct,
                  ),
              ],
            ),
          );
      ref.invalidate(courseQuizProvider(widget.courseId));
      if (mounted) {
        setState(() => _quizId = id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกแบบทดสอบแล้ว')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกไม่สำเร็จ (แก้ไขได้เฉพาะคอร์สสถานะแบบร่าง)')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseByIdProvider(widget.courseId)).valueOrNull;
    final lectures = course?.sections.expand((s) => s.lectures).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('แบบทดสอบท้ายบท')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? const AppErrorState(message: 'โหลดแบบทดสอบไม่สำเร็จ')
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    TextField(controller: _title, decoration: const InputDecoration(labelText: 'ชื่อแบบทดสอบ')),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: lectures.any((l) => l.id == _lectureId) ? _lectureId : null,
                      decoration: const InputDecoration(labelText: 'อยู่ท้ายบทเรียน'),
                      items: [for (final l in lectures) DropdownMenuItem(value: l.id, child: Text(l.title))],
                      onChanged: (v) => setState(() => _lectureId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _threshold,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'เกณฑ์ผ่าน (%)'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (var i = 0; i < _questions.length; i++) _questionCard(i),
                    AppButton(
                      label: 'เพิ่มคำถาม',
                      icon: Icons.add,
                      variant: AppButtonVariant.secondary,
                      onPressed: _questions.length >= 50
                          ? null
                          : () => setState(() => _questions.add(_QuestionControllers())),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(label: 'บันทึกแบบทดสอบ', isLoading: _saving, fullWidth: true, onPressed: _saving ? null : _save),
                  ],
                ),
    );
  }

  Widget _questionCard(int index) {
    final q = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('ข้อที่ ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                tooltip: 'ลบคำถาม',
                onPressed: _questions.length <= 1
                    ? null
                    : () => setState(() => _questions.removeAt(index).dispose()),
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            TextField(controller: q.text, decoration: const InputDecoration(labelText: 'คำถาม')),
            RadioGroup<int>(
              groupValue: q.correct,
              onChanged: (v) => setState(() => q.correct = v ?? 0),
              child: Column(children: [
                for (var o = 0; o < q.options.length; o++)
                  Row(children: [
                    Radio<int>(value: o),
                    Expanded(
                      child: TextField(
                        controller: q.options[o],
                        decoration: InputDecoration(labelText: 'ตัวเลือก ${o + 1}${q.correct == o ? " (คำตอบที่ถูก)" : ""}'),
                      ),
                    ),
                  ]),
              ]),
            ),
            if (q.options.length < 6)
              TextButton.icon(
                onPressed: () => setState(() => q.options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มตัวเลือก'),
              ),
          ],
        ),
      ),
    );
  }
}
