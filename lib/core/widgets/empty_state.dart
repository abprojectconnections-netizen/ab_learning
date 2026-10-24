// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  const AppEmptyState({super.key, required this.message, this.ctaLabel, this.onCta});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (ctaLabel != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
          ],
        ],
      ),
    );
  }
}