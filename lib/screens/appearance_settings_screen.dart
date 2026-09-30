import 'dart:async';

import 'package:flutter/material.dart';

import '../services/appearance_settings_service.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceSettingsService.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Aparência')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _Header(
              title: 'Tema',
              subtitle: 'Escolha se o aplicativo acompanha o Android ou usa um tema fixo.',
            ),
            SegmentedButton<AppThemePreference>(
              segments: const [
                ButtonSegment(
                  value: AppThemePreference.system,
                  icon: Icon(Icons.settings_brightness_outlined),
                  label: Text('Sistema'),
                ),
                ButtonSegment(
                  value: AppThemePreference.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: AppThemePreference.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Escuro'),
                ),
              ],
              selected: <AppThemePreference>{appearance.themePreference},
              onSelectionChanged: (selection) {
                unawaited(appearance.setThemePreference(selection.first));
              },
            ),
            const SizedBox(height: 24),
            const _Header(
              title: 'Cor principal',
              subtitle: 'A cor escolhida é aplicada aos botões, seleções e destaques do aplicativo inteiro.',
            ),
            ...AppAccentColor.values.map(
              (color) => _AccentTile(
                color: color,
                selected: appearance.accentColor == color,
                onTap: () => unawaited(appearance.setAccentColor(color)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _AccentTile extends StatelessWidget {
  const _AccentTile({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AppAccentColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceSettingsService.instance;
    final preview = switch (color) {
      AppAccentColor.turquoise => const Color(0xFF20BFA9),
      AppAccentColor.blue => const Color(0xFF3B82F6),
      AppAccentColor.purple => const Color(0xFF8B5CF6),
      AppAccentColor.orange => const Color(0xFFF59E0B),
    };
    final label = switch (color) {
      AppAccentColor.turquoise => 'Turquesa',
      AppAccentColor.blue => 'Azul',
      AppAccentColor.purple => 'Roxo',
      AppAccentColor.orange => 'Laranja',
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: preview, shape: BoxShape.circle),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: appearance.seedColor)
            : const Icon(Icons.circle_outlined),
      ),
    );
  }
}
