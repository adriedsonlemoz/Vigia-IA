#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "ERRO DE VERIFICACAO: $*" >&2
  exit 1
}

python3 tool/check_version_sync.py || fail 'Metadados de versao nao estao sincronizados.'

grep -q '^name: vigiaia$' pubspec.yaml || fail 'Nome tecnico Dart esperado vigiaia nao encontrado.'
grep -q '^version: 1\.0\.77+77$' pubspec.yaml || fail 'Versao esperada 1.0.77+77 nao encontrada.'
if grep -q "import 'dart:ui';" lib/main.dart; then
  fail 'Import dart:ui redundante reapareceu em lib/main.dart.'
fi
grep -q 'required this.sourceConfig' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController deve usar initializing formal para sourceConfig.'

if grep -q 'separatorBuilder: (_, __)' lib/screens/events_screen.dart lib/screens/events_screen_components.dart; then
  fail 'Placeholder duplo desnecessario reapareceu em EventsScreen.'
fi
if grep -q 'errorBuilder: (_, __, ___)' lib/screens/events_screen.dart lib/screens/events_screen_components.dart; then
  fail 'Placeholders multiplos desnecessarios reapareceram em EventsScreen.'
fi
if grep -q "import 'dart:typed_data';" lib/services/event_history_service.dart; then
  fail 'Import dart:typed_data redundante reapareceu no historico de eventos.'
fi
grep -q 'SmartAlertRuleEngine(' lib/services/smart_alert_rule_engine.dart \
  || fail 'Construtor do SmartAlertRuleEngine nao encontrado.'
grep -q 'this._rules' lib/services/smart_alert_rule_engine.dart \
  || fail 'SmartAlertRuleEngine deve usar initializing formal para _rules.'
grep -q '^  flutter_litert:' pubspec.yaml || fail 'flutter_litert nao esta configurado no pubspec.yaml.'
grep -q '^  path_provider:' pubspec.yaml || fail 'path_provider nao esta configurado para a Central de Erros.'
if grep -q '^  tflite_flutter:' pubspec.yaml; then
  fail 'Dependencia tflite_flutter antiga ainda presente.'
fi

grep -q "package:flutter_litert/native.dart" lib/services/object_detection_service.dart \
  || fail 'ObjectDetectionService nao esta usando flutter_litert.'
grep -q "flutter_litert/native.dart' hide Detection" lib/services/object_detection_service.dart \
  || fail 'Import do flutter_litert deve ocultar Detection para evitar conflito com o modelo local.'
grep -q "efficientdet_lite0.tflite" lib/services/object_detection_service.dart \
  || fail 'Detector principal EfficientDet-Lite0 nao esta configurado.'
grep -q "ssd_mobilenet_v1.tflite" lib/services/object_detection_service.dart \
  || fail 'Fallback SSD MobileNet V1 nao esta configurado.'
grep -q 'TensorType.uint8' lib/services/object_detection_service.dart lib/services/object_detection_worker.dart \
  || fail 'Pre-processamento uint8 do modelo SSD nao foi encontrado.'

grep -q 'SettingsScreen' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Engrenagem de configuracoes nao esta acessivel pelo monitoramento.'
grep -q 'ErrorLogService.instance' lib/main.dart \
  || fail 'Captura global de erros nao foi inicializada.'
grep -q 'Future<void> retry()' lib/controllers/monitor_controller.dart \
  || fail 'Rotina de recuperacao do monitoramento nao foi encontrada.'
grep -q 'MotionDetectionService' lib/controllers/monitor_controller.dart \
  || fail 'Filtro de movimento nao esta ligado ao MonitorController.'
if grep -q 'if (!sameGrid || previous == null)' lib/services/motion_detection_service.dart; then
  fail 'Checagem de null redundante reapareceu no filtro de movimento.'
fi
grep -q 'ObjectFilterPolicy.apply' lib/controllers/monitor_controller.dart \
  || fail 'Filtro de classes nao esta ligado ao pipeline de deteccao.'

grep -q 'MonitoringZoneService.boundingZone' lib/controllers/monitor_controller.dart \
  || fail 'Uniao das multiplas Areas de Monitoramento nao esta ligada ao pipeline.'
grep -q 'MonitoringZoneService.crop' lib/controllers/monitor_controller.dart \
  || fail 'Areas de monitoramento nao estao recortando frames antes da IA.'
grep -q 'MonitoringZoneService.filterToZones' lib/controllers/monitor_controller.dart \
  || fail 'Deteccoes nao estao sendo filtradas pelas zonas ativas.'
grep -q 'MonitoringZoneOverlay' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Editor visual das Areas de Monitoramento nao foi encontrado.'
grep -q 'updateMonitoringZone' lib/controllers/monitor_controller.dart \
  || fail 'Atualizacao das Areas de Monitoramento nao esta ligada ao controller.'
[[ -f lib/models/monitoring_zone.dart ]] \
  || fail 'Modelo MonitoringZone nao encontrado.'
[[ -f lib/services/monitoring_zone_service.dart ]] \
  || fail 'Servico MonitoringZoneService nao encontrado.'
[[ -f test/monitoring_zone_service_test.dart ]] \
  || fail 'Testes da Area de Monitoramento nao encontrados.'
grep -q 'setAlertLabels' lib/controllers/monitor_controller.dart \
  || fail 'Troca de filtro em tempo de execucao nao foi encontrada.'
grep -q 'ObjectFilterCatalog.recommended' lib/models/video_source_config.dart \
  || fail 'Preset recomendado de objetos nao esta configurado.'
grep -q 'showObjectFilterDialog' lib/screens/home_screen.dart \
  || fail 'Filtro de objetos nao esta disponivel na Home.'
grep -q 'showObjectFilterDialog' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Filtro de objetos nao esta disponivel durante o monitoramento.'
[[ -f lib/widgets/object_filter_dialog.dart ]] \
  || fail 'Dialogo de filtro de objetos nao encontrado.'
[[ -f test/object_filter_policy_test.dart ]] \
  || fail 'Testes do filtro de objetos nao encontrados.'
grep -q 'motionResult.isBoxMoving' lib/controllers/monitor_controller.dart \
  || fail 'Deteccoes nao estao sendo filtradas pela regiao em movimento.'

[[ -f lib/models/smart_alert_rules.dart ]] \
  || fail 'Modelo SmartAlertRules nao encontrado.'
[[ -f lib/services/smart_alert_rule_engine.dart ]] \
  || fail 'SmartAlertRuleEngine nao encontrado.'
[[ -f lib/widgets/smart_alert_rules_dialog.dart ]] \
  || fail 'Dialogo de Regras Inteligentes nao encontrado.'
[[ -f test/smart_alert_rule_engine_test.dart ]] \
  || fail 'Testes das Regras Inteligentes nao encontrados.'
grep -q 'limite exato de ausencia preserva a mesma presenca' test/smart_alert_rule_engine_test.dart \
  || fail 'Teste de regressao do limite exato de absenceReset nao encontrado.'
grep -q 'SmartAlertRuleEngine' lib/controllers/monitor_controller.dart \
  || fail 'Regras Inteligentes nao estao ligadas ao MonitorController.'
grep -q 'ruleEligibleLabels' lib/controllers/monitor_controller.dart \
  || fail 'Regras Inteligentes nao estao antes do anti-repeticao.'
grep -q 'showSmartAlertRulesDialog' lib/screens/home_screen.dart \
  || fail 'Regras Inteligentes nao estao configuraveis na Home.'
grep -q 'showSmartAlertRulesDialog' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Regras Inteligentes nao estao configuraveis durante o monitoramento.'
grep -q 'ignoreStationaryVehicles' lib/models/smart_alert_rules.dart \
  || fail 'Regra para veiculos parados nao foi encontrada.'
if grep -q 'now.difference(previousLastSeen) >= absenceReset' lib/services/smart_alert_rule_engine.dart; then
  fail 'Limite exato de ausencia nao pode reiniciar uma presenca ainda observada.'
fi
if grep -q 'now.difference(entry.value) >= absenceReset' lib/services/smart_alert_rule_engine.dart; then
  fail 'Expiracao no limite exato de ausencia pode quebrar o tempo minimo de permanencia.'
fi

[[ -f lib/models/monitor_event.dart ]] \
  || fail 'Modelo persistente de eventos nao encontrado.'
[[ -f lib/services/event_history_service.dart ]] \
  || fail 'Servico de historico de eventos nao encontrado.'
[[ -f lib/screens/events_screen.dart ]] \
  || fail 'Tela de historico de eventos nao encontrada.'
[[ -f lib/screens/events_screen_components.dart ]] \
  || fail 'Componentes extraidos do historico nao encontrados.'
[[ -f lib/widgets/detection_overlay.dart ]] \
  || fail 'Overlay de caixas de deteccao nao encontrado.'
[[ -f test/monitor_event_test.dart ]] \
  || fail 'Teste de serializacao de eventos nao encontrado.'
grep -q '_recordConfirmedEvents' lib/controllers/monitor_controller.dart \
  || fail 'Eventos confirmados nao estao ligados ao anti-repeticao.'
grep -q 'EventHistoryService.instance' lib/controllers/monitor_controller.dart \
  || fail 'Historico nao esta ligado ao MonitorController.'
grep -q 'DetectionOverlay' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Caixas de deteccao nao estao ligadas ao preview.'
grep -q 'EventsScreen' lib/screens/home_screen.dart \
  || fail 'Historico de eventos nao esta acessivel pela Home.'
grep -q 'maxEvents = 200' lib/services/event_history_service.dart \
  || fail 'Limite preventivo do historico nao foi encontrado.'
grep -q 'repeatWhilePresent: false' lib/controllers/monitor_controller.dart \
  || fail 'TTS ainda pode repetir durante o mesmo evento.'
grep -q 'motionConfirmationHits' lib/models/video_source_config.dart \
  || fail 'Confirmacao de movimento nao esta configurada.'
grep -q 'CameraPreview(active, key: ObjectKey(active))' lib/services/shared_local_camera_service.dart \
  || fail 'Preview compartilhado deve deixar CameraPreview controlar a proporcao nativa.'
grep -q '_waitForProcessing' lib/controllers/monitor_controller.dart \
  || fail 'Encerramento nao aguarda inferencia em andamento.'
[[ -f lib/services/motion_detection_service.dart ]] \
  || fail 'Servico de deteccao de movimento nao encontrado.'
[[ -f test/motion_detection_service_test.dart ]] \
  || fail 'Testes do filtro de movimento nao encontrados.'

if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  fail 'Teste padrao MyApp reapareceu.'
fi

for MODEL_FILE in assets/models/efficientdet_lite0.tflite assets/models/ssd_mobilenet_v1.tflite; do
  [[ -f "$MODEL_FILE" ]] || fail "Modelo .tflite nao encontrado: $MODEL_FILE"
  MODEL_SIZE=$(wc -c < "$MODEL_FILE")
  if (( MODEL_SIZE < 1048576 )); then
    if grep -qx 'MODEL_DOWNLOADED_IN_CI' "$MODEL_FILE"; then
      echo "Modelo em modo fonte: $MODEL_FILE sera baixado por tool/fetch_model.sh antes do build."
    else
      fail "Modelo .tflite parece incompleto: $MODEL_FILE"
    fi
  fi
done


# Recursos 1.0.14
[[ -f lib/services/clip_recorder_service.dart ]] || fail 'ClipRecorderService nao encontrado.'
grep -q 'ClipRecorderService' lib/controllers/monitor_controller.dart \
  || fail 'Gravacao automatica de clipes nao esta ligada ao controller.'
grep -q 'attachClip' lib/services/event_history_service.dart \
  || fail 'Historico nao associa clipes aos eventos.'
grep -q 'clipPath' lib/models/monitor_event.dart \
  || fail 'MonitorEvent nao persiste clipPath.'

[[ -f lib/models/monitor_schedule.dart ]] || fail 'Modelo MonitorSchedule nao encontrado.'
[[ -f test/monitor_schedule_test.dart ]] || fail 'Testes do agendamento nao encontrados.'
grep -q 'MonitorSchedule' lib/controllers/monitor_controller.dart \
  || fail 'Agendamento nao esta ligado ao controller.'
grep -q '_applyScheduleState' lib/controllers/monitor_controller.dart \
  || fail 'Aplicacao automatica do agendamento nao foi encontrada.'

[[ -f lib/services/app_settings_service.dart ]] || fail 'AppSettingsService nao encontrado.'
grep -q 'PersistedMonitorProfile' lib/models/video_source_config.dart \
  || fail 'Perfil persistente completo nao encontrado.'
grep -q 'AppSettingsService' lib/screens/home_screen.dart \
  || fail 'Home nao carrega/salva configuracoes persistentes.'
grep -q '_persistRuntime' lib/controllers/monitor_controller.dart \
  || fail 'Alteracoes em tempo de execucao nao sao persistidas.'

[[ -f lib/models/tracked_detection.dart ]] || fail 'Modelo de rastreamento nao encontrado.'
[[ -f lib/services/object_tracker.dart ]] || fail 'ObjectTracker nao encontrado.'
[[ -f test/object_tracker_test.dart ]] || fail 'Testes do rastreamento nao encontrados.'
grep -q 'ObjectTracker' lib/controllers/monitor_controller.dart \
  || fail 'Rastreamento individual nao esta ligado ao controller.'
grep -q 'trackId' lib/widgets/detection_overlay.dart \
  || fail 'IDs de rastreamento nao aparecem no overlay.'
grep -q 'ZoneTransitionType.entered' lib/controllers/monitor_controller*.dart \
  || fail 'Deteccao de entrada por zona nao encontrada.'
grep -q 'ZoneTransitionType.exited' lib/services/object_tracker.dart \
  || fail 'Deteccao de saida por zona nao encontrada.'
grep -q 'enum MonitorEventType { alert, entered, exited, cameraObstructed, cameraMoved }' lib/models/monitor_event.dart \
  || fail 'Historico nao suporta alerta, entrada, saida e integridade da camera.'

grep -q 'take(6)' lib/controllers/monitor_controller.dart \
  || fail 'Limite preventivo de 6 zonas nao foi encontrado.'
grep -q 'monitoringZones' lib/models/video_source_config.dart \
  || fail 'Multiplas zonas nao sao persistidas em MonitorSettings.'

grep -q 'BackgroundMonitorService' lib/controllers/monitor_controller.dart \
  || fail 'Servico Flutter de segundo plano nao esta ligado ao controller.'
[[ -f lib/services/background_monitor_service.dart ]] \
  || fail 'BackgroundMonitorService Flutter nao encontrado.'
[[ -f tool/android/MainActivity.kt ]] || fail 'MainActivity nativa de apoio nao encontrada.'
[[ -f tool/android/MonitoringForegroundService.kt ]] \
  || fail 'MonitoringForegroundService nativo nao encontrado.'
