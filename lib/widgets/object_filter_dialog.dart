import 'package:flutter/material.dart';

import '../models/object_filter_catalog.dart';

Future<Set<String>?> showObjectFilterDialog({
  required BuildContext context,
  required Set<String> selectedLabels,
}) async {
  final selectedGroups = <String>{
    ...ObjectFilterCatalog.groupKeysForSelection(selectedLabels),
  };
  if (selectedGroups.isEmpty) {
    selectedGroups.addAll(const <String>{'person', 'vehicle', 'animal'});
  }

  return showDialog<Set<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void toggle(String key) {
          setDialogState(() {
            if (selectedGroups.contains(key)) {
              selectedGroups.remove(key);
            } else {
              selectedGroups.add(key);
            }
          });
        }

        final cards = <({String key, IconData icon, String title, String subtitle})>[
          (
            key: 'person',
            icon: Icons.person_outline_rounded,
            title: 'Pessoas',
            subtitle: 'Detecta pessoas que aparecerem na área monitorada.',
          ),
          (
            key: 'vehicle',
            icon: Icons.directions_car_outlined,
            title: 'Automóveis',
            subtitle: 'Agrupa carros, motos, ônibus e caminhões.',
          ),
          (
            key: 'animal',
            icon: Icons.pets_outlined,
            title: 'Animais',
            subtitle: 'Detecta animais úteis reconhecidos pelo modelo, como cães, gatos, aves e animais rurais.',
          ),
        ];

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          title: const Text('O que a IA deve detectar?'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Escolha um, dois ou os três grupos. Objetos como móveis, alimentos e utensílios não aparecem no monitoramento.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                ...cards.map((item) {
                  final selected = selectedGroups.contains(item.key);
                  final scheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.10)
                          : scheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.55)
                              : scheme.outline.withValues(alpha: 0.18),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => toggle(item.key),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.11),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(item.icon, color: scheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(item.subtitle),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: selected,
                                onChanged: (_) => toggle(item.key),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (selectedGroups.isEmpty)
                  Text(
                    'Ative pelo menos um grupo para continuar.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: selectedGroups.isEmpty
                  ? null
                  : () {
                      final labels = <String>{};
                      for (final key in selectedGroups) {
                        labels.addAll(ObjectFilterCatalog.labelsForGroupKey(key));
                      }
                      Navigator.pop(
                        dialogContext,
                        Set<String>.unmodifiable(labels),
                      );
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aplicar'),
            ),
          ],
        );
      },
    ),
  );
}

String objectFilterSummary(Set<String> labels) {
  final groups = ObjectFilterCatalog.groupKeysForSelection(labels);
  final names = <String>[
    if (groups.contains('person')) 'Pessoas',
    if (groups.contains('vehicle')) 'Automóveis',
    if (groups.contains('animal')) 'Animais',
  ];
  return names.isEmpty ? 'Nenhum grupo' : names.join(' · ');
}

int objectFilterGroupCount(Set<String> labels) =>
    ObjectFilterCatalog.groupKeysForSelection(labels).length;
