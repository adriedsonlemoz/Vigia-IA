import '../core/video_source_status.dart';
import '../models/monitor_ai_pip_status.dart';

class MonitorAiStatusResolver {
  const MonitorAiStatusResolver._();

  static MonitorAiPipStatus resolve({
    required bool aiEnabled,
    required bool detectorReady,
    required bool initializing,
    required bool processing,
    required VideoSourceState sourceState,
    required bool networkSource,
    required DateTime? lastFrameAt,
    required Duration expectedFrameInterval,
    bool possibleAiError = false,
    String? detail,
    DateTime? now,
  }) {
    if (sourceState == VideoSourceState.error) {
      return MonitorAiPipStatus(
        state: networkSource
            ? MonitorAiPipState.connectionLost
            : MonitorAiPipState.cameraUnavailable,
        detail: detail,
      );
    }

    if (sourceState == VideoSourceState.reconnecting) {
      return MonitorAiPipStatus(
        state: MonitorAiPipState.connectionLost,
        detail: detail,
      );
    }

    if (possibleAiError) {
      return MonitorAiPipStatus(
        state: MonitorAiPipState.possibleError,
        detail: detail,
      );
    }

    if (initializing || sourceState == VideoSourceState.connecting) {
      return const MonitorAiPipStatus(
        state: MonitorAiPipState.waitingFrames,
      );
    }

    if (!aiEnabled ||
        sourceState == VideoSourceState.idle ||
        sourceState == VideoSourceState.stopped) {
      return const MonitorAiPipStatus(
        state: MonitorAiPipState.disabled,
      );
    }

    if (!detectorReady) {
      return MonitorAiPipStatus(
        state: MonitorAiPipState.possibleError,
        detail: detail,
      );
    }

    // Esta checagem vem depois de aiEnabled/detectorReady de propósito:
    // a interface nunca pode dizer "Analisando" quando a IA está desligada.
    if (processing) {
      return const MonitorAiPipStatus(
        state: MonitorAiPipState.analyzing,
      );
    }

    if (lastFrameAt == null) {
      return const MonitorAiPipStatus(
        state: MonitorAiPipState.waitingFrames,
      );
    }

    final staleAfter = Duration(
      milliseconds: (expectedFrameInterval.inMilliseconds * 4)
          .clamp(4000, 8000)
          .toInt(),
    );
    final current = now ?? DateTime.now();
    final age = current.difference(lastFrameAt);
    if (age.isNegative || age > staleAfter) {
      return const MonitorAiPipStatus(
        state: MonitorAiPipState.noFrames,
      );
    }

    return const MonitorAiPipStatus(
      state: MonitorAiPipState.active,
    );
  }
}