[[ -f android/app/src/main/kotlin/com/vigiaia/app/MonitoringForegroundService.kt ]] \
  || fail 'MonitoringForegroundService nao foi aplicado ao projeto Android.'
grep -q 'FOREGROUND_SERVICE_CAMERA' tool/AndroidManifest.xml \
  || fail 'Permissao FOREGROUND_SERVICE_CAMERA nao esta no Manifest fonte.'
grep -q 'MonitoringForegroundService' tool/AndroidManifest.xml \
  || fail 'Foreground Service nao esta declarado no Manifest fonte.'
grep -q 'MonitoringForegroundService.kt' tool/bootstrap_android.sh \
  || fail 'Bootstrap Android nao restaura o Foreground Service.'
grep -q 'MainActivity.kt' tool/bootstrap_android.sh \
  || fail 'Bootstrap Android nao restaura a MainActivity customizada.'

[[ -f android/app/build.gradle.kts ]] || fail 'Projeto Android nao foi criado.'
grep -q 'minSdk = 29' android/app/build.gradle.kts || fail 'minSdk Android nao esta em 29.'
grep -q 'JavaVersion.VERSION_17' android/app/build.gradle.kts || fail 'Java 17 nao esta configurado no app Android.'


# Regressões e interface 1.0.15
grep -q 'final ObjectTracker _tracker;' lib/controllers/monitor_controller.dart \
  || fail 'ObjectTracker deve permanecer final para evitar prefer_final_fields.'
if grep -q "import 'dart:typed_data';" lib/services/clip_recorder_service.dart; then
  fail 'Import dart:typed_data redundante reapareceu no ClipRecorderService.'
fi
grep -q 'DeviceOrientation.landscapeLeft' lib/main.dart \
  || fail 'Suporte explicito a paisagem nao encontrado.'
grep -q 'DeviceOrientation.landscapeRight' lib/main.dart \
  || fail 'Suporte aos dois sentidos de paisagem nao encontrado.'
if grep -q '_MonitorMenuAction' lib/screens/monitor_screen.dart; then
  fail 'Menu suspenso legado do monitor reapareceu.'
fi
grep -q "label: 'Áreas'" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Acao direta de Areas nao encontrada no monitor.'
grep -q "label: 'Objetos'" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Acao direta de Objetos nao encontrada no monitor.'
grep -q '_buildLandscape' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Layout paisagem do monitor nao encontrado.'
grep -q "Text('Diagnóstico'" lib/screens/error_center_screen.dart \
  || fail 'Tela visual de Diagnostico nao encontrada.'
[[ -f lib/screens/error_center_screen_components.dart ]] || fail 'Componentes extraidos do Diagnostico nao encontrados.'
grep -q '_HistoryCard' lib/screens/events_screen.dart lib/screens/events_screen_components.dart \
  || fail 'Cards do novo Historico nao foram encontrados.'

# Interface e informacoes 1.0.17
[[ -f lib/screens/settings_screen.dart ]] || fail 'Tela de Ajustes nao encontrada.'
[[ -f lib/screens/app_info_screen.dart ]] || fail 'Tela Sobre/Mudancas/Doacoes nao encontrada.'
[[ -f lib/widgets/main_navigation_bar.dart ]] || fail 'Navegacao principal nao encontrada.'
grep -q 'adriedson@outlook.com' lib/core/app_metadata.dart \
  || fail 'Chave PIX esperada nao encontrada nos metadados do app.'
grep -q 'COPIAR CHAVE PIX' lib/screens/app_info_screen*.dart \
  || fail 'Botao para copiar PIX nao encontrado.'
grep -q '_detectionsExpanded' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Painel recolhivel de deteccoes nao encontrado.'
if grep -q 'Arraste para desenhar a área' lib/screens/monitor_screen.dart; then
  fail 'Instrucao duplicada de desenho de area reapareceu no MonitorScreen.'
fi

# Workflow e empacotamento do projeto-fonte 1.0.16
[[ -f .github/workflows/android-apk.yml ]] \
  || fail 'Workflow Android APK nao encontrado em .github/workflows.'
grep -q 'workflow_dispatch:' .github/workflows/android-apk.yml \
  || fail 'Workflow Android APK precisa expor workflow_dispatch para execucao manual.'
grep -q 'push:' .github/workflows/android-apk.yml \
  || fail 'Workflow Android APK precisa reagir a push.'
[[ -f tool/package_source.sh ]] \
  || fail 'Empacotador seguro tool/package_source.sh nao encontrado.'



# Correcao de build 1.0.19
if grep -q 'VideoSourceState.ready' lib/sources/remote_phone_camera_source.dart; then
  fail 'Estado inexistente VideoSourceState.ready reapareceu na camera remota.'
fi
grep -q 'VideoSourceState.streaming' lib/sources/remote_phone_camera_source.dart \
  || fail 'Camera remota deve reportar VideoSourceState.streaming quando online.'
grep -q 'grid.isEmpty ? 0.0' lib/services/camera_integrity_service.dart \
  || fail 'Brilho da integridade da camera deve permanecer tipado como double.'
grep -q 'previous == null ? 0.0' lib/services/camera_integrity_service.dart \
  || fail 'Diferenca de cena deve permanecer tipada como double.'
if grep -q 'RadioListTile' lib/screens/presets_screen.dart; then
  fail 'API RadioListTile depreciada reapareceu na tela de presets.'
fi

# Correcao de rastreamento 1.0.20
grep -q 'bool hasVelocity = false;' lib/services/object_tracker.dart \
  || fail 'ObjectTracker perdeu o estado de inicializacao da velocidade.'
grep -q 'if (!hasVelocity)' lib/services/object_tracker.dart \
  || fail 'Primeira medicao de velocidade voltou a ser amortecida contra zero.'
grep -q 'velocityX = instantX;' lib/services/object_tracker.dart \
  || fail 'Velocidade X inicial nao usa a primeira medicao real.'
grep -q 'velocityY = instantY;' lib/services/object_tracker.dart \
  || fail 'Velocidade Y inicial nao usa a primeira medicao real.'

# Evolucao funcional 1.0.18
[[ -f app_identity.json ]] || fail 'Arquivo central de identidade futura nao encontrado.'
grep -q '"displayName": "Vigia IA"' app_identity.json \
  || fail 'Nome atual nao esta registrado em app_identity.json.'
grep -q "static const String version = '1.0.77';" lib/core/app_metadata.dart \
  || fail 'AppMetadata nao esta em 1.0.77.'
grep -q 'static const int build = 77;' lib/core/app_metadata.dart \
  || fail 'Build de AppMetadata nao esta em 77.'
grep -q "version: '1.0.77'" lib/screens/app_info_screen*.dart \
  || fail 'Tela Mudancas nao marca a versao 1.0.77.'

[[ -f lib/models/alert_preferences.dart ]] || fail 'Preferencias configuraveis de alerta nao encontradas.'
[[ -f lib/screens/alerts_clips_screen.dart ]] || fail 'Tela Alertas e clipes nao encontrada.'
grep -q 'ClipFormatPreference.mp4WithGifFallback' lib/models/video_source_config.dart \
  || fail 'Preferencia MP4 com fallback GIF nao encontrada.'
grep -q 'encodeMp4' lib/services/clip_recorder_service.dart \
  || fail 'ClipRecorderService nao tenta gerar MP4.'
grep -q 'MediaMuxer' tool/android/MainActivity.kt \
  || fail 'Encoder MP4 nativo via MediaMuxer nao encontrado.'
grep -q "endsWith('.mp4')" lib/screens/events_screen.dart lib/screens/events_screen_components.dart \
  || fail 'Historico nao reconhece clipes MP4.'
grep -q 'VlcPlayerController' lib/screens/events_screen.dart lib/screens/events_screen_components.dart \
  || fail 'Reproducao local de MP4 no Historico nao encontrada.'
grep -q 'requestNotificationPermission' lib/screens/alerts_clips_screen.dart \
  || fail 'Permissao de notificacoes nao pode ser conferida na interface.'
grep -q 'byObjectAndArea' lib/models/alert_preferences.dart \
  || fail 'Frases por objeto e area nao sao persistidas.'
grep -q 'DropdownButtonFormField<String>' lib/screens/alerts_clips_screen.dart \
  || fail 'Frases por objeto/area ainda nao usam seletores intuitivos.'

[[ -f lib/services/remote_camera_server_service.dart ]] || fail 'Modo Camera local nao encontrado.'
[[ -f lib/sources/remote_phone_camera_source.dart ]] || fail 'Fonte de celular remoto nao encontrada.'
[[ -f lib/screens/camera_mode_screen.dart ]] || fail 'Tela Modo Camera nao encontrada.'
[[ -f lib/screens/multi_camera_screen.dart ]] || fail 'Central multicamera nao encontrada.'
[[ -f lib/services/camera_registry_service.dart ]] || fail 'Registro de cameras nao encontrado.'
grep -q 'InternetAddress.anyIPv4' lib/services/remote_camera_server_service.dart \
  || fail 'Servidor de camera local nao esta limitado ao fluxo de rede local esperado.'
grep -q 'VideoSourceType.remotePhone' lib/controllers/monitor_controller.dart \
  || fail 'Celular remoto nao esta ligado ao pipeline principal.'
grep -q 'protectSecret' lib/services/camera_registry_service.dart \
  || fail 'Central multicamera nao protege enderecos/segredos persistidos.'

[[ -f lib/services/camera_integrity_service.dart ]] || fail 'Deteccao de obstrucao/deslocamento nao encontrada.'
grep -q 'CameraIntegrityService' lib/controllers/monitor_controller.dart \
  || fail 'Integridade da camera nao esta ligada ao pipeline.'
grep -q 'cameraObstructed' lib/models/monitor_event.dart \
  || fail 'Historico nao suporta evento de camera obstruida.'
grep -q 'cameraMoved' lib/models/monitor_event.dart \
  || fail 'Historico nao suporta evento de camera deslocada.'

[[ -f lib/screens/statistics_screen.dart ]] || fail 'Tela Estatisticas nao encontrada.'
[[ -f lib/services/statistics_service.dart ]] || fail 'Servico de Estatisticas nao encontrado.'
[[ -f lib/screens/storage_backup_screen.dart ]] || fail 'Tela Armazenamento e backup nao encontrada.'
[[ -f lib/services/storage_management_service.dart ]] || fail 'Gerenciamento de armazenamento nao encontrado.'
[[ -f lib/services/backup_export_service.dart ]] || fail 'Backup/exportacao nao encontrado.'
grep -q 'exportPortableProfile' lib/services/backup_export_service.dart \
  || fail 'Backup nao usa perfil portatil sem segredos.'
grep -q "source\['rtspUrl'\] = null" lib/services/app_settings_service.dart \
  || fail 'Persistencia segura nao remove RTSP em texto puro antes de gravar.'
grep -q 'rtspSecret' lib/services/app_settings_service.dart \
  || fail 'Credencial RTSP protegida nao e persistida separadamente.'
grep -q 'Android Keystore' lib/services/native_platform_service.dart \
  || fail 'Falha do Keystore Android nao esta tratada como falha segura.'
grep -q 'AndroidKeyStore' tool/android/MainActivity.kt \
  || fail 'Android Keystore nao esta implementado no codigo nativo.'

[[ -f lib/screens/system_health_screen.dart ]] || fail 'Painel de Saude do Sistema nao encontrado.'
[[ -f lib/services/runtime_health_service.dart ]] || fail 'Estado de saude em runtime nao encontrado.'
grep -q 'systemHealth' tool/android/MainActivity.kt \
  || fail 'Coleta nativa de saude do sistema nao encontrada.'
[[ -f lib/screens/presets_screen.dart ]] || fail 'Tela de presets nao encontrada.'
[[ -f lib/services/monitoring_preset_service.dart ]] || fail 'Servico de presets nao encontrado.'
grep -q 'MonitoringPreset.away' lib/services/monitoring_preset_service.dart \
  || fail 'Preset Ausente nao encontrado.'

# Segundo plano autonomo dentro dos limites do Android
grep -q 'return START_STICKY' tool/android/MonitoringForegroundService.kt \
  || fail 'Foreground Service nao esta configurado para recuperacao sticky com heartbeat.'
[[ -f tool/android/MonitorRecoveryReceiver.kt ]] || fail 'Receiver de recuperacao nao encontrado.'
grep -q 'BOOT_COMPLETED' tool/AndroidManifest.xml \
  || fail 'Recuperacao apos boot nao esta declarada.'
grep -q 'consumeResumeRequest' lib/screens/home_screen.dart \
  || fail 'Home nao consome pedido de retomada apos boot/processo.'
grep -q 'configureRecovery' lib/services/app_settings_service.dart \
  || fail 'Estado de recuperacao nao acompanha perfil/agendamento.'

# Rastreamento e anti-repeticao por ID
grep -q '_associateGlobally' lib/services/object_tracker.dart \
  || fail 'Associacao global do rastreador nao encontrada.'
grep -q 'predictedBox' lib/services/object_tracker.dart \
  || fail 'Predicao de movimento do rastreador nao encontrada.'
grep -q "'\$groupKey#\${tracked.trackId}'" lib/controllers/monitor_controller.dart \
  || fail 'Anti-repeticao nao considera familia + trackId.'
grep -Eq 'cruzar|cruzamento' test/object_tracker_test.dart \
  || fail 'Teste de regressao para cruzamento de objetos nao encontrado.'

# Novos testes puros e documentacao
[[ -f test/alert_preferences_test.dart ]] || fail 'Teste de preferencias de alerta nao encontrado.'
[[ -f test/storage_policy_test.dart ]] || fail 'Teste de politica de armazenamento nao encontrado.'
[[ -f test/video_source_config_test.dart ]] || fail 'Teste de fonte remota/serializacao nao encontrado.'
grep -q '1.0.20' README.md || fail 'README nao documenta 1.0.20.'
grep -q '## 1.0.20' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.20.'
grep -q '1.0.20' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.20.'

# Fonte e template Android devem permanecer sincronizados.
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity do projeto Android divergiu do template preservado.'
cmp -s tool/android/MonitoringForegroundService.kt android/app/src/main/kotlin/com/vigiaia/app/MonitoringForegroundService.kt \
  || fail 'Foreground Service do Android divergiu do template preservado.'
cmp -s tool/android/MonitorRecoveryReceiver.kt android/app/src/main/kotlin/com/vigiaia/app/MonitorRecoveryReceiver.kt \
  || fail 'Receiver de recuperacao do Android divergiu do template preservado.'
cmp -s tool/AndroidManifest.xml android/app/src/main/AndroidManifest.xml \
  || fail 'AndroidManifest do projeto divergiu do template preservado.'



