#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "ERRO DE VERIFICACAO: $*" >&2
  exit 1
}

grep -q '^name: vigiaia$' pubspec.yaml || fail 'Nome tecnico Dart esperado vigiaia nao encontrado.'
grep -q '^version: 1\.0\.31+31$' pubspec.yaml || fail 'Versao esperada 1.0.31+31 nao encontrada.'
if grep -q "import 'dart:ui';" lib/main.dart; then
  fail 'Import dart:ui redundante reapareceu em lib/main.dart.'
fi
grep -q 'required this.sourceConfig' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController deve usar initializing formal para sourceConfig.'

if grep -q 'separatorBuilder: (_, __)' lib/screens/events_screen.dart; then
  fail 'Placeholder duplo desnecessario reapareceu em EventsScreen.'
fi
if grep -q 'errorBuilder: (_, __, ___)' lib/screens/events_screen.dart; then
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

grep -q "package:flutter_litert/flutter_litert.dart" lib/services/object_detection_service.dart \
  || fail 'ObjectDetectionService nao esta usando flutter_litert.'
grep -q "flutter_litert/flutter_litert.dart' hide Detection" lib/services/object_detection_service.dart \
  || fail 'Import do flutter_litert deve ocultar Detection para evitar conflito com o modelo local.'
grep -q "ssd_mobilenet_v1.tflite" lib/services/object_detection_service.dart \
  || fail 'Detector nao esta apontando para o SSD MobileNet V1 compativel.'
grep -q 'TensorType.uint8' lib/services/object_detection_service.dart \
  || fail 'Pre-processamento uint8 do modelo SSD nao foi encontrado.'

grep -q 'SettingsScreen' lib/screens/monitor_screen.dart \
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
grep -q 'MonitoringZoneOverlay' lib/screens/monitor_screen.dart \
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
grep -q 'showObjectFilterDialog' lib/screens/monitor_screen.dart \
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
grep -q 'showSmartAlertRulesDialog' lib/screens/monitor_screen.dart \
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
[[ -f lib/widgets/detection_overlay.dart ]] \
  || fail 'Overlay de caixas de deteccao nao encontrado.'
[[ -f test/monitor_event_test.dart ]] \
  || fail 'Teste de serializacao de eventos nao encontrado.'
grep -q '_recordConfirmedEvents' lib/controllers/monitor_controller.dart \
  || fail 'Eventos confirmados nao estao ligados ao anti-repeticao.'
grep -q 'EventHistoryService.instance' lib/controllers/monitor_controller.dart \
  || fail 'Historico nao esta ligado ao MonitorController.'
grep -q 'DetectionOverlay' lib/screens/monitor_screen.dart \
  || fail 'Caixas de deteccao nao estao ligadas ao preview.'
grep -q 'EventsScreen' lib/screens/home_screen.dart \
  || fail 'Historico de eventos nao esta acessivel pela Home.'
grep -q 'maxEvents = 200' lib/services/event_history_service.dart \
  || fail 'Limite preventivo do historico nao foi encontrado.'
grep -q 'repeatWhilePresent: false' lib/controllers/monitor_controller.dart \
  || fail 'TTS ainda pode repetir durante o mesmo evento.'
grep -q 'motionConfirmationHits' lib/models/video_source_config.dart \
  || fail 'Confirmacao de movimento nao esta configurada.'
grep -q 'return Center(child: CameraPreview(controller));' lib/sources/local_camera_source.dart \
  || fail 'Preview local deve deixar CameraPreview controlar a proporcao nativa.'
grep -q '_waitForProcessing' lib/controllers/monitor_controller.dart \
  || fail 'Encerramento nao aguarda inferencia em andamento.'
[[ -f lib/services/motion_detection_service.dart ]] \
  || fail 'Servico de deteccao de movimento nao encontrado.'
[[ -f test/motion_detection_service_test.dart ]] \
  || fail 'Testes do filtro de movimento nao encontrados.'

if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  fail 'Teste padrao MyApp reapareceu.'
fi

[[ -f assets/models/ssd_mobilenet_v1.tflite ]] || fail 'Modelo .tflite nao encontrado.'
MODEL_SIZE=$(wc -c < assets/models/ssd_mobilenet_v1.tflite)
if (( MODEL_SIZE < 1048576 )); then
  if grep -qx 'MODEL_DOWNLOADED_IN_CI' assets/models/ssd_mobilenet_v1.tflite; then
    echo 'Modelo em modo fonte: sera baixado por tool/fetch_model.sh antes do build.'
  else
    fail 'Modelo .tflite parece incompleto.'
  fi
