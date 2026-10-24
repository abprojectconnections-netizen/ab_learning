// lib/core/widgets/app_form_field.dart
import 'package:flutter/material.dart';

enum AppFormFieldType { text, email, password, select }

/// รวม text/email/password/select ไว้ที่เดียว รองรับ default/focus(auto)/error/disabled
class AppFormField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final AppFormFieldType type;
  final String? errorText;
  final bool enabled;
  final List<String>? options; // ใช้เมื่อ type = select
  final String? selectedOption;
  final ValueChanged<String?>? onSelectOption;
  final ValueChanged<String>? onChanged;

  const AppFormField({
    super.key,
    required this.label,
    this.controller,
    this.type = AppFormFieldType.text,
    this.errorText,
    this.enabled = true,
    this.options,
    this.selectedOption,
    this.onSelectOption,
    this.onChanged,
  });

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    if (widget.type == AppFormFieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: widget.selectedOption,
        decoration: InputDecoration(labelText: widget.label, errorText: widget.errorText),
        items: (widget.options ?? []).map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: widget.enabled ? widget.onSelectOption : null,
      );
    }

    final isPassword = widget.type == AppFormFieldType.password;
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: isPassword && _obscure,
      keyboardType: widget.type == AppFormFieldType.email ? TextInputType.emailAddress : TextInputType.text,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}