# Pareamento QR 1.0.23
grep -q '^  mobile_scanner: \^7.4.2$' pubspec.yaml \
  || fail 'mobile_scanner nao esta configurado para o leitor QR.'
grep -q '^  qr_flutter: \^4.1.0$' pubspec.yaml \
  || fail 'qr_flutter nao esta configurado para gerar o QR.'
if grep -q '^dev.steenbakker.mobile_scanner.useUnbundled=true$' android/gradle.properties; then
  fail 'Scanner QR nao pode depender de download em tempo de uso no modo offline.'
fi
[[ -f lib/services/remote_camera_pairing_service.dart ]] \
  || fail 'Codec de pareamento remoto nao encontrado.'
[[ -f lib/screens/phone_pairing_scanner_screen.dart ]] \
  || fail 'Tela de leitura QR nao encontrada.'
grep -q "static const String scheme = 'vigiaia';" lib/services/remote_camera_pairing_service.dart \
  || fail 'Pareamento QR perdeu o esquema proprio versionado.'
grep -q 'RemoteCameraPairingService.encode' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Camera nao gera payload QR.'
grep -q 'QrImageView' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Camera nao renderiza QR.'
grep -q 'MobileScanner(' lib/screens/phone_pairing_scanner_screen.dart \
  || fail 'Scanner QR nao usa MobileScanner.'
grep -q 'final probe = await _registry.probe(candidate);' lib/screens/multi_camera_screen.dart \
  || fail 'Central nao testa celular antes do cadastro QR.'
grep -q 'atualizado com a nova chave de sessão' lib/screens/multi_camera_screen.dart \
  || fail 'Fluxo QR nao trata atualizacao de celular ja cadastrado.'
grep -q '_isPrivateIpv4' lib/services/remote_camera_server_service.dart \
  || fail 'Servidor remoto nao prioriza IPv4 privado.'
[[ -f test/remote_camera_pairing_service_test.dart ]] \
  || fail 'Testes do pareamento QR nao encontrados.'
grep -q 'gera e lê um QR versionado' test/remote_camera_pairing_service_test.dart \
  || fail 'Round-trip do pareamento QR nao esta coberto por teste.'
grep -q '1.0.23' README.md || fail 'README nao documenta 1.0.23.'
grep -q '## 1.0.23+23' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.23.'
grep -q 'Pareamento por QR 1.0.23' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta o pareamento QR.'

# Central multicamera + estabilidade 1.0.22
grep -q 'final String? cameraId;' lib/models/monitor_event.dart \
  || fail 'MonitorEvent perdeu cameraId estavel.'
grep -q "'cameraId': cameraId" lib/models/monitor_event.dart \
  || fail 'cameraId nao esta sendo persistido no historico.'
grep -q 'cameraId: sourceConfig.cameraId' lib/controllers/monitor_controller*.dart \
  || fail 'MonitorController nao associa novos eventos ao cameraId.'
grep -q 'probeAll(' lib/services/camera_registry_service.dart \
  || fail 'Probe paralelo da Central multicamera nao encontrado.'
grep -q '_automaticRefreshInterval = Duration(seconds: 15)' lib/screens/multi_camera_screen.dart \
  || fail 'Atualizacao automatica de 15 s da Central nao encontrada.'
grep -q 'Editar / renomear' lib/screens/multi_camera_screen*.dart \
  || fail 'Edicao/renomeacao de camera nao encontrada.'
grep -q "value == 'toggle'" lib/screens/multi_camera_screen*.dart \
  || fail 'Ativacao/desativacao de camera nao encontrada.'
grep -q 'VideoSourceState.reconnecting' lib/sources/remote_phone_camera_source.dart \
  || fail 'Camera remota perdeu estado de reconexao automatica.'
[[ -f test/camera_endpoint_test.dart ]] \
  || fail 'Testes de CameraEndpoint nao encontrados.'
grep -q "cameraId: 'cam-portao'" test/monitor_event_test.dart \
  || fail 'Teste de persistencia de cameraId nao encontrado.'
grep -q 'flutter test --reporter expanded --coverage' .github/workflows/android-apk.yml \
  || fail 'Workflow nao gera cobertura expandida dos testes.'
grep -q 'flutter-test-coverage' .github/workflows/android-apk.yml \
  || fail 'Artifact de cobertura nao encontrado no workflow.'
grep -q '^version: 1.0.77+77$' pubspec.yaml \
  || fail 'pubspec.yaml nao esta em 1.0.77+77.'

# Identidade tecnica 1.0.28
grep -q '^name: vigiaia$' pubspec.yaml \
  || fail 'Pacote Dart nao usa vigiaia.'
grep -q '"projectName": "vigiaia"' app_identity.json \
  || fail 'app_identity.json nao usa projectName vigiaia.'
grep -q '"version": "1.0.77"' app_identity.json \
  || fail 'app_identity.json nao esta na versao 1.0.77.'
grep -q '"build": 77' app_identity.json \
  || fail 'app_identity.json nao esta no build 77.'
grep -q '"applicationId": "com.vigiaia.app"' app_identity.json \
  || fail 'applicationId vigiaia nao esta registrado.'
grep -q 'namespace = "com.vigiaia.app"' android/app/build.gradle.kts \
  || fail 'Namespace Android nao usa com.vigiaia.app.'
grep -q 'applicationId = "com.vigiaia.app"' android/app/build.gradle.kts \
  || fail 'applicationId Android nao usa com.vigiaia.app.'
grep -q '^package com.vigiaia.app$' tool/android/MainActivity.kt \
  || fail 'MainActivity template nao usa o package vigiaia.'
grep -q "MethodChannel('vigiaia/background')" lib/services/background_monitor_service.dart \
  || fail 'Canal de background nao usa a identidade vigiaia.'
grep -q "MethodChannel('vigiaia/native')" lib/services/native_platform_service.dart \
  || fail 'Canal nativo nao usa a identidade vigiaia.'
grep -q "static const String scheme = 'vigiaia';" lib/services/remote_camera_pairing_service.dart \
  || fail 'Protocolo QR nao usa o esquema vigiaia.'
grep -q '^## 1.0.28+28' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.28.'
grep -q 'Evolução 1.0.28' README.md || fail 'README nao documenta 1.0.28.'
grep -q 'Identidade técnica e correção de build 1.0.28' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta identidade tecnica 1.0.28.'
if grep -q "import 'dart:typed_data';" lib/services/monitor_lan_stream_service.dart; then
  fail 'Import redundante dart:typed_data reapareceu no stream LAN.'
fi
if grep -q "if (statusText != null) 'statusText': statusText" lib/services/background_monitor_service.dart; then
  fail 'Colecao condicional que disparava use_null_aware_elements reapareceu.'
fi

# Identidade e tema padrao 1.0.25
grep -q "static const String name = 'Vigia IA';" lib/core/app_metadata.dart \
  || fail 'AppMetadata nao usa o nome Vigia IA.'
grep -q "title: 'Vigia IA'" lib/app/app.dart \
  || fail 'MaterialApp nao usa o titulo Vigia IA.'
grep -q 'android:label="Vigia IA"' android/app/src/main/AndroidManifest.xml \
  || fail 'Android Manifest nao usa Vigia IA.'
grep -q 'AppThemePreference _themePreference = AppThemePreference.dark;' lib/services/appearance_settings_service.dart \
  || fail 'Tema padrao de novas instalacoes nao esta Escuro.'
grep -q 'orElse: () => AppThemePreference.dark' lib/services/appearance_settings_service.dart \
  || fail 'Fallback de tema invalido nao esta Escuro.'
[[ -f test/app_metadata_test.dart ]] || fail 'Teste de metadados 1.0.25 nao encontrado.'
grep -q '^## 1.0.25+25' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.25.'
grep -q 'Evolução 1.0.25' README.md || fail 'README nao documenta 1.0.25.'
grep -q 'Identidade e aparência 1.0.25' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta identidade/tema da 1.0.25.'

# Permissoes e segundo plano 1.0.26
grep -q 'requestCameraPermission' tool/android/MainActivity.kt \
  || fail 'Bridge nativa nao solicita permissao da camera.'
grep -q 'maybePromptCameraPermissionOnFirstLaunch' tool/android/MainActivity.kt \
  || fail 'Camera nao e solicitada na primeira abertura.'
grep -q 'FOREGROUND_SERVICE_SPECIAL_USE' tool/AndroidManifest.xml \
  || fail 'Permissao specialUse do foreground service nao declarada.'
grep -q 'camera|specialUse' tool/AndroidManifest.xml \
  || fail 'Tipos camera/specialUse nao declarados no servico.'
grep -q 'FOREGROUND_SERVICE_TYPE_CAMERA' tool/android/MonitoringForegroundService.kt \
  || fail 'Foreground service nao promove sessao local como camera.'
grep -q 'return START_STICKY' tool/android/MonitoringForegroundService.kt \
  || fail 'Foreground service nao usa START_STICKY para recuperacao assistida.'
grep -q '_checkBackgroundHealth' lib/controllers/monitor_controller.dart \
  || fail 'Watchdog de frames em segundo plano nao encontrado.'
grep -q 'App minimizado • monitoramento continua ativo.' lib/controllers/monitor_controller.dart \
  || fail 'Notificacao de monitoramento minimizado nao esta atualizada.'
grep -q '^## 1.0.26+26' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.26.'
grep -q 'Evolução 1.0.26' README.md || fail 'README nao documenta 1.0.26.'
grep -q 'Permissões e segundo plano 1.0.26' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta permissoes/segundo plano 1.0.26.'
[[ -f test/background_monitor_status_test.dart ]] || fail 'Teste do status do foreground service nao encontrado.'
[[ -f test/camera_permission_status_test.dart ]] || fail 'Teste do status da permissao de camera nao encontrado.'

# Transmissao LAN do monitor 1.0.27
[[ -f lib/services/monitor_lan_stream_service.dart ]] \
  || fail 'MonitorLanStreamService nao encontrado.'
grep -q "case '/frame.jpg'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Endpoint JPEG do visualizador LAN nao encontrado.'
grep -q "case '/status'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Endpoint de estado real do visualizador LAN nao encontrado.'
grep -q 'publishFrame(frame)' lib/controllers/monitor_controller.dart \
  || fail 'Frames do monitor nao sao publicados na LAN.'
grep -q 'await ensureLanStreaming();' lib/controllers/monitor_controller.dart \
  || fail 'Servidor LAN nao inicia junto com a fonte.'
grep -q 'await _lanStream.stop();' lib/controllers/monitor_controller.dart \
  || fail 'Servidor LAN nao encerra junto com a fonte.'
grep -q "Text('Rede local')" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Acesso a Rede local nao aparece no monitor.'
grep -q 'NEARBY_WIFI_DEVICES' tool/AndroidManifest.xml \
  || fail 'Permissao NEARBY_WIFI_DEVICES nao declarada.'
grep -q 'ACCESS_LOCAL_NETWORK' tool/AndroidManifest.xml \
  || fail 'Permissao ACCESS_LOCAL_NETWORK nao declarada.'
grep -q 'requestLocalNetworkPermission' tool/android/MainActivity.kt \
  || fail 'Bridge nativa de permissao LAN nao encontrada.'

grep -Fq '"canRequest" to (!granted && !localNetworkPermissionRequestInFlight)' tool/android/MainActivity.kt \
  || fail 'Expressao canRequest da permissao de rede local nao esta parentizada com seguranca.'
grep -q 'requestLocalNetworkPermission' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Camera nao solicita permissao LAN quando exigida.'
grep -q 'InternetAddress(localAddress)' lib/services/monitor_lan_stream_service.dart \
  || fail 'Servidor do monitor nao esta vinculado ao IPv4 local selecionado.'
[[ -f test/monitor_lan_stream_service_test.dart ]] \
  || fail 'Teste do servidor LAN nao encontrado.'
[[ -f test/local_network_permission_status_test.dart ]] \
  || fail 'Teste da permissao LAN nao encontrado.'
grep -q '^## 1.0.27+27' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.27.'
grep -q 'Evolução 1.0.27' README.md || fail 'README nao documenta 1.0.27.'
grep -q 'Transmissão LAN do monitor 1.0.27' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta transmissao LAN 1.0.27.'

# Simplificacao visual e navegacao 1.0.24
[[ -f lib/services/appearance_settings_service.dart ]] || fail 'Servico de Aparencia 1.0.24 nao encontrado.'
[[ -f lib/screens/appearance_settings_screen.dart ]] || fail 'Tela de Aparencia 1.0.24 nao encontrada.'
[[ -f lib/screens/advanced_settings_screen.dart ]] || fail 'Tela Avancado 1.0.24 nao encontrada.'
grep -q "static const Set<String> automobiles" lib/models/object_filter_catalog.dart \
  || fail 'Grupo Automoveis nao encontrado no catalogo.'
grep -q "'car'" lib/models/object_filter_catalog.dart || fail 'Carro ausente do grupo Automoveis.'
grep -q "'motorcycle'" lib/models/object_filter_catalog.dart || fail 'Moto ausente do grupo Automoveis.'
grep -q "'bus'" lib/models/object_filter_catalog.dart || fail 'Onibus ausente do grupo Automoveis.'
grep -q "'truck'" lib/models/object_filter_catalog.dart || fail 'Caminhao ausente do grupo Automoveis.'
grep -q 'normalizeSelection' lib/services/app_settings_service.dart \
  || fail 'Migracao das classes antigas nao esta ligada ao carregamento.'
grep -q "title: 'Pessoas'" lib/widgets/object_filter_dialog.dart \
  || fail 'Card Pessoas nao encontrado na selecao.'
grep -q "title: 'Automóveis'" lib/widgets/object_filter_dialog.dart \
  || fail 'Card Automoveis nao encontrado na selecao.'
grep -q "title: 'Animais'" lib/widgets/object_filter_dialog.dart \
  || fail 'Card Animais nao encontrado na selecao.'
for destination in 'Início' 'Histórico' 'Monitor' 'Câmeras'; do
  grep -q "label: '$destination'" lib/widgets/main_navigation_bar.dart \
    || fail "Destino principal ausente: $destination"
done
if grep -q "label: 'Diagnóstico'" lib/widgets/main_navigation_bar.dart; then
  fail 'Diagnostico nao pode ficar na barra principal 1.0.24.'
fi
if grep -q "label: 'Configurações'" lib/widgets/main_navigation_bar.dart; then
  fail 'Configuracoes nao pode ficar na barra principal 1.0.24.'
fi
grep -q "title: 'Aparência'" lib/screens/settings_screen.dart \
  || fail 'Categoria Aparencia nao encontrada nas Configuracoes.'
grep -q "title: 'Diagnóstico'" lib/screens/settings_screen.dart \
  || fail 'Categoria Diagnostico nao encontrada nas Configuracoes.'
