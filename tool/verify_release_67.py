#!/usr/bin/env python3
"""Gates estruturais complementares; não substitui Flutter analyze/test."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")
def require(path, *tokens):
    source = read(path)
    for token in tokens:
        if token not in source:
            raise SystemExit(f"{path}: contrato ausente: {token}")

require("lib/services/object_detection_worker.dart", "runtime.input.bytes.buffer",
        "lastInferenceDurationMicroseconds", "tensorTransferMs", "shouldUseLightModel")
require("lib/services/object_detection_runtime.dart", "XNNPackDelegate", "options.delete()", "delegate?.delete()")
require("lib/services/detector_input_buffer.dart", "DetectorImageTransform.fit", "Float32List", "rgb.length")
require("lib/controllers/monitor_controller.dart", "_cadence.observe(now)", "immediateKeys:",
        "urgentFrameMaxAge", "freshForSpeech ?", "observationWindow: observationWindow")
if read("lib/controllers/monitor_controller.dart").count("AnalysisBudgetPolicy.allowOptionalDetailScan(") != 2:
    raise SystemExit("Recortes de movimento e detalhe precisam compartilhar orçamento.")
require("lib/services/monitor_lan_stream_service.dart", "connectedViewers == 0 ? 0.5")
require("lib/services/shared_local_camera_service.dart", "AnimatedBuilder(", "await _detachPreview()",
        "generation == _generation", "endOfFrame.timeout")
for filename in ("MainActivity.kt", "AlertAudioPlayer.kt", "MonitorSystemUi.kt"):
    source = root / "tool/android" / filename
    target = root / "android/app/src/main/kotlin/com/vigiaia/app" / filename
    if source.read_bytes() != target.read_bytes():
        raise SystemExit(f"Espelho Android divergente: {filename}")
    require("tool/bootstrap_android.sh", filename)
require("tool/android/AlertAudioPlayer.kt", "USAGE_MEDIA", "prepareAsync()", "requestAudioFocus",
        "setOnErrorListener", "expired_before_start", 'finish(request, false, "failed")', '"started"', '"mediaVolume"')
if "prepare()" in read("tool/android/AlertAudioPlayer.kt"):
    raise SystemExit("Player não pode preparar áudio sincronamente.")
require("lib/services/alert_voice_service.dart", "_pending", "_generation", "_speech.speakMessage",
        "spokenFrameMaxAge", "tts_requested")
require("lib/screens/monitor_screen.dart", "PopScope<void>", "_fullscreen ? null : AppBar",
        "Tela inteira horizontal", "_fullscreen ? _buildFullscreen(context)")
require("lib/screens/monitor_screen_fullscreen.dart", "DeviceOrientation.landscapeLeft",
        "DeviceOrientation.landscapeRight", "Duration(seconds: 4)", "Sair da tela inteira")
require("tool/android/MonitorSystemUi.kt", "hide(WindowInsets.Type.systemBars())",
        "show(WindowInsets.Type.systemBars())")
require("lib/services/performance_telemetry_service.dart", "'schemaVersion': 2", "'audioDiagnostics'",
        "'alertEvents'", "'tensorTransferMs'", "summaryScope")
for name in ("detector_input_buffer", "frame_converter", "detection_cadence_policy", "alert_voice_service"):
    require(f"test/{name}_test.dart", "test(")
require("README.md", "Evolução 1.0.67")
require("ARCHITECTURE.md", "Evolução 1.0.67")
print("Contratos de IA, áudio, câmera e tela inteira 1.0.67 verificados.")
