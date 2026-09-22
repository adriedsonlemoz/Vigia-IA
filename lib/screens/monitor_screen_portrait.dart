part of 'monitor_screen.dart';

extension _MonitorPortraitLayout on _MonitorScreenState {
  Widget _buildPortrait(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final status = _controller.sourceStatus;
        final secondary = _secondaryController;
        final bikeSnapshot = _effectiveBikeSnapshot;
        final cameraHeight = bikeSnapshot == null
            ? (constraints.maxHeight * 0.37).clamp(220.0, 350.0).toDouble()
            : (constraints.maxHeight * 0.29).clamp(180.0, 280.0).toDouble();
        return ColoredBox(
          color: scheme.surface,
          child: Column(
            children: [
              if (bikeSnapshot != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: BikeRideHud(snapshot: bikeSnapshot),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: secondary == null
                    ? _DeviceStatusStrip(
                        localDevice: _controller.localDeviceTelemetry,
                        remoteStatus: _controller.remotePhoneStatus,
                        sourceType: _controller.sourceConfig.type,
                        sourceStatus: status,
                        receiverActive:
                            !_controller.initializing &&
                            _controller.error == null,
                        networkLatencyMs:
                            _controller.sessionStatus.networkLatencyMs,
                        onTap: () => unawaited(_showSessionStatus()),
                        embedded: true,
                      )
                    : _buildDeviceStrip(
                        status: status,
                        secondary: secondary,
                        embedded: true,
                      ),
              ),
              const SizedBox(height: 8),
              _buildPortraitModeBar(context),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  height: cameraHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.34),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildAdaptiveCameraStage(
                    context,
                    portraitEmbedded: true,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              _buildControlDock(context),
              const SizedBox(height: 7),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildDetectionPanel(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortraitModeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: _PortraitModeButton(
              icon: Icons.videocam_outlined,
              label: 'Ao vivo',
              active: true,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _PortraitModeButton(
              icon: Icons.psychology_alt_outlined,
              label: 'IA ativa',
              active: !_controller.initializing,
              onTap: () => unawaited(_showObjectFilter()),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _PortraitModeButton(
              icon: Icons.bar_chart_rounded,
              label: 'Painel',
              active: false,
              onTap: () => unawaited(_showSessionStatus()),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _PortraitModeButton(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              active: false,
              onTap: () =>
                  unawaited(_openStandardScreen(const SettingsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitModeButton extends StatelessWidget {
  const _PortraitModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: active
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.62)
                  : scheme.outline.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