grep -q "title: 'Avançado'" lib/screens/settings_screen.dart \
  || fail 'Secao Avancado nao encontrada nas Configuracoes.'
grep -q 'AppThemePreference.system' lib/screens/appearance_settings_screen.dart \
  || fail 'Tema Sistema nao encontrado.'
grep -q 'AppThemePreference.light' lib/screens/appearance_settings_screen.dart \
  || fail 'Tema Claro nao encontrado.'
grep -q 'AppThemePreference.dark' lib/screens/appearance_settings_screen.dart \
  || fail 'Tema Escuro nao encontrado.'
grep -q 'singularNameForLabel' lib/services/statistics_service.dart \
  || fail 'Estatisticas nao agregam os tres grupos visuais.'
grep -q 'event.type == MonitorEventType.cameraObstructed' lib/screens/events_screen.dart \
  || fail 'Historico nao filtra eventos tecnicos de integridade.'
if grep -q '_eventHistory.addCameraIntegrityEvent' lib/controllers/monitor_controller.dart; then
  fail 'MonitorController nao deve gravar integridade da camera no Historico 1.0.24.'
fi
grep -q 'this.countingEnabled = false' lib/models/camera_endpoint.dart \
  || fail 'Reserva de contagem por camera deve iniciar desativada.'
grep -q "'countingEnabled': countingEnabled" lib/models/camera_endpoint.dart \
  || fail 'Reserva futura de contagem nao e persistida por camera.'
grep -q 'Adicionar outra câmera não ativa contador' lib/screens/multi_camera_screen*.dart \
  || fail 'Central multicamera nao explica independencia da contagem.'
grep -q 'Entrada e saída' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Monitor nao explica entrada/saida.'
grep -q '^## 1.0.24+24' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.24.'
grep -q 'Evolução 1.0.24' README.md || fail 'README nao documenta 1.0.24.'
grep -q 'Interface e domínio de detecção 1.0.24' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta a fronteira dos tres grupos.'

# Diagnostico e saude real 1.0.29
[[ -f lib/services/system_health_service.dart ]] || fail 'SystemHealthService nao encontrado.'
grep -q "import '../models/system_health.dart';" lib/controllers/monitor_controller.dart || fail 'MonitorController nao importa CameraHealthState.'
grep -q "bytes < 0 ? 0.0 : bytes.toDouble()" lib/utils/storage_size_formatter.dart || fail 'StorageSizeFormatter pode voltar a inferir num em bytes.'
grep -q "mebibytes < 0 ? 0.0 : mebibytes.toDouble()" lib/utils/storage_size_formatter.dart || fail 'StorageSizeFormatter pode voltar a inferir num em MiB.'
[[ -f lib/services/diagnostic_report_service.dart ]] || fail 'DiagnosticReportService nao encontrado.'
[[ -f lib/utils/storage_size_formatter.dart ]] || fail 'StorageSizeFormatter nao encontrado.'
[[ -f lib/widgets/help_button.dart ]] || fail 'HelpButton nao encontrado.'
[[ -f test/storage_size_formatter_test.dart ]] || fail 'Teste de formatacao de armazenamento nao encontrado.'
[[ -f test/system_health_state_test.dart ]] || fail 'Teste de estados da Saude nao encontrado.'
[[ -f test/runtime_health_service_test.dart ]] || fail 'Teste de heartbeat de frames nao encontrado.'
[[ -f test/diagnostic_report_service_test.dart ]] || fail 'Teste de diagnostico/exportacao nao encontrado.'
grep -q "label: const Text('Exportar')" lib/screens/error_center_screen.dart || fail 'Botao Exportar do Diagnostico nao encontrado.'
grep -q "Serviço Android ativo" lib/screens/system_health_screen.dart || fail 'Saude nao separa o servico Android.'
grep -q "Frames chegando" lib/screens/system_health_screen.dart || fail 'Saude nao exibe o estado de frames.'
grep -q "Monitoramento IA ativo" lib/screens/system_health_screen.dart || fail 'Saude nao exibe o estado real da IA.'
grep -q "title: 'Transmissão LAN'" lib/screens/system_health_screen.dart || fail 'Saude nao exibe a transmissao LAN.'
grep -q "title: 'Servidor LAN'" lib/screens/system_health_screen.dart || fail 'Saude nao separa servidor LAN de frames enviados.'
grep -q "StorageSizeFormatter.formatBytes" lib/screens/storage_backup_screen.dart || fail 'Armazenamento nao usa o formatador unico.'
grep -q '"shareText"' tool/android/MainActivity.kt || fail 'Bridge nativa de compartilhamento nao encontrada.'
grep -q 'freeStorageBytes' tool/android/MainActivity.kt || fail 'Metricas Android nao usam bytes.'
grep -q '^## 1.0.32+32' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.32.'
grep -q 'Evolução 1.0.32' README.md || fail 'README nao documenta 1.0.32.'
grep -q 'Diagnóstico e saúde real 1.0.29' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta a Etapa 4.'

# Regressão Android APK 3: a chave LAN deve usar percent-encoding canônico (%20),
# não application/x-www-form-urlencoded (+), para manter o contrato do endereço exibido.
grep -q 'Uri.encodeComponent(accessKey)' lib/services/monitor_lan_stream_service.dart \
  || fail 'URL LAN nao usa Uri.encodeComponent para a chave compartilhada.'
! grep -q 'Uri.encodeQueryComponent(accessKey)' lib/services/monitor_lan_stream_service.dart \
  || fail 'Codificacao antiga da chave LAN ainda esta presente.'


# Integracao corretiva 1.0.33
[[ -f lib/services/shared_local_camera_service.dart ]] \
  || fail 'SharedLocalCameraService nao encontrado.'
grep -q 'CameraController(' lib/services/shared_local_camera_service.dart \
  || fail 'CameraController compartilhado nao foi encontrado.'
if grep -q 'CameraController(' lib/sources/local_camera_source.dart; then
  fail 'LocalCameraSource voltou a criar CameraController proprio.'
fi
grep -q 'SharedLocalCameraService.instance' lib/sources/local_camera_source.dart \
  || fail 'LocalCameraSource nao usa a camera compartilhada.'
grep -q 'LocalCameraSource(' lib/services/remote_camera_server_service.dart \
  || fail 'Modo Camera nao reutiliza LocalCameraSource compartilhada.'
grep -q 'restartPipeline' lib/controllers/monitor_controller.dart \
  || fail 'Watchdog nao reinicia o pipeline compartilhado.'

grep -q "return '\$base/#key=\${Uri.encodeComponent(accessKey)}';" lib/services/monitor_lan_stream_service.dart \
  || fail 'Link automatico LAN nao usa fragmento protegido.'
grep -q "path == '/session'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Sessao temporaria do navegador LAN nao encontrada.'
grep -q "Cookie('vigia_session'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Cookie temporario LAN nao encontrado.'
grep -q "history.replaceState" lib/services/monitor_lan_stream_service.dart \
  || fail 'Pagina LAN nao remove a chave da barra apos autenticar.'
grep -q "fetch('/status'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Pagina LAN nao consulta o estado real.'
grep -q "img.src='/frame.jpg" lib/services/monitor_lan_stream_service.dart \
  || fail 'Pagina LAN nao carrega quadros JPEG por sequencia.'
if grep -q '/stream.mjpg' lib/services/monitor_lan_stream_service.dart; then
  fail 'MJPEG legado reapareceu no visualizador LAN principal.'
fi

grep -q 'const Duration(milliseconds: 400)' lib/models/video_source_config.dart \
  || fail 'Intervalo local padrao de 400 ms nao encontrado.'
grep -q 'const Duration(seconds: 1)' lib/models/video_source_config.dart \
  || fail 'Ausencia padrao de 1 s nao encontrada.'
grep -q "'version': 7" lib/services/app_settings_service.dart \
  || fail 'Schema de configuracoes nao foi migrado para version 7.'
grep -q 'profileVersion < 6' lib/services/app_settings_service.dart \
  || fail 'Migracao dos antigos defaults nao encontrada.'
grep -q 'SpeechPriority.high' lib/controllers/monitor_controller*.dart \
  || fail 'Alertas prioritarios de entrada/saida/integridade nao encontrados.'
grep -q 'await _tts.stop();' lib/services/speech_service.dart \
  || fail 'TTS nao descarta fala anterior antes do alerta atual.'
grep -q 'Duration(seconds: 3)' lib/controllers/monitor_controller.dart \
  || fail 'Watchdog rapido de 3 s nao encontrado.'

grep -q "owner: BackgroundMonitorService.monitorOwner" lib/controllers/monitor_controller.dart \
  || fail 'Lease do Monitor nao encontrado.'
grep -q "owner: BackgroundMonitorService.cameraModeOwner" lib/services/remote_camera_server_service.dart \
  || fail 'Lease do Modo Camera nao encontrado.'
grep -q "'heartbeat'" lib/services/background_monitor_service.dart \
  || fail 'Heartbeat Flutter do foreground service nao encontrado.'
grep -q 'flutterHeartbeatFresh' lib/services/system_health_service.dart \
  || fail 'Saude do sistema nao valida heartbeat Flutter.'
grep -q 'lanServerActive' lib/models/system_health.dart \
  || fail 'Saude nao distingue servidor LAN de transmissao com frames.'
grep -q 'Frames LAN recentes:' lib/services/diagnostic_report_service.dart \
  || fail 'Diagnostico nao registra frescor dos frames LAN.'
grep -q 'heartbeatStaleMs = 15_000L' tool/android/MonitoringForegroundService.kt \
  || fail 'Timeout nativo do heartbeat nao encontrado.'
grep -q 'orphanStopMs = 60_000L' tool/android/MonitoringForegroundService.kt \
  || fail 'Encerramento do servico orfao nao encontrado.'
grep -q 'return START_STICKY' tool/android/MonitoringForegroundService.kt \
  || fail 'Recuperacao START_STICKY nao encontrada.'

grep -q 'SystemUiMode.edgeToEdge' lib/services/system_ui_service.dart \
  || fail 'Modo edge-to-edge global nao encontrado.'
grep -q 'SystemUiMode.immersiveSticky' lib/services/system_ui_service.dart \
  || fail 'Modo imersivo das telas de camera nao encontrado.'
grep -q 'SystemUiService.immersive' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Monitor ao vivo nao entra em tela imersiva.'
grep -q 'SystemUiService.immersive' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Camera nao entra em tela imersiva.'

grep -q '^## 1.0.33+33' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.33.'
grep -q 'Evolução 1.0.33' README.md || fail 'README nao documenta 1.0.33.'
grep -q 'Schema atual: `version: 7`.' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta schema 7.'

# Buildfix 1.0.35
if grep -q "import 'dart:typed_data';" lib/services/shared_local_camera_service.dart; then
  fail 'Import dart:typed_data redundante reapareceu em SharedLocalCameraService.'
fi
grep -q '^## 1.0.35+35' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.35.'
grep -q 'Evolução 1.0.35' README.md || fail 'README nao documenta 1.0.35.'

# Evolucao da deteccao 1.0.34
[[ -f lib/services/detector_image_transform.dart ]] \
  || fail 'Transformacao letterbox do detector nao encontrada.'
[[ -f lib/services/detection_confidence_policy.dart ]] \
  || fail 'Politica adaptativa de confianca nao encontrada.'
[[ -f lib/services/temporal_detection_filter.dart ]] \
  || fail 'Filtro temporal de deteccoes nao encontrado.'
[[ -f lib/services/detection_merger.dart ]] \
  || fail 'Mesclagem das duas passagens de deteccao nao encontrada.'
grep -q 'DetectorImageTransform.fit' lib/services/detector_input_buffer.dart \
  || fail 'Inferencia nao usa letterbox preservando proporcao.'
grep -q 'EfficientDet-Lite0' lib/services/object_detection_service.dart \
  || fail 'EfficientDet-Lite0 nao e o detector principal.'
grep -q 'SSD MobileNet V1' lib/services/object_detection_service.dart \
  || fail 'Fallback SSD MobileNet nao foi preservado.'
grep -q 'focusRegions(maxRegions: 2)' lib/controllers/monitor_controller.dart \
  || fail 'Focos separados de movimento nao estao ligados ao pipeline.'
grep -q 'idlePresenceRefresh' lib/controllers/monitor_controller.dart \
  || fail 'Atualizacao periodica de presenca sem movimento nao foi encontrada.'
grep -q 'TemporalDetectionFilter' lib/controllers/monitor_controller.dart \
  || fail 'Confirmacao temporal nao esta ligada ao controller.'
grep -q "'version': 7" lib/services/app_settings_service.dart \
  || fail 'Schema 7 das regras de deteccao nao encontrado.'
grep -q 'vehicleMinimumPresence = const Duration(milliseconds: 600)' lib/models/smart_alert_rules.dart \
  || fail 'Tempo padrao de veiculo nao foi reduzido para 600 ms.'
grep -q 'animalMinimumPresence = const Duration(milliseconds: 800)' lib/models/smart_alert_rules.dart \
  || fail 'Tempo padrao de animal nao foi reduzido para 800 ms.'
grep -q 'lite-model_efficientdet_lite0_detection_metadata_1.tflite' tool/fetch_model.sh \
  || fail 'Download do EfficientDet-Lite0 nao esta configurado.'
[[ -f test/detector_image_transform_test.dart ]] || fail 'Teste de letterbox nao encontrado.'
[[ -f test/detection_confidence_policy_test.dart ]] || fail 'Teste da confianca adaptativa nao encontrado.'
[[ -f test/temporal_detection_filter_test.dart ]] || fail 'Teste da confirmacao temporal nao encontrado.'
[[ -f test/detection_merger_test.dart ]] || fail 'Teste da segunda passagem nao encontrado.'
grep -q '^## 1.0.34+34' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.34.'
grep -q 'Evolução 1.0.34' README.md || fail 'README nao documenta 1.0.34.'
grep -q 'Vigia IA 1.0.77+77' ARCHITECTURE.md || fail 'ARCHITECTURE nao esta em 1.0.77+77.'

# Evolucao da deteccao 1.0.36
[[ -f lib/services/detection_scan_planner.dart ]] \
  || fail 'Planejador multiescala da deteccao nao encontrado.'
grep -q 'allowedLabels' lib/services/object_detection_service.dart \
  || fail 'Detector nao filtra classes monitoradas antes de maxResults.'
grep -q 'acceptedThresholdForDetection' lib/services/detection_confidence_policy.dart \
  || fail 'Confianca nao considera tamanho da deteccao.'
grep -q 'confirmationHits' lib/services/temporal_detection_filter.dart \
  || fail 'Filtro temporal nao usa confirmacao adaptativa.'