fi


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
grep -q 'ZoneTransitionType.entered' lib/controllers/monitor_controller.dart \
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
grep -q "label: 'Áreas'" lib/screens/monitor_screen.dart \
  || fail 'Acao direta de Areas nao encontrada no monitor.'
grep -q "label: 'Objetos'" lib/screens/monitor_screen.dart \
  || fail 'Acao direta de Objetos nao encontrada no monitor.'
grep -q '_buildLandscape' lib/screens/monitor_screen.dart \
  || fail 'Layout paisagem do monitor nao encontrado.'
grep -q "Text('Diagnóstico'" lib/screens/error_center_screen.dart \
  || fail 'Tela visual de Diagnostico nao encontrada.'
grep -q '_HistoryCard' lib/screens/events_screen.dart \
  || fail 'Cards do novo Historico nao foram encontrados.'

# Interface e informacoes 1.0.17
[[ -f lib/screens/settings_screen.dart ]] || fail 'Tela de Ajustes nao encontrada.'
[[ -f lib/screens/app_info_screen.dart ]] || fail 'Tela Sobre/Mudancas/Doacoes nao encontrada.'
[[ -f lib/widgets/main_navigation_bar.dart ]] || fail 'Navegacao principal nao encontrada.'
grep -q 'adriedson@outlook.com' lib/core/app_metadata.dart \
  || fail 'Chave PIX esperada nao encontrada nos metadados do app.'
grep -q 'COPIAR CHAVE PIX' lib/screens/app_info_screen.dart \
  || fail 'Botao para copiar PIX nao encontrado.'
grep -q '_detectionsExpanded' lib/screens/monitor_screen.dart \
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
grep -q "static const String version = '1.0.31';" lib/core/app_metadata.dart \
  || fail 'AppMetadata nao esta em 1.0.31.'
grep -q 'static const int build = 31;' lib/core/app_metadata.dart \
  || fail 'Build de AppMetadata nao esta em 31.'
grep -q "version: '1.0.31'" lib/screens/app_info_screen.dart \
  || fail 'Tela Mudancas nao marca a versao 1.0.31.'

[[ -f lib/models/alert_preferences.dart ]] || fail 'Preferencias configuraveis de alerta nao encontradas.'
[[ -f lib/screens/alerts_clips_screen.dart ]] || fail 'Tela Alertas e clipes nao encontrada.'
grep -q 'ClipFormatPreference.mp4WithGifFallback' lib/models/video_source_config.dart \
  || fail 'Preferencia MP4 com fallback GIF nao encontrada.'
grep -q 'encodeMp4' lib/services/clip_recorder_service.dart \
  || fail 'ClipRecorderService nao tenta gerar MP4.'
grep -q 'MediaMuxer' tool/android/MainActivity.kt \
  || fail 'Encoder MP4 nativo via MediaMuxer nao encontrado.'
grep -q "endsWith('.mp4')" lib/screens/events_screen.dart \
  || fail 'Historico nao reconhece clipes MP4.'
grep -q 'VlcPlayerController' lib/screens/events_screen.dart \
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
grep -q 'START_NOT_STICKY' tool/android/MonitoringForegroundService.kt \
  || fail 'Foreground Service deve evitar reinicio orfao sem o pipeline Flutter.'
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
grep -q "'\${detection.label}#\${tracked.trackId}'" lib/controllers/monitor_controller.dart \
  || fail 'Anti-repeticao nao considera trackId.'
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
grep -q 'cameraId: sourceConfig.cameraId' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController nao associa novos eventos ao cameraId.'
grep -q 'probeAll(' lib/services/camera_registry_service.dart \
  || fail 'Probe paralelo da Central multicamera nao encontrado.'
grep -q '_automaticRefreshInterval = Duration(seconds: 15)' lib/screens/multi_camera_screen.dart \
  || fail 'Atualizacao automatica de 15 s da Central nao encontrada.'
grep -q 'Editar / renomear' lib/screens/multi_camera_screen.dart \
  || fail 'Edicao/renomeacao de camera nao encontrada.'
