import 'package:flutter/material.dart';

import '../models/update_release.dart';

class UpdateNewsDialog extends StatelessWidget {
  const UpdateNewsDialog({super.key, required this.decision});

  final UpdateNewsDecision decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changes = decision.changes;
    return AlertDialog(
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
        ),
      ),
      title: const Text('Novidades do Vigia IA'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Versão ${decision.installedVersion.display}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (decision.releases.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  '${decision.releases.length} atualizações desde a última visualização',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              for (final change in changes.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    change,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