grep -q 'focusRegions(maxRegions: 2)' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao usa focos separados de movimento.'
grep -q 'detailScanInterval = Duration(milliseconds: 1600)' lib/controllers/monitor_controller.dart \
  || fail 'Varredura detalhada controlada nao encontrada.'
grep -q 'DetectionScanPlanner.recoveryZone' lib/controllers/monitor_controller.dart \
  || fail 'Reaquisicao localizada nao esta conectada ao controller.'
grep -q 'existingGroup == detectionGroup' lib/services/detection_merger.dart \
  || fail 'Mesclagem semantica por familia nao encontrada.'
[[ -f test/detection_scan_planner_test.dart ]] \
  || fail 'Teste do planejador de varredura nao encontrado.'
grep -q 'movimentos separados geram regioes de foco separadas' test/motion_detection_service_test.dart \
  || fail 'Teste de multiplos focos de movimento nao encontrado.'
grep -q '^## 1.0.36+36' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.36.'
grep -q 'Evolução 1.0.36' README.md || fail 'README nao documenta 1.0.36.'

# Evolucao de movimento/aparencia e audio 1.0.37
[[ -f lib/models/object_appearance.dart ]] \
  || fail 'Modelo ObjectAppearance nao encontrado.'
[[ -f lib/services/object_appearance_service.dart ]] \
  || fail 'ObjectAppearanceService nao encontrado.'
[[ -f test/object_appearance_service_test.dart ]] \
  || fail 'Testes de aparencia por cor nao encontrados.'
grep -q 'colorDifferenceThreshold' lib/services/motion_detection_service.dart \
  || fail 'Movimento nao considera diferenca RGB.'
grep -q 'ObjectAppearanceService.enrichAll' lib/controllers/monitor_controller.dart \
  || fail 'Assinatura visual nao esta ligada ao pipeline.'
grep -q 'ObjectAppearanceService.similarity' lib/services/object_tracker.dart \
  || fail 'Rastreamento nao usa semelhanca de aparencia.'
grep -q 'identityRetention = const Duration(seconds: 12)' lib/services/object_tracker.dart \
  || fail 'Retencao de identidade de 12 s nao encontrada.'
grep -q "ObjectFilterCatalog.groupKeyForLabel(detection.label)" lib/controllers/monitor_controller.dart \
  || fail 'Anti-repeticao nao usa familia semantica do objeto.'
grep -q 'const Duration(seconds: 5)' lib/controllers/monitor_controller.dart \
  || fail 'Janela antichatter de transicoes nao encontrada.'
[[ -f custom_audio/README.md ]] || fail 'Guia de audio personalizado nao encontrado.'
grep -q 'playCustomAlertAudio' lib/services/native_platform_service.dart \
  || fail 'Bridge Flutter para audio personalizado nao encontrada.'
grep -q 'playCustomAlertAudio' tool/android/MainActivity.kt \
  || fail 'Reproducao nativa de audio personalizado nao encontrada.'
grep -q 'MediaPlayer' tool/android/AlertAudioPlayer.kt \
  || fail 'MediaPlayer nativo para audio personalizado nao encontrado.'
grep -q 'CUSTOM_AUDIO_DIR' tool/bootstrap_android.sh \
  || fail 'Bootstrap nao copia custom_audio para res/raw.'
grep -q '^## 1.0.37+37' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.37.'
grep -q 'Evolução 1.0.37' README.md || fail 'README nao documenta 1.0.37.'
grep -q 'Reidentificação visual e áudio personalizado 1.0.37' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta 1.0.37.'

# Pacote de voz personalizado 1.0.38
grep -q '^## 1.0.38+38' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.38.'
grep -q 'Evolução 1.0.38' README.md || fail 'README nao documenta 1.0.38.'
grep -q 'Pacote de voz personalizado 1.0.38' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta 1.0.38.'
grep -q '_audioSlotForTransition' lib/controllers/monitor_controller*.dart \
  || fail 'Controller nao seleciona audio de transicao por categoria.'
grep -q 'AudioSlotIds.personEntered' lib/controllers/monitor_controller*.dart \
  || fail 'Slots de entrada/saida de pessoa nao estao ligados ao catalogo central.'
grep -q 'AudioSlotIds.vehicleEntered' lib/controllers/monitor_controller*.dart \
  || fail 'Slots de entrada/saida de veiculo nao estao ligados ao catalogo central.'
grep -q 'AudioSlotIds.animalEntered' lib/controllers/monitor_controller*.dart \
  || fail 'Slots de entrada/saida de animal nao estao ligados ao catalogo central.'
for audio in \
  person_detected vehicle_detected animal_detected object_detected \
  person_entered person_exited vehicle_entered vehicle_exited \
  animal_entered animal_exited object_entered object_exited \
  camera_obstructed camera_moved; do
  [[ -f "custom_audio/$audio.m4a" ]] || fail "Audio personalizado ausente: $audio.m4a"
  [[ -f "android/app/src/main/res/raw/$audio.m4a" ]] || fail "Audio Android ausente: $audio.m4a"
done

# Nomes tecnicos antigos nao podem voltar ao projeto atual.
for legacy in 'Monitor IA' 'monitor-ia' 'camera_guard_offline' 'vigia-ia'; do
  if grep -R -F -I -n --exclude-dir=.git --exclude='*.zip' --exclude='verify_project.sh' -- "$legacy" \
      lib android tool test pubspec.yaml app_identity.json README.md CHANGELOG.md ARCHITECTURE.md >/dev/null 2>&1; then
    fail "Referencia antiga reapareceu: $legacy"
  fi
done


# Evolucao de UI/permissoes e compatibilidade Flutter 3.44 - 1.0.39
[[ -f lib/screens/access_guide_screen.dart ]] \
  || fail 'Tela inicial de permissoes 1.0.39 nao encontrada.'
grep -q 'Escanear QR do outro celular' lib/screens/home_screen.dart \
  || fail 'Pareamento por QR nao esta exposto na Home.'
grep -q 'PhonePairingScannerScreen' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Pareamento por QR nao esta ligado ao seletor de fonte.'
[[ -f lib/services/partial_person_detection_service.dart ]] \
  || fail 'Heuristica de pessoa parcial nao encontrada.'
grep -q 'PartialPersonDetectionService.infer' lib/controllers/monitor_controller.dart \
  || fail 'Heuristica de pessoa parcial nao esta ligada ao pipeline.'
grep -q '_recentAlertMemory' lib/controllers/monitor_controller.dart \
  || fail 'Memoria visual anti-repeticao nao encontrada.'
if grep -q 'groupValue: selected' lib/screens/monitor_screen.dart; then
  fail 'API Radio.groupValue obsoleta reapareceu no seletor de fonte.'
fi
if grep -q 'onChanged: (_) => onTap()' lib/screens/monitor_screen.dart; then
  fail 'API Radio.onChanged obsoleta reapareceu no seletor de fonte.'
fi
grep -q '^## 1.0.40+40' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.40.'
grep -q 'Evolução 1.0.40' README.md || fail 'README nao documenta 1.0.40.'
grep -q 'Evolução 1.0.40' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.40.'
[[ -f AGENTS.md ]] || fail 'AGENTS.md com regras permanentes do projeto nao encontrado.'


# Modo Bike - 1.0.40
test -f lib/models/bike_mode_config.dart || fail 'BikeModeConfig ausente.'
test -f lib/services/bike_mode_service.dart || fail 'BikeModeService ausente.'
test -f lib/screens/bike_mode_screen.dart || fail 'BikeModeScreen ausente.'
grep -q "label: 'Bike'" lib/widgets/main_navigation_bar.dart || fail 'Destino Bike nao aparece no menu principal.'
grep -q 'currentIndex: 4' lib/screens/bike_mode_screen.dart || fail 'Tela Bike nao seleciona o quinto destino do menu principal.'
test -f test/main_navigation_bar_test.dart || fail 'Teste do menu principal com destino Bike ausente.'
grep -q "findsNWidgets(5)" test/main_navigation_bar_test.dart || fail 'Teste do menu principal nao valida os cinco destinos.'
grep -q '4 => const BikeModeScreen()' lib/screens/home_screen.dart || fail 'Inicio nao navega para o Modo Bike.'
grep -q '4 => const BikeModeScreen()' lib/screens/events_screen.dart || fail 'Historico nao navega para o Modo Bike.'
grep -q '4 => const BikeModeScreen()' lib/screens/multi_camera_screen.dart || fail 'Cameras nao navega para o Modo Bike.'
if grep -q "title: 'Modo Bike'" lib/screens/settings_screen.dart; then
  fail 'Modo Bike voltou a ficar duplicado em Configuracoes.'
fi
grep -q 'BikePowerProfile.extremeEconomy' lib/models/bike_mode_config.dart || fail 'Perfis do Modo Bike incompletos.'
test -f test/bike_mode_config_test.dart || fail 'Teste do Modo Bike ausente.'

# Modo Bike - Etapa 2 - 1.0.41
grep -q '^## 1.0.41+41' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.41.'
grep -q 'Evolução 1.0.41' README.md || fail 'README nao documenta 1.0.41.'
grep -q 'Evolução 1.0.41' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.41.'
test -f lib/models/device_telemetry.dart || fail 'DeviceTelemetrySnapshot ausente.'
grep -q 'effectiveAnalysisInterval' lib/models/bike_mode_config.dart || fail 'Modo Bike nao calcula intervalo efetivo.'
grep -q 'targetJpegQuality' lib/models/bike_mode_config.dart || fail 'Modo Bike nao define politica JPEG por perfil.'
grep -q 'setBikeScreenBrightness' lib/services/native_platform_service.dart || fail 'Ponte de brilho do Modo Bike ausente.'
grep -q 'setBikeScreenBrightness' tool/android/MainActivity.kt || fail 'Implementacao Android do brilho do Modo Bike ausente.'
grep -q 'appCpuPercent' tool/android/MainActivity.kt || fail 'Telemetria de CPU do app ausente.'
grep -q 'batteryCharging' tool/android/MainActivity.kt || fail 'Telemetria de carga da bateria ausente.'
grep -q 'setEncodingPolicy' lib/services/monitor_lan_stream_service.dart || fail 'Transmissao LAN nao aplica politica de compressao do Modo Bike.'
grep -q 'updateDeviceTelemetry' lib/services/monitor_lan_stream_service.dart || fail 'Telemetria nao foi conectada ao status LAN.'
grep -q '_bikeConfig.effectiveAnalysisInterval' lib/controllers/monitor_controller.dart || fail 'MonitorController nao aplica intervalo do Modo Bike.'
grep -q '_bikeConfig.effectiveAnalysisInterval' lib/services/remote_camera_server_service.dart || fail 'Modo Camera nao aplica intervalo do Modo Bike.'
grep -q "'device': telemetry.toJson()" lib/services/remote_camera_server_service.dart || fail 'Modo Camera nao expoe telemetria no status.'
test -f test/device_telemetry_test.dart || fail 'Teste de telemetria do dispositivo ausente.'


# Modo Bike - Etapa 3 - 1.0.42
grep -q '^## 1.0.42+42' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.42.'
grep -q 'Evolução 1.0.42' README.md || fail 'README nao documenta 1.0.42.'
grep -q 'Evolução 1.0.42' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.42.'
test -f lib/models/remote_phone_status.dart || fail 'RemotePhoneStatus ausente.'
test -f lib/widgets/remote_bike_status_panel.dart || fail 'Painel remoto do Modo Bike ausente.'
test -f test/remote_phone_status_test.dart || fail 'Teste do status remoto ausente.'
grep -q 'Future<void> _pollStatus()' lib/sources/remote_phone_camera_source.dart \
  || fail 'Fonte de celular remoto nao consulta telemetria.'
grep -q "request.headers.set('x-monitor-key', accessKey)" lib/sources/remote_phone_camera_source.dart \
  || fail 'Status remoto nao usa a chave de sessao no header.'
grep -q "'fps': _streamFps" lib/services/remote_camera_server_service.dart \
  || fail 'Modo Camera nao publica FPS no status.'
grep -q "'lowBatteryPercent': _bikeConfig.lowBatteryPercent" lib/services/remote_camera_server_service.dart \
  || fail 'Modo Camera nao publica o limite de bateria baixa.'
grep -q 'remoteStatusNotifier.addListener' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController nao observa telemetria do celular traseiro.'
grep -q 'RemoteBikeStatusPanel' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Monitor nao expoe painel do celular traseiro.'
grep -q 'RemoteBikeWarningBanner' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Monitor nao destaca avisos do celular traseiro.'
grep -q 'DeviceTelemetrySnapshot.fromJson' test/device_telemetry_test.dart \
  || fail 'Teste de telemetria remota com capturedAt ausente.'

# Buildfix Flutter analyze - 1.0.43
grep -q '^## 1.0.43+43' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.43.'
grep -q 'Evolução 1.0.43' README.md || fail 'README nao documenta 1.0.43.'
grep -q 'Evolução 1.0.43' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.43.'
if grep -q 'rawDevice as Map' lib/models/remote_phone_status.dart; then
  fail 'Cast redundante rawDevice as Map reapareceu.'
fi
if grep -q 'decoded as Map' lib/sources/remote_phone_camera_source.dart; then
  fail 'Cast redundante decoded as Map reapareceu.'
fi

# Navegacao principal do Modo Bike - 1.0.44
grep -q '^## 1.0.44+44' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.44.'
grep -q 'Evolução 1.0.44' README.md || fail 'README nao documenta 1.0.44.'
grep -q 'Evolução 1.0.44' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.44.'

# Biblioteca central de audio e personalizacao - 1.0.45
grep -q '^## 1.0.45+45' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.45.'
grep -q 'Evolução 1.0.45' README.md || fail 'README nao documenta 1.0.45.'
grep -q 'Evolução 1.0.45' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.45.'
[[ -f lib/models/audio_slot.dart ]] || fail 'Catalogo central de audio ausente.'
[[ -f lib/screens/audio_settings_screen.dart ]] || fail 'Tela de configuracao de audio ausente.'
[[ -f test/audio_slot_catalog_test.dart ]] || fail 'Teste do catalogo de audio ausente.'
grep -q "title: 'Áudios e voz'" lib/screens/settings_screen.dart \
  || fail 'Configuracoes gerais nao expoem Audios e voz.'
grep -q 'audioOverrideSlots' lib/services/native_platform_service.dart \
  || fail 'Flutter nao consulta overrides de audio.'
grep -q 'importAudioOverride' tool/android/MainActivity.kt \
  || fail 'Android nao permite importar audio personalizado.'
grep -q 'startAudioRecording' tool/android/MainActivity.kt \
  || fail 'Android nao permite gravar audio personalizado.'
