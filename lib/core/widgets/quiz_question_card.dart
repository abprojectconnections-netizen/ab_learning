// lib/core/widgets/quiz_question_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum QuizOptionState { unanswered, selected, correct, incorrect, locked }

class QuizQuestionCard extends StatelessWidget {
  final String questionText;
  final List<String> options;
  final int? selectedIndex;
  final int?
      correctIndex; // ส่งมาเฉพาะตอนแสดงเฉลย (หลัง submit) ไม่ใช่ตอนทำข้อสอบ
  final bool locked; // ยังไม่ถึงคำถามนี้ หรือ submit ไปแล้ว
  final ValueChanged<int>? onSelect;

  const QuizQuestionCard({
    super.key,
    required this.questionText,
    required this.options,
    required this.selectedIndex,
    this.correctIndex,
    this.locked = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(questionText, style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<int>(
              groupValue: selectedIndex,
              onChanged: (value) {
                if (value != null && !locked && correctIndex == null) {
                  onSelect?.call(value);
                }
              },
              child: Column(
                  children: List.generate(
                      options.length, (i) => _buildOption(context, i))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, int i) {
    final isSelected = selectedIndex == i;
    final showResult = correctIndex != null;
    final isCorrectOption = showResult && correctIndex == i;
    final isWrongSelected = showResult && isSelected && correctIndex != i;

    Color borderColor = AppColors.gray300;
    Color? bgColor;
    IconData? trailingIcon;
    Color? iconColor;

    if (showResult) {
      if (isCorrectOption) {
        borderColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.08);
        trailingIcon = Icons.check_circle;
        iconColor = AppColors.success;
      } else if (isWrongSelected) {
        borderColor = AppColors.danger;
        bgColor = AppColors.danger.withValues(alpha: 0.08);
        trailingIcon = Icons.cancel;
        iconColor = AppColors.danger;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.06);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: (locked || showResult) ? null : () => onSelect?.call(i),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            color: bgColor,
          ),
          child: Row(
            children: [
              Radio<int>(value: i, enabled: !(locked || showResult)),
              Expanded(
                  child: Text(options[i], style: AppTextStyles.bodyMedium)),
              if (trailingIcon != null)
                Icon(trailingIcon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
