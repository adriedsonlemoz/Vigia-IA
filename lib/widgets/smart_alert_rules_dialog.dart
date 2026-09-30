import 'package:flutter/material.dart';

import '../models/smart_alert_rules.dart';

Future<SmartAlertRules?> showSmartAlertRulesDialog({
  required BuildContext context,
  required SmartAlertRules initialRules,
}) {
  var rules = initialRules;

  return showDialog<SmartAlertRules>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget delaySlider({
            required String title,
            required Duration value,
            required ValueChanged<Duration> onChanged,
          }) {
            final seconds = value.inMilliseconds / 1000;
            final label = seconds == 0
                ? 'Sem atraso extra'
                : '${seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1)} s';
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title)),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: seconds.clamp(0, 10).toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 20,
                    onChanged: rules.enabled
                        ? (value) => setDialogState(
                              () => onChanged(
                                Duration(milliseconds: (value * 1000).round()),
                              ),
                            )
                        : null,
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Regras inteligentes'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rules.enabled,
                      onChanged: (value) => setDialogState(
                        () => rules = rules.copyWith(enabled: value),
                      ),
                      title: const Text('Ativar regras inteligentes'),
                      subtitle: const Text(
                        'Define um tempo mínimo antes do alerta e pode '
                        'evitar avisos de automóveis que estejam parados.',
                      ),
                    ),
                    delaySlider(
                      title: 'Pessoa',
                      value: rules.personMinimumPresence,
                      onChanged: (value) => rules = rules.copyWith(
                        personMinimumPresence: value,
                      ),
                    ),
                    delaySlider(
                      title: 'Automóveis',
                      value: rules.vehicleMinimumPresence,
                      onChanged: (value) => rules = rules.copyWith(
                        vehicleMinimumPresence: value,
                      ),
                    ),
                    delaySlider(
                      title: 'Animais',
                      value: rules.animalMinimumPresence,
                      onChanged: (value) => rules = rules.copyWith(
                        animalMinimumPresence: value,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rules.ignoreStationaryVehicles,
                      onChanged: rules.enabled
                          ? (value) => setDialogState(
                                () => rules = rules.copyWith(
                                  ignoreStationaryVehicles: value,
                                ),
                              )
                          : null,
                      title: const Text('Ignorar automóveis parados'),
                      subtitle: const Text(
                        'Só libera o alerta quando o automóvel mostrar '
                        'movimento real na área detectada.',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mesmo com essas regras, o controle anti-repetição continua ativo para evitar avisos duplicados.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, rules),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );
}

String smartAlertRulesSummary(SmartAlertRules rules) {
  if (!rules.enabled) return 'Desativadas';
  final person = _formatDelay(rules.personMinimumPresence);
  final vehicle = _formatDelay(rules.vehicleMinimumPresence);
  final animal = _formatDelay(rules.animalMinimumPresence);
  final parked = rules.ignoreStationaryVehicles ? ' · parado ignorado' : '';
  return 'Pessoas $person · Automóveis $vehicle · Animais $animal$parked';
}

String _formatDelay(Duration duration) {
  if (duration == Duration.zero) return 'sem atraso';
  final seconds = duration.inMilliseconds / 1000;
  final digits = seconds % 1 == 0 ? 0 : 1;
  return '${seconds.toStringAsFixed(digits)}s';
}