grep -q "value == 'toggle'" lib/screens/multi_camera_screen.dart \
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
grep -q '^version: 1.0.31+31$' pubspec.yaml \
  || fail 'pubspec.yaml nao esta em 1.0.31+31.'

# Identidade tecnica 1.0.28
grep -q '^name: vigiaia$' pubspec.yaml \
  || fail 'Pacote Dart nao usa vigiaia.'
grep -q '"projectName": "vigiaia"' app_identity.json \
  || fail 'app_identity.json nao usa projectName vigiaia.'
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
grep -q 'START_NOT_STICKY' tool/android/MonitoringForegroundService.kt \
  || fail 'Foreground service pode renascer orfao.'
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
grep -q "case '/stream.mjpg'" lib/services/monitor_lan_stream_service.dart \
  || fail 'Endpoint MJPEG do monitor nao encontrado.'
grep -q 'publishFrame(frame)' lib/controllers/monitor_controller.dart \
  || fail 'Frames do monitor nao sao publicados na LAN.'
grep -q 'await ensureLanStreaming();' lib/controllers/monitor_controller.dart \
  || fail 'Servidor LAN nao inicia junto com a fonte.'
grep -q 'await _lanStream.stop();' lib/controllers/monitor_controller.dart \
  || fail 'Servidor LAN nao encerra junto com a fonte.'
grep -q "tooltip: 'Rede local'" lib/screens/monitor_screen.dart \
  || fail 'Acesso a Rede local nao aparece no monitor.'
grep -q 'NEARBY_WIFI_DEVICES' tool/AndroidManifest.xml \
  || fail 'Permissao NEARBY_WIFI_DEVICES nao declarada.'
grep -q 'ACCESS_LOCAL_NETWORK' tool/AndroidManifest.xml \
  || fail 'Permissao ACCESS_LOCAL_NETWORK nao declarada.'
grep -q 'requestLocalNetworkPermission' tool/android/MainActivity.kt \
  || fail 'Bridge nativa de permissao LAN nao encontrada.'
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
grep -q 'Adicionar outra câmera não ativa contador' lib/screens/multi_camera_screen.dart \
  || fail 'Central multicamera nao explica independencia da contagem.'
grep -q 'Entrada e saída' lib/screens/monitor_screen.dart \
  || fail 'Monitor nao explica entrada/saida.'
grep -q '^## 1.0.24+24' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.24.'
grep -q 'Evolução 1.0.24' README.md || fail 'README nao documenta 1.0.24.'
grep -q 'Interface e domínio de detecção 1.0.24' ARCHITECTURE.md \
  || fail 'ARCHITECTURE nao documenta a fronteira dos tres grupos.'

echo 'Verificacao preventiva concluida com sucesso.'

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
grep -q "Transmissão LAN ativa" lib/screens/system_health_screen.dart || fail 'Saude nao exibe a transmissao LAN.'
grep -q "StorageSizeFormatter.formatBytes" lib/screens/storage_backup_screen.dart || fail 'Armazenamento nao usa o formatador unico.'
grep -q '"shareText"' tool/android/MainActivity.kt || fail 'Bridge nativa de compartilhamento nao encontrada.'
grep -q 'freeStorageBytes' tool/android/MainActivity.kt || fail 'Metricas Android nao usam bytes.'
grep -q '^## 1.0.31+31' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.31.'
grep -q 'Evolução 1.0.31' README.md || fail 'README nao documenta 1.0.31.'
grep -q 'Diagnóstico e saúde real 1.0.29' ARCHITECTURE.md || fail 'ARCHITECTURE nao documenta a Etapa 4.'

# Regressão Android APK 3: a chave LAN deve usar percent-encoding canônico (%20),
# não application/x-www-form-urlencoded (+), para manter o contrato do endereço exibido.
grep -q 'Uri.encodeComponent(accessKey)' lib/services/monitor_lan_stream_service.dart \
  || fail 'URL LAN nao usa Uri.encodeComponent para a chave compartilhada.'
grep -q 'Uri.encodeComponent(_accessKey)' lib/services/monitor_lan_stream_service.dart \
  || fail 'Pagina LAN nao usa a mesma codificacao da chave no stream MJPEG.'
! grep -q 'Uri.encodeQueryComponent(accessKey)' lib/services/monitor_lan_stream_service.dart \
  || fail 'Codificacao antiga da chave LAN ainda esta presente.'