grep -q 'removeAllAudioOverrides' tool/android/MainActivity.kt \
  || fail 'Android nao permite restaurar todos os audios.'
grep -q 'android.permission.RECORD_AUDIO' tool/AndroidManifest.xml \
  || fail 'Permissao de microfone para gravacao de audio ausente.'
grep -q '\*.m4a' tool/bootstrap_android.sh \
  || fail 'Bootstrap nao reconhece M4A como audio versionado.'
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity atual diverge da copia estavel em tool/android.'
[[ $(find custom_audio -maxdepth 1 -type f -name '*.m4a' | wc -l) -eq 78 ]] \
  || fail 'Biblioteca padrao nao possui 78 M4A.'
[[ $(find android/app/src/main/res/raw -maxdepth 1 -type f -name '*.m4a' | wc -l) -eq 78 ]] \
  || fail 'res/raw nao possui os 78 M4A da biblioteca padrao.'
python3 - <<'PY_AUDIO_CHECK' || fail 'Catalogo de audio diverge dos arquivos M4A.'
import re
from pathlib import Path
text = Path('lib/models/audio_slot.dart').read_text(encoding='utf-8')
ids = re.findall(r"AudioSlotDefinition\(id: '([^']+)'", text)
files = {p.stem for p in Path('custom_audio').glob('*.m4a')}
if len(ids) != 78 or len(set(ids)) != 78:
    raise SystemExit('catalogo nao tem 78 ids unicos')
if set(ids) != files:
    raise SystemExit(f'diferenca catalogo/arquivos: {sorted(set(ids)^files)}')
if sum(1 for item in ids if item.startswith('bike_')) != 64:
    raise SystemExit('quantidade de slots Bike diferente de 64')
PY_AUDIO_CHECK

# Buildfix da tela de audio - 1.0.46
grep -q '^## 1.0.46+46' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.46.'
grep -q 'Evolução 1.0.46' README.md || fail 'README nao documenta 1.0.46.'
grep -q 'Evolução 1.0.46' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.46.'
if grep -q 'person_voice_outlined' lib/screens/audio_settings_screen.dart; then
  fail 'Icone Material incompatível person_voice_outlined reapareceu na tela de audio.'
fi
grep -q 'avatar: Icon(Icons.mic_rounded, size: 16)' lib/screens/audio_settings_screen.dart \
  || fail 'Chip de audio personalizado nao usa um icone Material compativel.'

# Assinatura release permanente - 1.0.47
grep -q '^## 1.0.47+47' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.47.'
grep -q 'Evolução 1.0.47' README.md || fail 'README nao documenta 1.0.47.'
grep -q 'Evolução 1.0.47' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.47.'
grep -q 'ANDROID_KEYSTORE_BASE64:.*secrets.ANDROID_KEYSTORE_BASE64' .github/workflows/android-apk.yml \
  || fail 'Workflow nao consome ANDROID_KEYSTORE_BASE64 dos GitHub Secrets.'
grep -q 'ANDROID_KEYSTORE_PASSWORD:.*secrets.ANDROID_KEYSTORE_PASSWORD' .github/workflows/android-apk.yml \
  || fail 'Workflow nao consome ANDROID_KEYSTORE_PASSWORD dos GitHub Secrets.'
grep -q 'ANDROID_KEY_ALIAS:.*secrets.ANDROID_KEY_ALIAS' .github/workflows/android-apk.yml \
  || fail 'Workflow nao consome ANDROID_KEY_ALIAS dos GitHub Secrets.'
grep -q 'ANDROID_KEY_PASSWORD:.*secrets.ANDROID_KEY_PASSWORD' .github/workflows/android-apk.yml \
  || fail 'Workflow nao consome ANDROID_KEY_PASSWORD dos GitHub Secrets.'
grep -q 'base64 --decode' .github/workflows/android-apk.yml \
  || fail 'Workflow nao reconstrói a keystore a partir do Base64.'
grep -q 'keytool -list' .github/workflows/android-apk.yml \
  || fail 'Workflow nao valida a keystore/alias antes do build.'
grep -q 'apksigner.*verify' .github/workflows/android-apk.yml \
  || fail 'Workflow nao valida a assinatura da APK pronta.'
grep -q 'signingConfigs.getByName("release")' tool/bootstrap_android.sh \
  || fail 'Bootstrap Android nao aplica a signingConfig release.'
grep -q 'ANDROID_KEYSTORE_PATH' tool/bootstrap_android.sh \
  || fail 'Bootstrap Android nao lê o caminho temporario da keystore.'
if grep -q 'signingConfigs.getByName("debug")' android/app/build.gradle.kts; then
  fail 'Assinatura debug reapareceu no build release atual.'
fi
grep -q "text = text.replace('signingConfig = signingConfigs.getByName(\"debug\")', 'signingConfig = signingConfigs.getByName(\"release\")')" tool/bootstrap_android.sh \
  || fail 'Bootstrap nao substitui automaticamente a assinatura debug gerada pelo Flutter.'
grep -q '^\*\.jks$' .gitignore || fail '.gitignore nao bloqueia arquivos JKS.'
grep -q '^\*\.keystore$' .gitignore || fail '.gitignore nao bloqueia arquivos keystore.'
grep -q '^android/key.properties$' .gitignore || fail '.gitignore nao bloqueia android/key.properties.'
if find . -type f \( -name '*.jks' -o -name '*.keystore' \) -not -path './build/*' | grep -q .; then
  fail 'Arquivo de keystore foi incluido no projeto; a chave deve existir apenas nos Secrets.'
fi

# Instrumentacao e orcamento do pipeline da IA - 1.0.52
grep -q '^## 1.0.52+52' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.52.'
grep -q 'Evolução 1.0.52' README.md || fail 'README nao documenta 1.0.52.'
grep -q 'Evolução 1.0.52' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.52.'
[[ -f lib/services/analysis_budget_policy.dart ]] || fail 'Politica de orcamento da analise nao encontrada.'
[[ -f test/analysis_budget_policy_test.dart ]] || fail 'Testes da politica de orcamento nao encontrados.'
grep -q 'class AnalysisBudgetPolicy' lib/services/analysis_budget_policy.dart \
  || fail 'AnalysisBudgetPolicy nao encontrada.'
grep -q 'allowOptionalDetailScan' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController nao protege a varredura opcional por orcamento.'
grep -q '_lastPrimaryInferenceMs' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao mede a inferencia principal.'
grep -q '_lastPostprocessMs' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao mede o pos-processamento.'
grep -q '_lastTotalProcessingMs' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao mede o processamento total.'
grep -q 'processingBudgetUsagePercent' lib/models/session_status.dart \
  || fail 'SessionStatusData nao calcula uso do orcamento.'
grep -q 'pipelineHotspot' lib/models/session_status.dart \
  || fail 'SessionStatusData nao identifica a etapa mais custosa.'
grep -q 'Pipeline da IA' lib/widgets/session_status_panel.dart \
  || fail 'Painel detalhado nao exibe o pipeline da IA.'
grep -q 'Detalhes evitados por orçamento' lib/widgets/session_status_panel.dart \
  || fail 'Painel nao exibe varreduras opcionais evitadas.'
grep -q 'pipeline_budget_critical' test/session_status_test.dart \
  || fail 'Testes nao cobrem estouro do orcamento do pipeline.'

# Saude operacional do Status da sessao - 1.0.51
grep -q '^## 1.0.51+51' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.51.'
grep -q 'Evolução 1.0.51' README.md || fail 'README nao documenta 1.0.51.'
grep -q 'Evolução 1.0.51' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.51.'
grep -q 'enum SessionHealthState' lib/models/session_status.dart \
  || fail 'Estados de saude da sessao nao encontrados.'
grep -q 'class SessionHealthAnalyzer' lib/models/session_status.dart lib/models/session_status_health_analyzer.dart \
  || fail 'Avaliador de saude da sessao nao encontrado.'
grep -q 'framesDroppedProcessing' lib/models/session_status.dart \
  || fail 'Status da sessao nao separa perdas por processamento.'
grep -q 'framesSkippedOptimization' lib/models/session_status.dart \
  || fail 'Status da sessao nao separa otimizacoes intencionais.'
grep -q '_framesDroppedProcessing++' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao contabiliza frames perdidos com IA ocupada.'
grep -q '_framesSkippedOptimization++' lib/controllers/monitor_controller.dart \
  || fail 'Controller nao contabiliza frames pulados pela otimizacao.'
grep -q 'Saúde da sessão' lib/widgets/session_status_panel.dart lib/widgets/session_status_panel_components.dart \
  || fail 'Painel nao exibe a saude da sessao.'
grep -q 'Gargalo provável' lib/widgets/session_status_panel.dart lib/widgets/session_status_panel_components.dart \
  || fail 'Painel nao exibe o gargalo provavel.'
grep -q 'Ocorrências recentes' lib/widgets/session_status_panel.dart lib/widgets/session_status_panel_components.dart \
  || fail 'Painel nao exibe ocorrencias recentes.'
grep -q "processing_drop_critical" test/session_status_test.dart \
  || fail 'Testes nao cobrem perdas reais de processamento.'

# Buildfix do Status da sessao - 1.0.50
grep -q '^## 1.0.50+50' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.50.'
grep -q 'Evolução 1.0.50' README.md || fail 'README nao documenta 1.0.50.'
grep -q 'Evolução 1.0.50' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.50.'
if grep -q '\${frameWidth}' lib/models/session_status.dart; then
  fail 'Interpolacao redundante de frameWidth reapareceu.'
fi
if grep -q '\${analysisWidth}' lib/models/session_status.dart; then
  fail 'Interpolacao redundante de analysisWidth reapareceu.'
fi
if grep -q '\${frameDelayMs}' lib/models/session_status.dart; then
  fail 'Interpolacao redundante de frameDelayMs reapareceu.'
fi

# Status da sessao e telemetria em tempo real - 1.0.49
[[ -f lib/models/session_status.dart ]] || fail 'Modelo SessionStatusData nao encontrado.'
[[ -f lib/widgets/session_status_panel.dart ]] || fail 'Painel Status da sessao nao encontrado.'
[[ -f lib/widgets/session_status_panel_components.dart ]] || fail 'Componentes do Status da sessao nao encontrados.'
[[ -f test/session_status_test.dart ]] || fail 'Teste do resumo de status da sessao nao encontrado.'
grep -q 'SessionStatusData get sessionStatus' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController nao expoe o status consolidado da sessao.'
grep -q '_framesReceived' lib/controllers/monitor_controller.dart \
  || fail 'Contador de frames recebidos nao encontrado.'
grep -q '_framesAnalyzed' lib/controllers/monitor_controller.dart \
  || fail 'Contador de frames analisados nao encontrado.'
grep -q '_lastInferenceMs' lib/controllers/monitor_controller.dart \
  || fail 'Tempo de inferencia nao esta sendo medido.'
grep -q 'Status da sessão' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Acesso ao Status da sessao nao foi adicionado ao Monitor.'
grep -q 'x-vigia-frame-captured-at' lib/services/remote_camera_server_service.dart \
  || fail 'Servidor remoto nao envia timestamp real do frame.'
grep -q 'x-vigia-frame-captured-at' lib/sources/remote_phone_camera_source.dart \
  || fail 'Fonte remota nao preserva timestamp real do frame.'
grep -q 'connectionType' lib/models/device_telemetry.dart \
  || fail 'Telemetria nao expoe o tipo de conexao.'
grep -q 'ACCESS_NETWORK_STATE' tool/AndroidManifest.xml \
  || fail 'Manifest nao permite consultar o estado da rede.'
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity gerada diverge da fonte versionada apos a telemetria 1.0.49.'
grep -q '^## 1.0.49+49' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.49.'
grep -q 'Evolução 1.0.49' README.md || fail 'README nao documenta 1.0.49.'
grep -q 'Evolução 1.0.49' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.49.'

# Correcao de reproducao e layout da biblioteca de audio - 1.0.48
grep -q '^## 1.0.48+48' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.48.'
grep -q 'Evolução 1.0.48' README.md || fail 'README nao documenta 1.0.48.'
grep -q 'Evolução 1.0.48' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.48.'
grep -q 'AudioAttributes.USAGE_MEDIA' tool/android/AlertAudioPlayer.kt \
  || fail 'Player de alertas nao define AudioAttributes de midia.'
grep -q 'next.setAudioAttributes(attributes)' tool/android/AlertAudioPlayer.kt \
  || fail 'Player de alertas nao aplica AudioAttributes ao MediaPlayer.'
grep -q 'class _AudioActionButton extends StatelessWidget' lib/screens/audio_settings_screen.dart \
  || fail 'Botao compacto de audio ausente.'
grep -q "label: 'Trocar'" lib/screens/audio_settings_screen.dart \
  || fail 'Acao Trocar compacta nao encontrada.'
python3 - <<'PY_AUDIO_LAYOUT' || fail 'Layout principal de audio voltou a quebrar em Wrap.'
from pathlib import Path
text = Path('lib/screens/audio_settings_screen.dart').read_text(encoding='utf-8')
start = text.index('class _AudioSlotCard')
end = text.index('class _AudioActionButton')
card = text[start:end]
if 'Wrap(' in card:
    raise SystemExit('Wrap encontrado no card de audio')
if 'Row(' not in card or card.count('_AudioActionButton(') < 3:
    raise SystemExit('linha compacta de tres acoes nao encontrada')
PY_AUDIO_LAYOUT
[[ $(find custom_audio -maxdepth 1 -type f -name '*.m4a' | wc -l) -eq 78 ]] \
  || fail 'Biblioteca 1.0.48 nao possui 78 M4A.'
[[ $(find android/app/src/main/res/raw -maxdepth 1 -type f -name '*.m4a' | wc -l) -eq 78 ]] \
  || fail 'res/raw 1.0.48 nao possui 78 M4A.'
if find custom_audio -maxdepth 1 -type f -name '*.wav' | grep -q .; then
  fail 'WAV PCM antigo ainda esta presente na biblioteca padrao.'
fi
python3 - <<'PY_AUDIO_MIRROR' || fail 'Biblioteca M4A diverge entre custom_audio e res/raw.'
from pathlib import Path
import hashlib
src = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('custom_audio').glob('*.m4a')}
dst = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('android/app/src/main/res/raw').glob('*.m4a')}
if src != dst:
    raise SystemExit('M4A source/raw divergentes')
PY_AUDIO_MIRROR

# Correcao definitiva de reproducao dos audios padrao - 1.0.53
grep -q '^## 1.0.53+53' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.53.'
grep -q 'Evolução 1.0.53' README.md || fail 'README nao documenta 1.0.53.'
grep -q 'Evolução 1.0.53' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.53.'
grep -q 'private fun bundledFile' tool/android/AlertAudioPlayer.kt \
  || fail 'Player nao materializa audio padrao no cache privado.'
