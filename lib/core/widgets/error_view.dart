import 'package:flutter/material.dart';
import 'package:shiori/core/errors/error_messages.dart';
import 'package:shiori/l10n/l10n.dart';

/// Full-area error state for a failed load, with an optional retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onRetry = this.onRetry;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          spacing: 16,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            Text(
              errorMessage(context, error),
              style: theme.textTheme.bodyLarge,
              textAlign: .center,
            ),
            if (onRetry != null)
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}
