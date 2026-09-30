import 'package:flutter/material.dart';

import '../models/monitor_ai_pip_status.dart';

class MapAiStatusOverlay extends StatelessWidget {
  const MapAiStatusOverlay({
    super.key,
    required this.status,
  });

  final MonitorAiPipStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _tone(scheme);

    return IgnorePointer(
      child: Tooltip(
        message: status.detail?.trim().isNotEmpty == true
            ? '${status.label}\n${status.detail!.trim()}'
            : status.label,
        child: Semantics(
          label: status.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: tone.withValues(alpha: 0.88)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 11, color: tone),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.2,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (status.state) {
        MonitorAiPipState.active => Icons.psychology_alt_rounded,
        MonitorAiPipState.disabled => Icons.power_settings_new_rounded,
        MonitorAiPipState.waitingFrames => Icons.hourglass_top_rounded,
        MonitorAiPipState.noFrames => Icons.videocam_off_outlined,
        MonitorAiPipState.cameraUnavailable => Icons.no_photography_outlined,
        MonitorAiPipState.connectionLost => Icons.wifi_off_rounded,
        MonitorAiPipState.analyzing => Icons.manage_search_rounded,
        MonitorAiPipState.possibleError => Icons.error_outline_rounded,
      };

  Color _tone(ColorScheme scheme) => switch (status.state) {
        MonitorAiPipState.active => Colors.lightGreenAccent,
        MonitorAiPipState.disabled => scheme.outline,
        MonitorAiPipState.waitingFrames => Colors.lightBlueAccent,
        MonitorAiPipState.noFrames => Colors.orangeAccent,
        MonitorAiPipState.cameraUnavailable => scheme.error,
        MonitorAiPipState.connectionLost => Colors.orangeAccent,
        MonitorAiPipState.analyzing => Colors.cyanAccent,
        MonitorAiPipState.possibleError => scheme.error,
      };
}