grep -q 'resources.openRawResource(request.resource)' tool/android/AlertAudioPlayer.kt \
  || fail 'Audio padrao nao e lido diretamente de res/raw.'
grep -q 'File(context.cacheDir, "bundled_alert_audio/\$stamp")' tool/android/AlertAudioPlayer.kt \
  || fail 'Audio padrao nao usa cache privado do app.'
grep -q 'request.usingOverride = false' tool/android/AlertAudioPlayer.kt \
  || fail 'Fallback padrao nao usa o novo player por arquivo local.'
if grep -q 'android.resource://' tool/android/MainActivity.kt tool/android/AlertAudioPlayer.kt; then
  fail 'Implementacao antiga por URI android.resource reapareceu no player padrao.'
fi
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity gerada diverge da fonte versionada na correcao 1.0.53.'


# HUD Bike e simulador sem ESP32 - 1.0.54
grep -q '^## 1.0.54+54' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.54.'
grep -q 'Evolução 1.0.54' README.md || fail 'README nao documenta 1.0.54.'
grep -q 'Evolução 1.0.54' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.54.'
[[ -f lib/models/bike_sensor_snapshot.dart ]] || fail 'Contrato de sensores da bike nao encontrado.'
[[ -f lib/services/bike_sensor_service.dart ]] || fail 'Servico de sensores/simulador da bike nao encontrado.'
[[ -f lib/widgets/bike_ride_hud.dart ]] || fail 'HUD transparente da bike nao encontrado.'
[[ -f test/bike_sensor_snapshot_test.dart ]] || fail 'Testes dos sensores simulados nao encontrados.'
grep -q 'sensorSimulationEnabled' lib/models/bike_mode_config.dart   || fail 'Configuracao do simulador nao e persistida no Modo Bike.'
grep -q 'Teste do HUD sem ESP32' lib/screens/bike_mode_screen.dart   || fail 'Tela Bike nao oferece teste do HUD sem ESP32.'
grep -q 'BikeRideHud(snapshot:' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart   || fail 'Monitor nao exibe o HUD da bike sobre o video.'
grep -q "'SIMULAÇÃO" lib/widgets/bike_ride_hud.dart   || fail 'HUD simulado nao identifica claramente dados sinteticos.'
if grep -q 'if (primaryIssue != null) primaryIssue' lib/widgets/session_status_panel.dart lib/widgets/session_status_panel_components.dart; then
  fail 'Lint use_null_aware_elements da 1.0.53 reapareceu no Status da sessao.'
fi
grep -q '?primaryIssue' lib/widgets/session_status_panel.dart lib/widgets/session_status_panel_components.dart   || fail 'Buildfix null-aware do Status da sessao nao encontrado.'


# Layout adaptativo e buildfix - 1.0.55
grep -q '^## 1.0.55+55' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.55.'
grep -q 'Evolução 1.0.55' README.md || fail 'README nao documenta 1.0.55.'
grep -q 'Evolução 1.0.55' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.55.'
[[ -f lib/core/adaptive_layout.dart ]] || fail 'Breakpoints adaptativos nao encontrados.'
grep -q 'class AdaptiveMainScaffold' lib/widgets/main_navigation_bar.dart || fail 'Shell adaptativo principal ausente.'
grep -q 'class MainNavigationRail' lib/widgets/main_navigation_bar.dart || fail 'NavigationRail principal ausente.'
grep -q "label: _fillPreview ? 'Preencher' : 'Ajustar'" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'Alternancia Ajustar/Preencher ausente.'
grep -q 'fillPreview: _fillPreview' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'Overlays nao acompanham o modo de preenchimento.'
grep -q 'constraints.maxWidth >= 760' lib/screens/bike_mode_screen.dart || fail 'Modo Bike nao reorganiza a tela larga.'
grep -q 'showCloseButton: true' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'Status da sessao nao usa superficie larga.'
[[ -f test/adaptive_main_scaffold_test.dart ]] || fail 'Teste do shell adaptativo nao encontrado.'
if grep -q 'bikeSnapshot!' lib/screens/monitor_screen.dart; then fail 'Non-null assertion regressivo no HUD Bike.'; fi


# Alerta rapido de aproximacao Bike - 1.0.56
grep -q '^## 1.0.56+56' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.56.'
grep -q 'Evolução 1.0.56' README.md || fail 'README nao documenta 1.0.56.'
grep -q 'Evolução 1.0.56' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.56.'
[[ -f lib/services/bike_approach_estimator.dart ]] || fail 'Estimador de aproximacao Bike ausente.'
[[ -f lib/models/bike_approach_status.dart ]] || fail 'Modelo de aproximacao Bike ausente.'
[[ -f lib/widgets/bike_approach_banner.dart ]] || fail 'Banner de aproximacao Bike ausente.'
[[ -f test/bike_approach_estimator_test.dart ]] || fail 'Teste do estimador de aproximacao ausente.'
grep -q 'BikeSimulationScenario.vehicleApproaching' lib/models/bike_mode_config.dart || fail 'Simulacao de aproximacao nao configurada.'
grep -q '_updateBikeApproachFastPath(primaryGlobalForBike, now);' lib/controllers/monitor_controller.dart || fail 'Caminho rapido Bike nao esta ligado apos a inferencia principal.'
grep -q 'primaryAllowedLabels' lib/controllers/monitor_controller.dart || fail 'Inferencia principal nao separa labels de seguranca Bike.'
grep -q 'BikeApproachBanner(status: approach)' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'Monitor nao exibe alerta visual de aproximacao.'
python3 - <<'PY_BIKE_FAST_PATH' || fail 'Caminho rapido Bike nao ocorre antes das inferencias auxiliares.'
from pathlib import Path
text = Path('lib/controllers/monitor_controller.dart').read_text(encoding='utf-8')
fast = text.index('_updateBikeApproachFastPath(primaryGlobalForBike, now);')
aux = text.index('if (motionResult.hasMotion && !hasUsefulPrimary)', fast)
if fast >= aux:
    raise SystemExit(1)
PY_BIKE_FAST_PATH

# Refatoracao estrutural - 1.0.57
grep -q '^## 1.0.57+57' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.57.'
grep -q 'Evolução 1.0.57' README.md || fail 'README nao documenta 1.0.57.'
grep -q 'Evolução 1.0.57' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.57.'
[[ -f lib/controllers/monitor_controller_session_support.dart ]] || fail 'Modulo de sessao/telemetria do MonitorController ausente.'
[[ -f lib/controllers/monitor_controller_event_support.dart ]] || fail 'Modulo de eventos/alertas do MonitorController ausente.'
[[ -f lib/controllers/monitor_controller_state_support.dart ]] || fail 'Modulo de estado/diagnostico do MonitorController ausente.'
[[ -f lib/screens/monitor_screen_components.dart ]] || fail 'Componentes extraidos do Monitor ausentes.'
[[ -f lib/screens/home_screen_components.dart ]] || fail 'Componentes extraidos da Home ausentes.'
grep -q "part 'monitor_controller_session_support.dart';" lib/controllers/monitor_controller.dart || fail 'MonitorController nao referencia modulo de sessao.'
grep -q "part 'monitor_screen_components.dart';" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'MonitorScreen nao referencia componentes extraidos.'
grep -q "part 'home_screen_components.dart';" lib/screens/home_screen.dart || fail 'HomeScreen nao referencia componentes extraidos.'
python3 - <<'PY_REFACTOR_SIZE' || fail 'Arquivos principais continuam acima do limite preventivo definido para o lote 1.'
from pathlib import Path
limits = {
    'lib/controllers/monitor_controller.dart': 1800,
    'lib/screens/monitor_screen.dart': 1400,
    'lib/screens/home_screen.dart': 850,
}
for filename, limit in limits.items():
    lines = len(Path(filename).read_text(encoding='utf-8').splitlines())
    if lines > limit:
        raise SystemExit(f'{filename}: {lines} > {limit}')
PY_REFACTOR_SIZE


# Refatoracao estrutural - 1.0.58
 grep -q '^## 1.0.58+58' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.58.'
 grep -q 'Evolução 1.0.58' README.md || fail 'README nao documenta 1.0.58.'
 grep -q 'Evolução 1.0.58' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.58.'
 [[ -f lib/screens/multi_camera_screen_components.dart ]] || fail 'Componentes extraidos da Central multicamera ausentes.'
 [[ -f lib/screens/app_info_screen_components.dart ]] || fail 'Componentes extraidos de Informacoes do aplicativo ausentes.'
 [[ -f lib/screens/bike_mode_screen_components.dart ]] || fail 'Componentes extraidos do Modo Bike ausentes.'
 grep -q "part 'multi_camera_screen_components.dart';" lib/screens/multi_camera_screen.dart || fail 'Central multicamera nao referencia componentes extraidos.'
 grep -q "part 'app_info_screen_components.dart';" lib/screens/app_info_screen.dart || fail 'Informacoes do aplicativo nao referencia componentes extraidos.'
 grep -q "part 'bike_mode_screen_components.dart';" lib/screens/bike_mode_screen.dart || fail 'Modo Bike nao referencia componentes extraidos.'
 python3 - <<'PY_REFACTOR2_SIZE' || fail 'Arquivos principais continuam acima do limite preventivo definido para o lote 2.'
from pathlib import Path
limits = {
    'lib/screens/multi_camera_screen.dart': 680,
    'lib/screens/app_info_screen.dart': 130,
    'lib/screens/bike_mode_screen.dart': 470,
}
for filename, limit in limits.items():
    lines = len(Path(filename).read_text(encoding='utf-8').splitlines())
    if lines > limit:
        raise SystemExit(f'{filename}: {lines} > {limit}')
PY_REFACTOR2_SIZE

# Refatoracao estrutural - 1.0.59
grep -q '^## 1.0.59+59' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.59.'
grep -q 'Evolução 1.0.59' README.md || fail 'README nao documenta 1.0.59.'
grep -q 'Evolução 1.0.59' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.59.'
[[ -f lib/widgets/session_status_panel_components.dart ]] || fail 'Componentes extraidos do Status da sessao ausentes.'
[[ -f lib/screens/error_center_screen_components.dart ]] || fail 'Componentes extraidos da Central de diagnostico ausentes.'
[[ -f lib/screens/events_screen_components.dart ]] || fail 'Componentes extraidos do Historico ausentes.'
grep -q "part 'session_status_panel_components.dart';" lib/widgets/session_status_panel.dart || fail 'Status da sessao nao referencia componentes extraidos.'
grep -q "part 'error_center_screen_components.dart';" lib/screens/error_center_screen.dart || fail 'Central de diagnostico nao referencia componentes extraidos.'
grep -q "part 'events_screen_components.dart';" lib/screens/events_screen.dart || fail 'Historico nao referencia componentes extraidos.'
python3 - <<'PY_REFACTOR3_SIZE' || fail 'Arquivos principais continuam acima do limite preventivo definido para o lote 3.'
from pathlib import Path
limits = {
    'lib/widgets/session_status_panel.dart': 320,
    'lib/screens/error_center_screen.dart': 360,
    'lib/screens/events_screen.dart': 420,
}
for filename, limit in limits.items():
    lines = len(Path(filename).read_text(encoding='utf-8').splitlines())
    if lines > limit:
        raise SystemExit(f'{filename}: {lines} > {limit}')
PY_REFACTOR3_SIZE

# Refatoracao estrutural - 1.0.60

grep -q '^## 1.0.60+60' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.60.'
grep -q 'Evolução 1.0.60' README.md || fail 'README nao documenta 1.0.60.'
grep -q 'Evolução 1.0.60' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.60.'
[[ -f lib/models/session_status_health_analyzer.dart ]] || fail 'Analisador de saude da sessao extraido esta ausente.'
[[ -f lib/screens/system_health_screen_components.dart ]] || fail 'Componentes extraidos de Saude do sistema ausentes.'
[[ -f lib/services/object_detection_worker.dart ]] || fail 'Runtime extraido do detector ausente.'
grep -q "part 'session_status_health_analyzer.dart';" lib/models/session_status.dart || fail 'SessionStatus nao referencia analisador extraido.'
grep -q "part 'system_health_screen_components.dart';" lib/screens/system_health_screen.dart || fail 'Saude do sistema nao referencia componentes extraidos.'
grep -q "part 'object_detection_worker.dart';" lib/services/object_detection_service.dart || fail 'Detector nao referencia runtime extraido.'
grep -q 'class SessionHealthAnalyzer' lib/models/session_status_health_analyzer.dart || fail 'Analisador de saude nao foi preservado no modulo extraido.'
grep -q 'DetectorImageTransform.fit' lib/services/detector_input_buffer.dart || fail 'Pre-processamento do detector nao foi preservado no runtime extraido.'
grep -q 'interpreter.runForMultipleInputs' lib/services/object_detection_worker.dart || fail 'Inferencia TFLite nao foi preservada no runtime extraido.'
python3 - <<'PY_REFACTOR4_SIZE' || fail 'Arquivos principais continuam acima do limite preventivo definido para o lote 4.'
from pathlib import Path
limits = {
    'lib/models/session_status.dart': 260,
    'lib/screens/system_health_screen.dart': 440,
    'lib/services/object_detection_service.dart': 280,
}
for filename, limit in limits.items():
    lines = len(Path(filename).read_text(encoding='utf-8').splitlines())
    if lines > limit:
        raise SystemExit(f'{filename}: {lines} > {limit}')
PY_REFACTOR4_SIZE



# Buildfix pós-refatoracao - 1.0.61
grep -q '^## 1.0.61+61' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.61.'
grep -q 'Evolução 1.0.61' README.md || fail 'README nao documenta 1.0.61.'
grep -q 'Evolução 1.0.61' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.61.'
if grep -qE 'Future<void> _refreshSessionTelemetry\(\)|Future<void> _deliverAlert\(|Map<String, Object\?> _zonesDiagnosticContext\(\)' lib/controllers/monitor_controller.dart; then
  fail 'MonitorController ainda contem wrappers privados obsoletos que geram unused_element.'
fi


# Buildfix pós-refatoração - 1.0.63
grep -q '^## 1.0.63+63' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.63.'
grep -q 'Evolução 1.0.63' README.md || fail 'README nao documenta 1.0.63.'
grep -q 'Evolução 1.0.63' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.63.'
if grep -q 'this\._' lib/controllers/monitor_controller.dart; then
  fail 'MonitorController reintroduziu qualificadores this._ desnecessarios.'
