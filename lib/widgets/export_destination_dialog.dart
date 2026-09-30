import 'package:flutter/material.dart';

import '../services/export_preferences_service.dart';

/// Retorna `false` para Downloads, `true` para o seletor do Android e `null`
/// quando o usuário cancela.
Future<bool?> resolveExportLocation(
  BuildContext context, {
  required String title,
}) async {
  final preference = await ExportPreferencesService.instance.initialize();
  if (!context.mounted) return null;
  if (preference == ExportDestinationPreference.downloads) return false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: const Text(
        'Escolha Downloads/Vigia IA ou outro local pelo seletor do Android.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Escolher local'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, false),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Downloads'),
        ),
      ],
    ),
  );
}
