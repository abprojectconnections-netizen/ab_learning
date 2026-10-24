// lib/core/widgets/error_state.dart
import 'package:flutter/material.dart';

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ],
      ),
    );
  }
}