fi
grep -q 'run: bash ./tool/bootstrap_android.sh' .github/workflows/android-apk.yml || fail 'Workflow ainda depende do bit executavel de bootstrap_android.sh.'
grep -q 'run: bash ./tool/fetch_model.sh' .github/workflows/android-apk.yml || fail 'Workflow ainda depende do bit executavel de fetch_model.sh.'
grep -q 'run: bash ./tool/verify_project.sh' .github/workflows/android-apk.yml || fail 'Workflow ainda depende do bit executavel de verify_project.sh.'
if grep -qE 'run: \./tool/(bootstrap_android|fetch_model|verify_project)\.sh' .github/workflows/android-apk.yml; then
  fail 'Workflow voltou a executar script shell diretamente sem bash.'
fi



# Telemetria/exportacao/onboarding/layout adaptativo - 1.0.64
grep -q '^## 1.0.64+64' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.64.'
grep -q 'Evolução 1.0.64' README.md || fail 'README nao documenta 1.0.64.'
grep -q 'Evolução 1.0.64' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta 1.0.64.'
[[ -f lib/services/performance_telemetry_service.dart ]] || fail 'Servico de telemetria de desempenho nao encontrado.'
[[ -f lib/services/export_preferences_service.dart ]] || fail 'Preferencia de destino de exportacao nao encontrada.'
[[ -f lib/widgets/export_destination_dialog.dart ]] || fail 'Resolucao do destino de exportacao nao encontrada.'
[[ -f test/performance_telemetry_service_test.dart ]] || fail 'Testes da telemetria de desempenho nao encontrados.'
grep -q 'detectMeasured' lib/services/object_detection_service.dart || fail 'Detector perdeu API de medicao granular.'
grep -q 'liteRtMs' lib/services/object_detection_worker.dart || fail 'Worker nao mede LiteRT puro.'
grep -q 'sourceConversionMs' lib/services/frame_converter.dart || fail 'Conversao da fonte nao esta instrumentada.'
grep -q 'PerformanceTelemetryService.instance' lib/controllers/monitor_controller.dart || fail 'Monitor nao registra telemetria de desempenho.'
grep -q 'Diagnóstico 30 s' lib/screens/error_center_screen_components.dart || fail 'Diagnostico profundo de 30 s nao esta exposto.'
grep -q 'Diagnóstico 60 s' lib/screens/error_center_screen_components.dart || fail 'Diagnostico profundo de 60 s nao esta exposto.'
grep -q "'resumo.txt'" lib/services/performance_telemetry_service.dart || fail 'ZIP de desempenho nao contem resumo.txt.'
grep -q "'telemetria.json'" lib/services/performance_telemetry_service.dart || fail 'ZIP de desempenho nao contem telemetria.json.'
grep -q "'telemetria.csv'" lib/services/performance_telemetry_service.dart || fail 'ZIP de desempenho nao contem telemetria.csv.'
grep -q 'MediaStore.Downloads' tool/android/MainActivity.kt || fail 'Exportacao para Downloads via MediaStore nao encontrada.'
grep -q 'Intent.ACTION_CREATE_DOCUMENT' tool/android/MainActivity.kt || fail 'Seletor nativo de destino nao encontrado.'
grep -q 'noBackupFilesDir' tool/android/MainActivity.kt || fail 'Marcador de onboarding fora de backup nao encontrado.'
grep -q 'home: const _StartupGate()' lib/app/app.dart || fail 'App voltou a abrir AccessGuide como home permanente.'
grep -q 'manualReview: true' lib/screens/settings_screen.dart || fail 'Revisao manual de permissoes nao esta acessivel nas Configuracoes.'
grep -q 'Local padrão de exportação' lib/screens/settings_screen.dart || fail 'Preferencia de destino nao esta nas Configuracoes.'
grep -q 'onTap: onTap ??' lib/widgets/session_status_panel_components.dart || fail 'Detalhes do Status voltaram a depender apenas de bottom sheet empilhado.'
grep -q 'showGeneralDialog<void>' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'Painel lateral do Status em paisagem nao encontrado.'

# Buildfix Android-APK-33 - 1.0.65
if grep -q "import 'dart:typed_data';" lib/services/native_platform_service.dart; then
  fail 'Import dart:typed_data redundante reapareceu em NativePlatformService.'
fi
grep -q 'expect(path, isNotNull);' test/diagnostic_report_service_test.dart \
  || fail 'Teste de diagnostico nao valida retorno nullable da exportacao.'
grep -q 'File(path!);' test/diagnostic_report_service_test.dart \
  || fail 'Teste de diagnostico nao promove o caminho apos validar nao nulo.'
grep -q '^## 1.0.65+65' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.65.'
grep -q 'Evolução 1.0.65' README.md || fail 'README nao documenta 1.0.65.'

# Buildfix Android-APK-34 - 1.0.66
grep -q "expect(value.pipelineHotspot, 'Inferências auxiliares');" test/session_status_test.dart \
  || fail 'Teste do hotspot granular nao foi atualizado para a telemetria atual.'
grep -q '^## 1.0.66+66' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.66.'
grep -q 'Evolução 1.0.66' README.md || fail 'README nao documenta 1.0.66.'

python3 tool/verify_release_67.py || fail 'Regressao das correcoes 1.0.67.'
grep -q '^## 1.0.69+69' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.69.'
grep -q 'Evolução 1.0.69' README.md || fail 'README nao documenta 1.0.69.'
grep -q "version: '1.0.69'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.69.'
grep -q '^## 1.0.70+70' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.70.'
grep -q 'Evolução 1.0.70' README.md || fail 'README nao documenta 1.0.70.'
grep -q "version: '1.0.70'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.70.'
grep -q '^\*\.jks$' .gitignore || fail 'Pacote-fonte 1.0.70 perdeu a protecao JKS.'

# Transporte remoto, HUD operacional e audio - 1.0.71
grep -q '^## 1.0.71+71' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.71.'
grep -q 'Evolução 1.0.71' README.md || fail 'README nao documenta 1.0.71.'
grep -q "version: '1.0.71'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.71.'
[[ -f RELEASE-1.0.71.md ]] || fail 'Notas da entrega 1.0.71 ausentes.'
[[ -f test/remote_phone_camera_source_test.dart ]] || fail 'Teste da camera remota ausente.'
grep -q "statusCode = HttpStatus.noContent" lib/services/remote_camera_server_service.dart \
  || fail 'Servidor remoto nao evita retransmitir quadro repetido.'
grep -q "response.statusCode == HttpStatus.noContent" lib/sources/remote_phone_camera_source.dart \
  || fail 'Receptor remoto nao trata ausencia de quadro novo.'
grep -q 'class _DeviceStatusStrip' lib/screens/monitor_screen_components.dart \
  || fail 'Faixa permanente dos aparelhos ausente.'
grep -q 'AudioResourceCatalog.all' tool/android/MainActivity.kt \
  || fail 'Audio padrao nao usa o catalogo Android compilado.'
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity Android diverge da fonte versionada.'

# Buildfix do analyze e decisao de produto - 1.0.72
grep -q '^## 1.0.72+72' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.72.'
grep -q 'Evolução 1.0.72' README.md || fail 'README nao documenta 1.0.72.'
grep -q "version: '1.0.72'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.72.'
[[ -f RELEASE-1.0.72.md ]] || fail 'Notas da entrega 1.0.72 ausentes.'
grep -q "'device': telemetry.toJson()" lib/services/remote_camera_server_service.dart \
  || fail 'Buildfix 1.0.72 perdeu a serializacao sem operador nulo desnecessario.'
if grep -q "import 'dart:async';" test/remote_phone_camera_source_test.dart; then
  fail 'Buildfix 1.0.72 perdeu a remocao do import dart:async redundante.'
fi
grep -q 'mini mapa/GPS deve ficar no aparelho receptor' RELEASE-1.0.72.md \
  || fail 'Decisao do mini mapa no receptor nao foi documentada.'

# Selecao inicial de modo - 1.0.73
grep -q '^## 1.0.73+73' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.73.'
grep -q 'Evolução 1.0.73' README.md || fail 'README nao documenta 1.0.73.'
grep -q "version: '1.0.73'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.73.'
[[ -f RELEASE-1.0.73.md ]] || fail 'Notas da entrega 1.0.73 ausentes.'
[[ -f lib/services/app_launch_mode_service.dart ]] || fail 'Servico de modo inicial ausente.'
[[ -f lib/screens/launch_mode_screen.dart ]] || fail 'Tela de escolha de modo ausente.'
[[ -f test/app_launch_mode_service_test.dart ]] || fail 'Teste do modo inicial ausente.'
grep -q 'AppLaunchMode.normal' lib/screens/launch_mode_screen.dart \
  || fail 'Escolha de modo nao inclui Normal.'
grep -q 'AppLaunchMode.bike' lib/screens/launch_mode_screen.dart \
  || fail 'Escolha de modo nao inclui Bike.'
grep -q 'AppLaunchMode.transmission' lib/screens/launch_mode_screen.dart \
  || fail 'Escolha de modo nao inclui Transmissao.'
grep -q 'launch_mode.json' lib/services/app_launch_mode_service.dart \
  || fail 'Modo inicial nao esta persistido em arquivo proprio.'
grep -q 'const LaunchModeScreen()' lib/app/app.dart \
  || fail 'StartupGate nao abre escolha de modo quando ainda nao ha selecao.'
grep -q 'LaunchModeScreen(manualReview: true)' lib/screens/settings_screen.dart \
  || fail 'Configuracoes nao permite trocar o modo inicial.'

# Paisagem limpa, saida e Modo Camera - 1.0.74
grep -q '^## 1.0.74+74' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.74.'
grep -q 'Evolução 1.0.74' README.md || fail 'README nao documenta 1.0.74.'
grep -q "version: '1.0.74'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.74.'
[[ -f RELEASE-1.0.74.md ]] || fail 'Notas da entrega 1.0.74 ausentes.'
grep -q 'extendBodyBehindAppBar: landscape || _fullscreen' lib/screens/monitor_screen.dart \
  || fail 'Monitor nao remove AppBar fixa em paisagem.'
grep -q 'class _CompactMonitorTopHud' lib/screens/monitor_screen_components.dart \
  || fail 'HUD superior compacto da paisagem ausente.'
grep -q 'Sair do monitoramento' lib/screens/monitor_screen_components.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Saida explicita do monitoramento ausente.'
grep -q 'forceFill = _fullscreen' lib/screens/monitor_screen.dart \
  || fail 'Preview nao força preenchimento em paisagem/tela cheia.'
grep -q 'class _CameraStandbyPanel' lib/screens/camera_mode_screen.dart \
  || fail 'Estado visual integrado do Modo Camera ausente.'
grep -q 'class _CameraModeControlPanel' lib/screens/camera_mode_screen.dart \
  || fail 'Painel adaptativo do Modo Camera ausente.'
grep -q 'Sair do Modo Câmera' lib/screens/camera_mode_screen.dart \
  || fail 'Saida clara do Modo Camera ausente.'
grep -q 'AccessGuideScreen' lib/screens/access_guide_screen.dart lib/app/app.dart \
  || fail 'Fluxo de permissoes antes da escolha de modo nao esta preservado.'
cmp -s tool/android/AlertAudioPlayer.kt android/app/src/main/kotlin/com/vigiaia/app/AlertAudioPlayer.kt \
  || fail 'AlertAudioPlayer Android diverge da fonte versionada.'

# Fluxo inicial receptor/transmissor - 1.0.76
grep -q '^## 1.0.76+76' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.76.'
grep -q 'Evolução 1.0.76' README.md || fail 'README nao documenta 1.0.76.'
grep -q "version: '1.0.76'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.76.'
[[ -f RELEASE-1.0.76.md ]] || fail 'Notas da entrega 1.0.76 ausentes.'
grep -q 'monitor,' lib/services/app_launch_mode_service.dart || fail 'AppLaunchMode nao inclui monitor.'
grep -q 'MonitorConnectScreen' lib/app/app.dart lib/screens/launch_mode_screen.dart \
  || fail 'Modo Monitor nao esta ligado ao fluxo inicial.'
grep -q "VideoSourceType.remotePhone" lib/screens/monitor_connect_screen.dart \
  || fail 'Modo Monitor nao abre fonte Celular remoto.'
grep -q 'Modo Monitor' lib/screens/settings_screen.dart lib/screens/launch_mode_screen.dart \
  || fail 'Textos do modo Monitor nao estao expostos.'

# Buildfix e telemetria de audio - 1.0.75
grep -q '^## 1.0.75+75' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.75.'
grep -q "version: '1.0.75'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.75.'
[[ -f RELEASE-1.0.75.md ]] || fail 'Notas da entrega 1.0.75 ausentes.'
if grep -q "_copy(address!, 'Endereço')" lib/screens/camera_mode_screen.dart; then
  fail 'Operador nulo desnecessario do Android-APK-43 reapareceu.'
fi
grep -q 'audio_focus_not_granted' tool/android/AlertAudioPlayer.kt \
  || fail 'Telemetria de foco de audio negado ausente.'
grep -q 'mediaErrorExtraName' tool/android/AlertAudioPlayer.kt \
  || fail 'Interpretacao dos codigos MediaPlayer ausente.'
grep -q 'lastErrorPhase' tool/android/AlertAudioPlayer.kt lib/services/performance_telemetry_service.dart \
  || fail 'Etapa real da falha de audio nao chega ao relatorio.'
grep -q "source: 'Áudio nativo'" lib/services/native_platform_service.dart \
  || fail 'Falha de audio nao e persistida na Central de Diagnostico.'
grep -q "'schemaVersion': 3" lib/services/performance_telemetry_service.dart \
  || fail 'Telemetria de desempenho nao usa o esquema 3.'

# Recursos de audio compilados - 1.0.77
python3 tool/verify_audio_resource_catalog.py \
  || fail 'Catalogo Android de audio diverge dos slots ou arquivos M4A.'
cmp -s tool/android/AudioResourceCatalog.kt android/app/src/main/kotlin/com/vigiaia/app/AudioResourceCatalog.kt \
  || fail 'AudioResourceCatalog Android diverge da fonte versionada.'
if grep -Eq 'getIdentifier|R\.raw::class\.java\.getField' tool/android/MainActivity.kt; then
  fail 'Resolucao dinamica de audio Android reapareceu.'
fi
grep -q 'bundledResourceCount' tool/android/AlertAudioPlayer.kt \
  || fail 'Diagnostico nao informa cobertura do catalogo de audio.'
grep -q 'bundledMissingSlots' tool/android/AlertAudioPlayer.kt \
  || fail 'Diagnostico nao informa recursos de audio ausentes.'
grep -q '^## 1.0.77+77' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.77.'
grep -q 'Evolução 1.0.77' README.md || fail 'README nao documenta 1.0.77.'
grep -q "version: '1.0.77'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.77.'
[[ -f RELEASE-1.0.77.md ]] || fail 'Notas da entrega 1.0.77 ausentes.'

echo 'Verificacao preventiva concluida com sucesso.'
