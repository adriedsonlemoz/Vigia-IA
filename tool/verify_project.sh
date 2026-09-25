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
grep -Fxq 'version: 1.0.131+131' pubspec.yaml || fail 'Versao esperada 1.0.131+131 nao encontrada.'
grep -q 'class Esp32CapabilityObservation' lib/models/esp32_capability_status.dart || fail 'Modelo de estado por sensor ESP32 1.0.124 ausente.'
grep -q 'Esp32CapabilityActivity.live' lib/screens/esp32_settings_screen.dart || fail 'Tela ESP32 nao renderiza estado de leitura ativa 1.0.124.'
grep -q 'Detectado · não configurado' lib/models/esp32_capability_status.dart || fail 'Estado de sensor novo ESP32 1.0.124 ausente.'
grep -q 'firmware legado' test/esp32_capability_status_test.dart || fail 'Teste de inferencia ESP32 legado 1.0.124 ausente.'
grep -Fq '## 1.0.131+131' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.131.'
[[ -f RELEASE-1.0.131.md ]] || fail 'Notas da entrega 1.0.131 ausentes.'
grep -q 'extendBody: true' lib/screens/map_monitoring_screen.dart || fail 'Mapa 1.0.125 nao usa superficie edge-to-edge.'
grep -q "tooltip: 'Aumentar zoom'" lib/screens/map_monitoring_screen.dart || fail 'Controle flutuante de zoom 1.0.125 ausente.'
grep -q "title: const Text('Próximos pontos')" lib/screens/map_monitoring_screen.dart || fail 'Acesso a Proximos pontos no mapa ausente.'
grep -q 'initialPointOfInterest' lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen.dart || fail 'Foco de POI entre lista e mapa 1.0.125 ausente.'
grep -q 'automaticRefreshDistanceMeters = 1500' lib/services/route_explorer_service.dart || fail 'Atualizacao automatica por deslocamento 1.0.125 ausente.'
grep -q 'automaticRefreshInterval = Duration(minutes: 5)' lib/services/route_explorer_service.dart || fail 'Atualizacao automatica temporal 1.0.125 ausente.'
grep -q 'maximumContinuousStepMeters = 250' lib/services/map_route_service.dart || fail 'Protecao contra salto de GPS 1.0.125 ausente.'
[[ -f test/map_navigation_policy_test.dart ]] || fail 'Testes de politica do mapa 1.0.125 ausentes.'
[[ -f lib/services/map_gps_filter.dart ]] || fail 'Filtro de GPS 1.0.126 ausente.'
grep -q 'maximumAcceptedAccuracyMeters = 60' lib/services/map_gps_filter.dart || fail 'Limite de precisao do mapa 1.0.126 ausente.'
grep -q 'maximumRecordingAccuracyMeters = 35' lib/services/map_gps_filter.dart || fail 'Limite de precisao da gravacao 1.0.126 ausente.'
grep -q 'maximumPlausibleSpeedMetersPerSecond = 70' lib/services/map_gps_filter.dart || fail 'Filtro de velocidade plausivel 1.0.126 ausente.'
grep -q 'Future<bool> startRecording()' lib/services/map_route_service.dart || fail 'API Gravar percurso 1.0.126 ausente.'
grep -q 'MapNavigationTarget' lib/services/map_route_service.dart lib/screens/map_monitoring_screen.dart || fail 'Destino separado da gravacao 1.0.126 ausente.'
grep -q "label: Text(recording ? 'Encerrar percurso' : 'Gravar percurso')" lib/screens/map_monitoring_screen.dart || fail 'Nomenclatura Gravar percurso 1.0.126 ausente.'
grep -q "label: const Text('Navegar até')" lib/screens/map_monitoring_screen.dart || fail 'Acao Navegar ate 1.0.126 ausente.'
[[ -f test/map_gps_filter_test.dart ]] || fail 'Testes do filtro GPS 1.0.126 ausentes.'
[[ -f test/map_navigation_target_test.dart ]] || fail 'Teste do destino de navegacao 1.0.126 ausente.'
[[ -f lib/services/map_view_policy.dart ]] || fail 'Politica da camera do mapa 1.0.127 ausente.'
[[ -f lib/services/map_view_settings_service.dart ]] || fail 'Persistencia visual do mapa 1.0.127 ausente.'
[[ -f test/map_view_policy_test.dart ]] || fail 'Testes da camera do mapa 1.0.127 ausentes.'
grep -q 'MapOrientationMode.headingUp' lib/screens/map_monitoring_screen.dart || fail 'Modo acompanhar direcao 1.0.127 ausente.'
grep -q 'offset: Offset(0, _followOffsetY)' lib/screens/map_monitoring_screen.dart || fail 'Visao a frente 1.0.127 nao usa offset de camera.'
grep -q 'CameraFit.coordinates' lib/screens/map_monitoring_screen.dart || fail 'Visao Rota 1.0.127 nao enquadra o percurso.'
grep -q 'class _MapQuickViewBar' lib/screens/map_monitoring_screen.dart || fail 'Atalhos Perto/Regiao/Rota 1.0.127 ausentes.'
grep -q 'current.recordedAt != _lastFollowCameraPointAt' lib/screens/map_monitoring_screen.dart || fail 'Camera 1.0.127 voltou a mover sem GPS novo.'
grep -q 'InteractiveFlag.all & ~InteractiveFlag.rotate' lib/screens/map_monitoring_screen.dart || fail 'Norte fixo 1.0.127 permite rotacao gestual indevida.'
! grep -q 'Icons.offline_map_rounded' lib/screens/map_monitoring_screen.dart || fail 'Icone offline_map_rounded invalido voltou ao mapa.'
grep -q 'Icons.download_for_offline_outlined' lib/screens/map_monitoring_screen.dart || fail 'Buildfix 1.0.128 do icone de mapas offline ausente.'
grep -q 'enum MapStylePreset' lib/services/map_view_settings_service.dart || fail 'MapStylePreset 1.0.129 ausente.'
grep -q 'MapStylePreset.bikeTravel' lib/screens/map_monitoring_screen.dart || fail 'Camada Bike/Viagem 1.0.129 ausente.'
grep -q 'MapStylePreset.topographic' lib/screens/map_monitoring_screen.dart || fail 'Camada Topografica 1.0.129 ausente.'
grep -q 'stamen_terrain' lib/screens/map_monitoring_screen.dart || fail 'Camada Terreno 1.0.129 ausente.'
grep -q 'alidade_satellite' lib/screens/map_monitoring_screen.dart || fail 'Camada Satelite 1.0.129 ausente.'
grep -q "message: 'Camadas e tipo do mapa'" lib/screens/map_monitoring_screen.dart || fail 'Controle de camadas 1.0.129 ausente.'
grep -q "tooltip: 'Opções do mapa'" lib/screens/map_monitoring_screen.dart || fail 'Menu Opcoes 1.0.129 ausente.'
[[ -f lib/models/offline_poi_package.dart ]] || fail 'OfflinePoiPackage 1.0.129 ausente.'
grep -q 'offlinePackages' lib/services/route_explorer_service.dart || fail 'Pacotes offline de POI 1.0.129 ausentes.'
grep -q 'Lista offline antiga' lib/services/route_explorer_service.dart || fail 'Migracao da lista offline antiga 1.0.129 ausente.'
grep -q 'automaticRefreshHeadingChangeDegrees = 50' lib/services/route_explorer_service.dart || fail 'Atualizacao automatica por heading 1.0.129 ausente.'
! grep -q '_routeState.tracking ||' lib/services/route_explorer_service.dart || fail 'Busca automatica continua dependente da gravacao.'
grep -q 'class _SelectedPoiCard' lib/screens/map_monitoring_screen.dart || fail 'Card compacto do POI 1.0.129 ausente.'
[[ -f test/offline_poi_package_test.dart ]] || fail 'Teste de pacotes offline de POI 1.0.129 ausente.'
[[ -f test/map_style_preset_test.dart ]] || fail 'Teste de estilos do mapa 1.0.129 ausente.'
[[ -f lib/services/map_camera_overlay_settings_service.dart ]] || fail 'Persistencia dos PiPs do mapa 1.0.130 ausente.'
grep -q 'Future<void> _showCameraSourcePicker' lib/screens/map_monitoring_screen.dart || fail 'Seletor de fonte das cameras do mapa 1.0.130 ausente.'
grep -q 'SecondaryCameraController' lib/screens/map_monitoring_screen.dart || fail 'Mapa 1.0.130 nao cria visualizacoes leves de camera.'
grep -Fq 'cameraPreviewBuilder: (_) => _controller.buildPreview()' lib/screens/monitor_screen.dart || fail 'Mapa 1.0.130 nao reutiliza a camera atual do Monitor.'
grep -q 'releaseLocationIfIdle' lib/services/map_route_service.dart || fail 'Liberacao de GPS ocioso 1.0.130 ausente.'
grep -q 'locationConsumers' lib/services/map_route_service.dart || fail 'Contagem de consumidores GPS 1.0.130 ausente.'
! grep -q '_elapsedTimer' lib/services/map_route_service.dart || fail 'Ticker global de 1 Hz voltou ao MapRouteService.'
grep -q '_LiveRouteElapsedPill' lib/screens/map_monitoring_screen.dart || fail 'Cronometro isolado do mapa 1.0.130 ausente.'
grep -q 'maximumDisplayPoints = 2200' lib/screens/map_monitoring_screen.dart || fail 'Reducao visual de percurso longo 1.0.130 ausente.'
grep -q '_lastHandledRoutePointAt' lib/services/route_explorer_service.dart || fail 'RouteExplorer voltou a recalcular sem GPS novo.'
[[ -f test/map_camera_overlay_settings_test.dart ]] || fail 'Teste de layout dos PiPs 1.0.130 ausente.'
[[ -f lib/services/map_ux_policy.dart ]] || fail 'MapUxPolicy 1.0.131 ausente.'
[[ -f test/map_ux_policy_test.dart ]] || fail 'Teste de UX do mapa 1.0.131 ausente.'
grep -q 'class _MapZoomCluster' lib/screens/map_monitoring_screen.dart || fail 'Cluster de zoom 1.0.131 ausente.'
grep -q 'class _CameraPipMenuButton' lib/screens/map_monitoring_screen.dart || fail 'Menu compacto dos PiPs 1.0.131 ausente.'
grep -q 'resetLayout' lib/services/map_camera_overlay_settings_service.dart || fail 'Restauracao de layout dos PiPs 1.0.131 ausente.'
grep -q 'updateOfflinePackage' lib/services/route_explorer_service.dart || fail 'Atualizacao segura de pacote offline 1.0.131 ausente.'
grep -q 'MapUxPolicy.cameraBottomReserve' lib/screens/map_monitoring_screen.dart || fail 'PiPs 1.0.131 nao respeitam overlays inferiores.'
grep -q "message: 'Camadas e tipo do mapa'" lib/screens/map_monitoring_screen.dart || fail 'Acesso a camadas 1.0.131 ausente do chip superior.'
if grep -q "import 'dart:typed_data';" lib/screens/map_monitoring_screen.dart; then
  fail 'Import dart:typed_data redundante reapareceu em MapMonitoringScreen (Android-APK-73).'
fi
if grep -q "import 'package:camera/camera.dart';" lib/sources/local_camera_source.dart; then
  fail 'Import camera nao utilizado reapareceu em LocalCameraSource (Android-APK-73).'
fi
if grep -q "import 'dart:ui';" lib/main.dart; then
  fail 'Import dart:ui redundante reapareceu em lib/main.dart.'
fi
grep -q 'required this.sourceConfig' lib/controllers/monitor_controller.dart \
  || fail 'MonitorController deve usar initializing formal para sourceConfig.'

if grep -q 'separatorBuilder: (_, __)' lib/screens/events_screen.dart lib/screens/events_screen_components.dart lib/screens/events_screen_actions.dart; then
  fail 'Placeholder duplo desnecessario reapareceu em EventsScreen.'
fi
if grep -q 'errorBuilder: (_, __, ___)' lib/screens/events_screen.dart lib/screens/events_screen_components.dart lib/screens/events_screen_actions.dart; then
  fail 'Placeholders multiplos desnecessarios reapareceram em EventsScreen.'
fi
if grep -q 'separatorBuilder: (_, __)' lib/screens/monitor_screen_portrait.dart; then
  fail 'Placeholder duplo desnecessario reapareceu no Monitor vertical.'
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
[[ -f lib/models/esp32_module.dart ]] || fail 'Modelo Esp32Module nao encontrado.'
[[ -f lib/services/esp32_module_service.dart ]] || fail 'Servico Esp32ModuleService nao encontrado.'
[[ -f test/esp32_module_test.dart ]] || fail 'Testes da fundacao modular ESP32 nao encontrados.'
grep -q 'moduleSnapshots' lib/services/bike_sensor_service.dart || fail 'BikeSensorService nao prepara telemetria por modulo.'
grep -q '_esp32ModuleRegistry.initialize' lib/screens/home_screen.dart || fail 'Home nao inicializa/migra o registro modular ESP32.'
grep -q 'telemetryIntervalMs \* 3' lib/services/bike_sensor_service.dart lib/models/esp32_module.dart || fail 'Timeout adaptativo do ESP32 nao encontrado.'
[[ -f lib/models/esp32_telemetry.dart ]] || fail 'Modelo de telemetria ESP32 1.0.121 nao encontrado.'
[[ -f lib/services/esp32_telemetry_service.dart ]] || fail 'Servico continuo de telemetria ESP32 1.0.121 nao encontrado.'
[[ -f test/esp32_telemetry_test.dart ]] || fail 'Testes de telemetria ESP32 1.0.121 nao encontrados.'
[[ -f lib/screens/esp32_setup_wizard.dart ]] || fail 'Wizard ESP32 1.0.122 nao encontrado.'
[[ -f test/esp32_setup_wizard_test.dart ]] || fail 'Teste do wizard ESP32 1.0.122 nao encontrado.'
grep -q 'Esp32Capability.energy' lib/models/esp32_module.dart || fail 'Capacidade de energia ESP32 1.0.123 ausente.'
grep -q 'enum Esp32BatteryChemistry' lib/models/esp32_module.dart || fail 'Quimica de bateria ESP32 1.0.123 ausente.'
grep -q 'Esp32PowerMonitorType.ina226' lib/models/esp32_module.dart lib/screens/esp32_setup_wizard.dart || fail 'Suporte INA226 ESP32 1.0.123 ausente.'
grep -q "'energy': <String, Object?>" lib/models/esp32_module.dart || fail 'Bloco energy do protocolo ESP32 ausente.'
grep -q 'solarPowerW' lib/models/esp32_telemetry.dart lib/screens/esp32_settings_screen.dart || fail 'Telemetria solar ESP32 1.0.123 ausente.'
grep -Fq '## 1.0.123+123' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.123.'
grep -q 'Evolução 1.0.123' README.md || fail 'README nao documenta 1.0.123.'
[[ -f RELEASE-1.0.123.md ]] || fail 'Notas da entrega 1.0.123 ausentes.'
grep -q 'Etapa \${_step + 1} de \$_stepCount' lib/screens/esp32_setup_wizard.dart || fail 'Wizard nao exibe progresso em etapas.'
grep -q 'floatingActionButton: !_loading && _devices.isNotEmpty' lib/screens/esp32_settings_screen.dart || fail 'Tela ESP32 pode voltar a mostrar CTA duplicado no estado vazio.'
if grep -q "package:flutter/foundation.dart" lib/services/esp32_telemetry_service.dart; then
  fail 'Import redundante do Android-APK-90 reapareceu na telemetria ESP32.'
fi
grep -q "'/api/v1/telemetry'" lib/services/esp32_telemetry_service.dart || fail 'Endpoint versionado de telemetria ESP32 ausente.'
grep -q "'/telemetry'" lib/services/esp32_telemetry_service.dart || fail 'Fallback legado /telemetry ausente.'
grep -q 'Esp32TelemetryService.instance.initialize' lib/app/app.dart || fail 'Telemetria ESP32 nao inicia globalmente apos onboarding.'
grep -q 'markEsp32ModuleDisconnected' lib/services/bike_sensor_service.dart || fail 'HUD Bike nao recebe estado offline por modulo.'
grep -q 'frontTirePressureAvailable' lib/models/bike_sensor_snapshot.dart || fail 'Disponibilidade individual do pneu dianteiro ausente.'
grep -q 'MÓDULOS ESP32' lib/services/diagnostic_report_service.dart || fail 'Diagnostico nao exporta runtime dos modulos ESP32.'
grep -Fq '## 1.0.122+122' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.122.'
grep -q 'Evolução 1.0.122' README.md || fail 'README nao documenta 1.0.122.'
[[ -f RELEASE-1.0.122.md ]] || fail 'Notas da entrega 1.0.122 ausentes.'
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
grep -q 'MonitoringZoneOverlay' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart \
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
grep -q 'DetectionOverlay' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart \
  || fail 'Caixas de deteccao nao estao ligadas ao preview.'
grep -q 'EventsScreen' lib/screens/home_screen*.dart \
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
[[ -f android/app/src/main/res/mipmap/ic_launcher.xml ]] || fail 'Recurso mipmap/ic_launcher ausente (regressao Android-APK-76).'
[[ -f android/app/src/main/res/values/styles.xml ]] || fail 'styles.xml Android ausente (regressao Android-APK-76).'
grep -q 'name="LaunchTheme"' android/app/src/main/res/values/styles.xml || fail 'LaunchTheme ausente do resources Android.'
grep -q 'name="NormalTheme"' android/app/src/main/res/values/styles.xml || fail 'NormalTheme ausente do resources Android.'
grep -q 'android:icon="@mipmap/ic_launcher"' android/app/src/main/AndroidManifest.xml || fail 'Manifest Android perdeu o ic_launcher.'
grep -q 'android:theme="@style/LaunchTheme"' android/app/src/main/AndroidManifest.xml || fail 'Manifest Android perdeu LaunchTheme.'


# Regressões e interface 1.0.15
grep -q 'final ObjectTracker _tracker;' lib/controllers/monitor_controller.dart \
  || fail 'ObjectTracker deve permanecer final para evitar prefer_final_fields.'
if grep -q "import 'dart:typed_data';" lib/services/clip_recorder_service.dart; then
  fail 'Import dart:typed_data redundante reapareceu no ClipRecorderService.'
fi
grep -q 'AppOrientationService.lockPortrait' lib/main.dart \
  || fail 'Aplicativo nao inicia travado em retrato.'
grep -q 'DeviceOrientation.landscapeLeft' lib/services/app_orientation_service.dart \
  && grep -q 'DeviceOrientation.landscapeRight' lib/services/app_orientation_service.dart \
  || fail 'Transmissao perdeu suporte aos dois sentidos de paisagem.'
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
grep -q '_buildPortraitDetectionSummary(context)' lib/screens/monitor_screen_portrait.dart \
  || fail 'Resumo compacto de deteccoes nao encontrado no Monitor vertical.'
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
grep -q "static const String version = '1.0.131';" lib/core/app_metadata.dart \
  || fail 'AppMetadata nao esta em 1.0.131.'
grep -q 'static const int build = 131;' lib/core/app_metadata.dart \
  || fail 'Build de AppMetadata nao esta em 129.'
grep -q "version: '1.0.123'" lib/screens/app_info_screen*.dart \
  || fail 'Tela Mudancas nao marca a versao 1.0.123.'

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
grep -Fq 'version: 1.0.131+131' pubspec.yaml \
  || fail 'pubspec.yaml nao esta em 1.0.131+131.'

# Identidade tecnica 1.0.28
grep -q '^name: vigiaia$' pubspec.yaml \
  || fail 'Pacote Dart nao usa vigiaia.'
grep -q '"projectName": "vigiaia"' app_identity.json \
  || fail 'app_identity.json nao usa projectName vigiaia.'
grep -q '"version": "1.0.131"' app_identity.json \
  || fail 'app_identity.json nao esta na versao 1.0.131.'
grep -q '"build": 131' app_identity.json \
  || fail 'app_identity.json nao esta no build 131.'
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
grep -q '_requestCamera' lib/screens/access_guide_screen.dart \
  || fail 'Acesso inicial nao oferece a solicitacao guiada da camera.'
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
for destination in 'Início' 'Histórico' 'Ao vivo' 'Câmeras' 'Ajustes'; do
  grep -q "label: '$destination'" lib/widgets/main_navigation_bar.dart \
    || fail "Destino principal ausente: $destination"
done
if grep -q "label: 'Diagnóstico'" lib/widgets/main_navigation_bar.dart; then
  fail 'Diagnostico nao pode ficar na barra principal 1.0.24.'
fi
if grep -q "label: 'Configurações'" lib/widgets/main_navigation_bar.dart; then
  fail 'Configuracoes nao pode ficar na barra principal 1.0.24.'
fi
grep -q "title: 'Tema e cores'" lib/screens/settings_screen.dart \
  || fail 'Preferencia de Aparencia nao encontrada nas Configuracoes.'
grep -q "title: 'Diagnóstico'" lib/screens/settings_screen.dart \
  || fail 'Categoria Diagnostico nao encontrada nas Configuracoes.'
grep -q "title: 'Ajustes avançados da IA'" lib/screens/settings_screen.dart \
  || fail 'Ajustes avancados da IA nao encontrados nas Configuracoes.'
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
grep -q "'version': 8" lib/services/app_settings_service.dart \
  || fail 'Schema de configuracoes nao foi migrado para version 8.'
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
grep -q "'version': 8" lib/services/app_settings_service.dart \
  || fail 'Schema atual das configuracoes nao esta em 8.'
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
grep -Fq 'Vigia IA 1.0.131+131' ARCHITECTURE.md || fail 'ARCHITECTURE nao esta em 1.0.131+131.'

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
grep -q 'Escanear QR do outro celular' lib/screens/home_screen.dart lib/screens/home_screen_source_panel.dart \
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


# Modo Bike preservado fora da navegacao principal
test -f lib/models/bike_mode_config.dart || fail 'BikeModeConfig ausente.'
test -f lib/services/bike_mode_service.dart || fail 'BikeModeService ausente.'
test -f lib/screens/bike_mode_screen.dart || fail 'BikeModeScreen ausente.'
if grep -q "label: 'Bike'" lib/widgets/main_navigation_bar.dart; then
  fail 'Destino Bike reapareceu no menu principal.'
fi
test -f test/main_navigation_bar_test.dart || fail 'Teste do menu principal ausente.'
grep -q "findsNWidgets(5)" test/main_navigation_bar_test.dart || fail 'Teste nao valida os cinco destinos principais.'
grep -q "find.text('Bike'), findsNothing" test/main_navigation_bar_test.dart \
  || fail 'Teste nao protege a retirada de Bike do menu inferior.'
grep -q "title: 'Bike e economia'" lib/screens/settings_screen.dart \
  || fail 'Bike e economia nao esta acessivel em Configuracoes.'
grep -q 'AppLaunchMode.bike' lib/services/app_launch_mode_service.dart \
  || fail 'Compatibilidade do modo Bike legado ausente.'
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
grep -q '_bikeConfig.transmissionFrameInterval' lib/services/remote_camera_server_service.dart || fail 'Transmissao nao aplica intervalo do perfil Bike.'
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
grep -q 'RemoteBikeWarningBanner' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart \
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
grep -q 'Status da sessão' lib/screens/monitor_screen*.dart \
  || fail 'Acesso ao Status da sessao nao foi preservado no Monitor.'
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
grep -q "'Emulador de sensores'" lib/screens/esp32_settings_screen.dart   || fail 'ESP32 nao oferece emulador de sensores.'
grep -q 'BikeRideHud(snapshot:' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart   || fail 'Monitor nao exibe o HUD da bike sobre o video.'
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
grep -q "label: _fillPreview ? 'Preencher' : 'Ajustar'" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart || fail 'Alternancia Ajustar/Preencher ausente.'
grep -q 'fillPreview: _fillPreview' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart || fail 'Overlays nao acompanham o modo de preenchimento.'
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
grep -q 'BikeApproachBanner(status: approach)' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart lib/screens/monitor_screen_multicamera.dart || fail 'Monitor nao exibe alerta visual de aproximacao.'
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
[[ -f lib/screens/home_screen_source_panel.dart ]] || fail 'Painel de fontes extraido da Home ausente.'
grep -q "part 'monitor_controller_session_support.dart';" lib/controllers/monitor_controller.dart || fail 'MonitorController nao referencia modulo de sessao.'
grep -q "part 'monitor_screen_components.dart';" lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart || fail 'MonitorScreen nao referencia componentes extraidos.'
grep -q "part 'home_screen_components.dart';" lib/screens/home_screen.dart || fail 'HomeScreen nao referencia componentes extraidos.'
grep -q "part 'home_screen_source_panel.dart';" lib/screens/home_screen.dart || fail 'HomeScreen nao referencia o painel de fontes extraido.'
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
[[ -f lib/screens/events_screen_actions.dart ]] || fail 'Acoes extraidas do Historico ausentes.'
grep -q "part 'session_status_panel_components.dart';" lib/widgets/session_status_panel.dart || fail 'Status da sessao nao referencia componentes extraidos.'
grep -q "part 'error_center_screen_components.dart';" lib/screens/error_center_screen.dart || fail 'Central de diagnostico nao referencia componentes extraidos.'
grep -q "part 'events_screen_components.dart';" lib/screens/events_screen.dart || fail 'Historico nao referencia componentes extraidos.'
grep -q "part 'events_screen_actions.dart';" lib/screens/events_screen.dart || fail 'Historico nao referencia acoes extraidas.'
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
grep -q 'bash ./tool/bootstrap_android.sh' .github/workflows/android-apk.yml || fail 'Workflow nao preserva o bootstrap Android por bash como recuperacao.'
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
grep -q 'final forceFill' lib/screens/monitor_screen.dart \
  && grep -q 'MediaQuery.orientationOf(context) == Orientation.landscape' lib/screens/monitor_screen.dart \
  || fail 'Preview nao força preenchimento em paisagem/tela cheia.'
grep -q 'class _CameraStandbyPanel' lib/screens/camera_mode_screen.dart \
  || fail 'Estado visual integrado do Modo Camera ausente.'
grep -q 'class _CameraModeControlPanel' lib/screens/camera_mode_screen.dart \
  || fail 'Painel adaptativo do Modo Camera ausente.'
grep -q "Text('Alterar modo')" lib/screens/camera_mode_screen.dart \
  || fail 'Troca clara de modo no Modo Camera ausente.'
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
grep -q "title: 'Remoto'" lib/screens/launch_mode_screen.dart \
  || fail 'Texto Remoto nao esta exposto na selecao de modo.'

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

# Cameras adaptativas, sensores e permissoes - 1.0.78
grep -q '^## 1.0.78+78' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.78.'
grep -q 'Evolução 1.0.78' README.md || fail 'README nao documenta 1.0.78.'
grep -q "version: '1.0.78'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.78.'
[[ -f RELEASE-1.0.78.md ]] || fail 'Notas da entrega 1.0.78 ausentes.'
[[ -f lib/core/adaptive_camera_layout.dart ]] || fail 'Politica adaptativa das cameras ausente.'
[[ -f test/adaptive_camera_layout_test.dart ]] || fail 'Teste do layout adaptativo ausente.'
[[ -f lib/controllers/secondary_camera_controller.dart ]] || fail 'Controller da segunda camera ausente.'
grep -q 'this.secondarySource' lib/screens/monitor_screen.dart \
  || fail 'Monitor nao aceita uma segunda fonte opcional.'
grep -q 'AdaptiveCameraLayout.sideBySide' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Duas cameras nao usam composicao lado a lado quando apropriado.'
grep -q 'AdaptiveCameraLayout.stacked' test/adaptive_camera_layout_test.dart \
  || fail 'Retrato com duas cameras nao esta protegido por teste.'
grep -q 'emitFrames: false' lib/controllers/secondary_camera_controller.dart \
  || fail 'Segunda camera pode duplicar o pipeline de IA.'
grep -q 'Duas câmeras' lib/screens/multi_camera_screen_components.dart \
  || fail 'Central multicamera nao oferece composicao com duas cameras.'
grep -q 'applyEsp32Telemetry' lib/services/bike_sensor_service.dart \
  || fail 'Entrada de telemetria ESP32 ausente.'
grep -q "'frontTirePsi'" lib/models/bike_sensor_snapshot.dart \
  || fail 'Contrato dos sensores nao inclui pressao dianteira.'
grep -q "'rearTirePsi'" lib/models/bike_sensor_snapshot.dart \
  || fail 'Contrato dos sensores nao inclui pressao traseira.'
grep -q "'temperatureC'" lib/models/bike_sensor_snapshot.dart \
  || fail 'Contrato dos sensores nao inclui temperatura.'
grep -q "'bikeSensors': _bikeSensors.snapshot" lib/services/remote_camera_server_service.dart \
  || fail 'Transmissor nao publica os sensores no status.'
grep -q 'rawBikeSensors' lib/models/remote_phone_status.dart \
  || fail 'Receptor nao converte sensores recebidos.'
grep -q 'access_guide_completed_v2' tool/android/MainActivity.kt \
  || fail 'Novo marcador do guia de acesso ausente.'
if grep -q 'maybePromptCameraPermissionOnFirstLaunch' tool/android/MainActivity.kt; then
  fail 'Android ainda solicita camera antes da tela explicativa.'
fi
cmp -s tool/android/MainActivity.kt android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity Android diverge da fonte versionada.'
grep -q 'class _PermissionReminderHost' lib/app/app.dart \
  || fail 'Orientacao posterior para permissoes ausentes nao encontrada.'
grep -q '_returnToModeSelection' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Transmissao nao retorna a selecao de modo.'
grep -q 'receiverConnected' lib/services/remote_camera_server_service.dart lib/screens/camera_mode_screen.dart \
  || fail 'Modo Transmissao nao informa se existe receptor conectado.'

# Buildfix Android-APK-47 e menu essencial - 1.0.79
grep -q '^## 1.0.79+79' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.79.'
grep -q 'Evolução 1.0.79' README.md || fail 'README nao documenta 1.0.79.'
grep -q "version: '1.0.79'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.79.'
[[ -f RELEASE-1.0.79.md ]] || fail 'Notas da entrega 1.0.79 ausentes.'
if grep -q 'setState(' lib/screens/monitor_screen_multicamera.dart lib/screens/multi_camera_screen_monitoring.dart; then
  fail 'Modulo extraido ainda usa State.setState diretamente.'
fi
grep -q '_updateMulticameraState' lib/screens/monitor_screen.dart lib/screens/monitor_screen_multicamera.dart \
  || fail 'Atualizador seguro do Monitor multicamera ausente.'
grep -q '_updateMonitoringState' lib/screens/multi_camera_screen.dart lib/screens/multi_camera_screen_monitoring.dart \
  || fail 'Atualizador seguro da Central multicamera ausente.'
grep -q '_MultiCameraScreenState._automaticRefreshInterval' lib/screens/multi_camera_screen_monitoring.dart \
  || fail 'Intervalo estatico da Central continua sem qualificacao.'
if grep -q "label: 'Bike'" lib/widgets/main_navigation_bar.dart; then
  fail 'Bike reapareceu no menu principal.'
fi
grep -q "findsNWidgets(5)" test/main_navigation_bar_test.dart \
  || fail 'Teste do menu nao exige cinco destinos.'
grep -q "title: 'Bike e economia'" lib/screens/settings_screen.dart \
  || fail 'Configuracoes nao oferece acesso a Bike e economia.'
if grep -q '4 => const BikeModeScreen()' lib/screens/home_screen.dart lib/screens/events_screen.dart lib/screens/multi_camera_screen.dart; then
  fail 'Indice Bike reapareceu nos manipuladores da navegacao principal.'
fi

# Historico, ESP32, cameras e artefato Android - 1.0.80
grep -q '^## 1.0.80+80' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.80.'
grep -q 'Evolução 1.0.80' README.md || fail 'README nao documenta 1.0.80.'
grep -q "version: '1.0.80'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.80.'
[[ -f RELEASE-1.0.80.md ]] || fail 'Notas da entrega 1.0.80 ausentes.'
[[ -f lib/screens/esp32_settings_screen.dart ]] || fail 'Painel ESP32 ausente.'
grep -q 'enum CameraEndpointType { local, rtsp, remotePhone, esp32 }' lib/models/camera_endpoint.dart \
  || fail 'CameraEndpoint nao suporta ESP32.'
grep -q 'enum VideoSourceType { localCamera, rtsp, remotePhone, esp32 }' lib/models/video_source_config.dart \
  || fail 'VideoSourceConfig nao suporta ESP32.'
grep -q 'applyEsp32Configuration' lib/services/camera_registry_service.dart lib/screens/esp32_settings_screen.dart \
  || fail 'Aplicacao da configuracao ESP32 nao esta conectada.'
grep -q "label: '2ª câmera'" lib/screens/monitor_screen.dart \
  || fail 'Monitor nao deixa a segunda camera explicita.'
grep -q "label: const Text('Salvar')" lib/screens/events_screen.dart lib/screens/events_screen_actions.dart \
  || fail 'Historico nao oferece salvar captura.'
grep -q 'Excluir este registro?' lib/screens/events_screen.dart lib/screens/events_screen_actions.dart \
  || fail 'Exclusao individual do Historico nao exige confirmacao.'
grep -q "expected = {'universal', 'armeabi-v7a', 'arm64-v8a', 'x86_64'}" .github/workflows/android-apk.yml \
  || fail 'Workflow nao valida APK universal e APKs separados por ABI.'
grep -q "VigiaIA-v{version}-{kind}.apk" .github/workflows/android-apk.yml \
  || fail 'Workflow nao nomeia os APKs com aplicativo, versao e tipo.'
grep -q 'gh release create' .github/workflows/android-apk.yml \
  || fail 'Workflow nao publica APKs como arquivos diretos na Release.'
grep -q 'apk-size-report.txt' .github/workflows/android-apk.yml \
  || fail 'Workflow nao gera relatorio de tamanho do APK.'
grep -q 'compression-level: 0' .github/workflows/android-apk.yml \
  || fail 'Workflow voltou a recomprimir o APK durante o upload.'

# Politica de orientacao por modo - 1.0.92
grep -q '^## 1.0.92+92' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.92.'
grep -q 'Evolução 1.0.92' README.md || fail 'README nao documenta 1.0.92.'
grep -q "version: '1.0.92'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.92.'
[[ -f RELEASE-1.0.92.md ]] || fail 'Notas da entrega 1.0.92 ausentes.'
[[ -f lib/services/app_orientation_service.dart ]] || fail 'Servico central de orientacao ausente.'
grep -q 'AppOrientationService.lockPortrait' lib/main.dart \
  || fail 'main.dart nao aplica retrato como politica padrao.'
grep -q 'AppOrientationService.allowTransmissionRotation' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Transmissao nao libera rotacao conforme a posicao fisica.'
grep -q 'AppOrientationService.lockPortrait' lib/screens/camera_mode_screen.dart \
  || fail 'Modo Transmissao nao restaura retrato ao sair.'
grep -q 'await _orientationSetup;' lib/screens/camera_mode_screen.dart \
  || fail 'Saida da Transmissao nao aguarda a liberacao inicial antes de restaurar retrato.'
grep -q 'AppOrientationService.lockPortrait' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Monitor nao preserva/restaura a politica de retrato.'
if grep -q 'DeviceOrientation.landscapeLeft' lib/screens/monitor_screen_fullscreen.dart; then
  fail 'Tela inteira do Monitor voltou a forcar paisagem.'
fi
if grep -q 'DeviceOrientation.values' lib/screens/monitor_screen.dart lib/screens/monitor_screen_fullscreen.dart; then
  fail 'Monitor voltou a liberar rotacao automatica fora da Transmissao.'
fi
[[ -f test/app_orientation_service_test.dart ]] || fail 'Teste da politica de orientacao ausente.'
grep -q 'sensorOrientation: description.sensorOrientation' lib/services/shared_local_camera_service.dart \
  && grep -q 'deviceOrientation: controller.value.deviceOrientation' lib/services/shared_local_camera_service.dart \
  || fail 'Pipeline da camera perdeu a rotacao baseada em sensor + orientacao fisica.'

# Dashboard paisagem / buildfix - 1.0.89
grep -q '^## 1.0.91+91' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.91.'
grep -q 'Evolução 1.0.91' README.md || fail 'README nao documenta 1.0.91.'
grep -q "version: '1.0.91'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.91.'
[[ -f RELEASE-1.0.91.md ]] || fail 'Notas da entrega 1.0.91 ausentes.'
if grep -q '^[[:space:]]*setState(' lib/screens/monitor_screen_landscape_dashboard.dart; then
  fail 'Dashboard paisagem voltou a chamar setState diretamente pela extensao.'
fi
grep -q '_updateMulticameraState' lib/screens/monitor_screen_landscape_dashboard.dart \
  || fail 'Dashboard paisagem nao usa o atualizador seguro da State.'
[[ -f lib/screens/multi_camera_screen_details.dart ]] || fail 'Detalhes das fontes na Central de Cameras ausentes.'
grep -q "Adicionar celular remoto" lib/screens/multi_camera_screen.dart \
  || fail 'Cadastro de celular remoto nao esta explicito.'
grep -q 'videoWidth' lib/services/remote_camera_server_service.dart lib/models/remote_phone_status.dart \
  || fail 'Telemetria de resolucao da fonte remota ausente.'
grep -q "label: const Text('Alterar modo')" lib/screens/home_screen.dart lib/screens/monitor_connect_screen.dart lib/screens/bike_mode_screen.dart \
  || fail 'Atalho Alterar modo nao aparece em todos os modos principais.'
grep -q "Text('Alterar modo')" lib/screens/camera_mode_screen.dart lib/screens/monitor_screen_fullscreen.dart \
  || fail 'Troca de modo ausente em Transmissao ou Monitor ativo.'
grep -q 'crossAxisCount: singleRow ? 4 : 2' lib/screens/events_screen.dart \
  || fail 'Historico nao adapta os filtros para uma linha.'

# Distribuicao direta de APKs por ABI - 1.0.82
grep -q '^## 1.0.82+82' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.82.'
grep -q 'Evolução 1.0.82' README.md || fail 'README nao documenta 1.0.82.'
grep -q "version: '1.0.82'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.82.'
[[ -f RELEASE-1.0.82.md ]] || fail 'Notas da entrega 1.0.82 ausentes.'

# Monitor vertical fixo e buildfix Android-APK-49 - 1.0.81
grep -q '^## 1.0.81+81' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.81.'
grep -q 'Evolução 1.0.81' README.md || fail 'README nao documenta 1.0.81.'
grep -q "version: '1.0.81'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.81.'
[[ -f RELEASE-1.0.81.md ]] || fail 'Notas da entrega 1.0.81 ausentes.'
[[ -f lib/screens/monitor_screen_portrait.dart ]] || fail 'Composicao vertical modular ausente.'
grep -q "part 'monitor_screen_portrait.dart';" lib/screens/monitor_screen.dart \
  || fail 'Monitor nao referencia a composicao vertical fixa.'
grep -q 'portraitEmbedded: true' lib/screens/monitor_screen_portrait.dart \
  || fail 'Camera nao esta incorporada ao cartao vertical.'
grep -q '_buildPortraitMapCard' lib/screens/monitor_screen_portrait.dart \
  || fail 'Tela vertical ainda nao integra o mini-mapa.'
grep -q '_buildPortraitDetectionSummary' lib/screens/monitor_screen_portrait.dart \
  || fail 'Resumo compacto de deteccoes nao foi preservado no Monitor vertical.'
if grep -q '_detectionsExpanded' lib/screens/monitor_screen*.dart; then
  fail 'Painel expansivel de deteccoes reapareceu no Monitor.'
fi
grep -q 'showBattery: remoteSource' lib/screens/monitor_screen_components.dart \
  || fail 'Bateria da fonte local pode voltar a ser duplicada.'
if ! grep -A3 'if (!mounted) return;' lib/screens/events_screen_actions.dart | \
    grep -q 'resolveExportLocation'; then
  fail 'BuildContext da exportacao nao esta protegido apos espera assincrona.'
fi


# Buildfix Android-APK-73 - 1.0.105
grep -q '^## 1.0.105+105' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.105.'
grep -q 'Correção 1.0.105' README.md || fail 'README nao documenta 1.0.105.'
grep -q "version: '1.0.105'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.105.'
[[ -f RELEASE-1.0.105.md ]] || fail 'Notas da entrega 1.0.105 ausentes.'

# Painel Stadia e mapa multicamera - 1.0.104
grep -q '^## 1.0.104+104' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.104.'
grep -q 'Evolução 1.0.104' README.md || fail 'README nao documenta 1.0.104.'
grep -q "version: '1.0.104'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.104.'
[[ -f RELEASE-1.0.104.md ]] || fail 'Notas da entrega 1.0.104 ausentes.'
grep -q "label: const Text('Colar')" lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Painel Stadia nao oferece botao Colar.'
grep -q "label: const Text('Copiar')" lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Painel Stadia nao oferece copia explicita da chave.'
grep -q 'testStadiaApiKey' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Teste da API key Stadia nao esta conectado ao painel.'
grep -q 'maskedStadiaApiKey' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Painel Stadia nao indica chave configurada de forma mascarada.'
grep -q "label: const Text('Mapa')" lib/screens/offline_area_selection_screen.dart \
  && grep -q "label: const Text('Área')" lib/screens/offline_area_selection_screen.dart \
  || fail 'Selecao offline nao separa os modos Mapa e Area.'
grep -q "tooltip: 'Diminuir zoom'" lib/screens/offline_area_selection_screen.dart \
  && grep -q "tooltip: 'Aumentar zoom'" lib/screens/offline_area_selection_screen.dart \
  || fail 'Selecao offline nao possui controles inferiores de zoom.'
grep -q '_MapTelemetryStrip' lib/screens/map_monitoring_screen.dart \
  && grep -q '_RouteButtonBar' lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa completo nao separa telemetria superior da acao principal inferior.'
grep -q 'secondaryCameraPreviewBuilder' lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen.dart \
  || fail 'Segunda camera nao esta conectada ao mapa completo.'
grep -q 'cameraAspectRatioProvider' lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen.dart \
  || fail 'PiP principal nao recebe proporcao dinamica da transmissao.'
grep -q 'secondaryCameraAspectRatioProvider' lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen.dart \
  || fail 'PiP secundario nao recebe proporcao dinamica quando disponivel.'
grep -q "Mostrar PiPs no mapa" lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa completo nao permite mostrar/ocultar os PiPs.'

echo 'Verificacao preventiva concluida com sucesso.'

# Tela vertical / mapa - 1.0.90
grep -q "label: 'Câmera'" lib/screens/monitor_screen_portrait.dart \
  || fail 'Tela vertical nao exibe a acao compacta Camera.'
grep -q "'Mapa'" lib/screens/monitor_screen_portrait.dart \
  || fail 'Tela vertical nao integra o mini-mapa compacto.'
grep -q '_showPortraitQuickPanel' lib/screens/monitor_screen_portrait.dart \
  || fail 'Tela vertical nao moveu os atalhos avancados para o Painel.'

# Monitor vertical compacto - 1.0.93
grep -q '^## 1.0.93+93' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.93.'
grep -q 'Evolução 1.0.93' README.md || fail 'README nao documenta 1.0.93.'
grep -q "version: '1.0.93'" lib/screens/app_info_screen_components.dart   || fail 'Tela de Mudancas nao documenta 1.0.93.'
[[ -f RELEASE-1.0.93.md ]] || fail 'Notas da entrega 1.0.93 ausentes.'
grep -q '_buildPortraitDetectionSummary(context)' lib/screens/monitor_screen_portrait.dart   || fail 'Tela principal vertical nao usa o resumo compacto de deteccoes.'
grep -q 'DraggableScrollableSheet' lib/screens/monitor_screen_portrait.dart   || fail 'Deteccoes detalhadas nao abrem em painel inferior arrastavel.'
grep -q 'scrollController: scrollController' lib/screens/monitor_screen_portrait.dart   || fail 'Painel arrastavel nao compartilha o controlador de rolagem.'
grep -q 'ScrollController? scrollController' lib/screens/monitor_screen.dart   || fail 'Painel de deteccoes nao aceita controlador de rolagem opcional.'
if grep -q 'height: detectionHeight' lib/screens/monitor_screen_portrait.dart; then
  fail 'Bloco grande fixo de Detectados agora reapareceu na tela vertical.'
fi
if grep -q 'Ver rota completa\|Mapa do trajeto\|Sua posição em tempo real\|Mostrar mapa' lib/screens/monitor_screen_portrait.dart; then
  fail 'Rotulos longos do mini-mapa reapareceram na tela vertical.'
fi
grep -q "label: const Text('Rota')" lib/screens/monitor_screen_portrait.dart   || fail 'Acao Rota compacta ausente no mini-mapa.'
grep -q "label: 'Câmera'" lib/screens/monitor_screen_portrait.dart   || fail 'Acao Camera ausente na faixa de atalhos.'
grep -q 'height: 64' lib/screens/monitor_screen_portrait.dart \
  || fail 'Faixa de telemetria vertical nao usa a altura compacta atual.'
grep -q 'constraints.maxHeight \* 0.255' lib/screens/monitor_screen_portrait.dart \
  || fail 'Mini-mapa vertical nao usa a altura ampliada atual.'

# Ajuste fino do Monitor e teste frontal - 1.0.94
grep -q '^## 1.0.94+94' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.94.'
grep -q 'Evolução 1.0.94' README.md || fail 'README nao documenta 1.0.94.'
grep -q "version: '1.0.94'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.94.'
[[ -f RELEASE-1.0.94.md ]] || fail 'Notas da entrega 1.0.94 ausentes.'
grep -q "label: 'Ajustes'" lib/screens/monitor_screen_portrait.dart \
  || fail 'Atalho Ajustes nao esta visivel na linha fixa do Monitor vertical.'
grep -q "label: 'Painel'" lib/screens/monitor_screen_portrait.dart \
  || fail 'Atalho Painel nao esta visivel na linha fixa do Monitor vertical.'
grep -q 'compact: true' lib/screens/monitor_screen_portrait.dart \
  || fail 'Atalhos inferiores nao usam o modo compacto.'
grep -q 'altitudeMeters' lib/screens/monitor_screen_portrait.dart \
  || fail 'Mini-mapa vertical nao mostra altitude real do GPS.'
if grep -q 'bikeSnapshotText' lib/screens/monitor_screen_portrait.dart; then
  fail 'Rotulo Bike legado reapareceu no overlay inferior do mapa.'
fi
grep -q 'minWidth: 116' lib/screens/monitor_screen_components.dart \
  || fail 'Cards ESP32/Bike nao usam a largura compacta atual.'
[[ -f lib/sources/front_camera_preview_source.dart ]] \
  || fail 'Fonte temporaria da camera frontal nao encontrada.'
grep -q 'ResolutionPreset.low' lib/sources/front_camera_preview_source.dart \
  || fail 'Camera frontal de teste nao usa resolucao leve.'
grep -q 'frontCameraTestId' lib/models/video_source_config.dart \
  || fail 'Identificador da frontal de teste nao esta centralizado.'
grep -q 'isFrontCameraTest' test/video_source_config_test.dart \
  || fail 'Teste do identificador da frontal temporaria nao encontrado.'
grep -q '_buildPortraitPictureInPictureStage' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Composicao PiP da segunda camera no retrato nao encontrada.'
grep -q 'Teste: câmera frontal' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Seletor nao oferece o teste temporario da camera frontal.'
grep -q '_buildCameraStage(context, portraitEmbedded: true)' lib/screens/monitor_screen_multicamera.dart \
  || fail 'PiP nao preserva a camera principal como base integral do Monitor.'
grep -q "sourceConfig.isFrontCameraTest" lib/controllers/secondary_camera_controller.dart \
  || fail 'SecondaryCameraController nao reconhece a frontal temporaria.'


# Refinamento do Monitor e hub de cameras - 1.0.95
grep -q '^## 1.0.95+95' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.95.'
grep -q 'Evolução 1.0.95' README.md || fail 'README nao documenta 1.0.95.'
grep -q "version: '1.0.95'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.95.'
[[ -f RELEASE-1.0.95.md ]] || fail 'Notas da entrega 1.0.95 ausentes.'
grep -q "label: 'Câmera'" lib/screens/monitor_screen_portrait.dart \
  || fail 'Botao Camera nao substituiu Abrir mapa.'
if grep -q "label: 'Abrir mapa'" lib/screens/monitor_screen_portrait.dart; then
  fail 'Botao Abrir mapa legado reapareceu na barra inferior.'
fi
grep -q 'onTap: (_, _) => unawaited(_openFullMap())' lib/screens/monitor_screen_portrait.dart \
  || fail 'Toda a area do mini-mapa nao abre o mapa completo.'
grep -q 'constraints.maxHeight \* 0.255' lib/screens/monitor_screen_portrait.dart \
  || fail 'Mapa vertical nao usa a altura ampliada da 1.0.95.'
grep -q 'height: 64' lib/screens/monitor_screen_portrait.dart \
  || fail 'Telemetria vertical nao usa a faixa compactada da 1.0.95.'
grep -q 'minWidth: 116' lib/screens/monitor_screen_components.dart \
  || fail 'Cards de telemetria nao usam a largura reduzida da 1.0.95.'
grep -q 'maxWidth: 158' lib/screens/monitor_screen_components.dart \
  || fail 'Cards de telemetria perderam o limite compacto de largura.'
grep -q 'foregroundColor: accent ? scheme.primary : scheme.onSurface' lib/screens/monitor_screen_components.dart \
  || fail 'Atalhos inferiores nao usam contraste de estado ativo.'
grep -q 'available >= 330' lib/screens/monitor_screen.dart \
  || fail 'Painel compacto nao tenta manter os seis atalhos lado a lado.'
grep -q 'SegmentedButton<bool>' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Hub de cameras nao preserva escolha entre uma e duas cameras.'
grep -q '_showCameraHub()' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Hub unificado de cameras nao foi encontrado.'
grep -q "title: const Text('Câmera frontal')" lib/screens/monitor_screen_multicamera.dart \
  || fail 'Hub de cameras nao oferece a frontal.'
grep -q 'CameraEndpointType.esp32' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Hub de cameras nao considera fontes ESP32.'
grep -q '_portraitPipOffset' lib/screens/monitor_screen.dart \
  || fail 'Posicao do PiP arrastavel nao esta persistida no estado do Monitor.'
grep -q 'onPanUpdate:' lib/screens/monitor_screen_multicamera.dart \
  || fail 'Segunda camera PiP nao pode ser arrastada.'
grep -q 'onDoubleTap:' lib/screens/monitor_screen_portrait.dart \
  || fail 'Duplo toque na imagem nao aciona tela inteira.'
grep -q "VideoSourceType.localCamera => 'Local'" lib/screens/monitor_screen_multicamera.dart \
  || fail 'Rotulo compacto Local nao foi aplicado na area de camera.'
if grep -q "PopupMenuItem(value: 'cameras'" lib/screens/monitor_screen_fullscreen.dart; then
  fail 'Selecao de cameras reapareceu no menu de tres pontos.'
fi
if grep -q "PopupMenuItem(value: 'status'" lib/screens/monitor_screen_fullscreen.dart; then
  fail 'Status da sessao reapareceu no menu de tres pontos.'
fi
grep -q 'canvas.drawRect(rect, border);' lib/widgets/detection_overlay.dart \
  || fail 'Overlay visual de caixas da IA foi alterado sem aprovacao nesta entrega.'




# Mapas offline e camera flutuante no mapa completo - 1.0.96
grep -q '^## 1.0.96+96' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.96.'
grep -q 'Evolução 1.0.96' README.md || fail 'README nao documenta 1.0.96.'
grep -q "version: '1.0.96'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.96.'
[[ -f RELEASE-1.0.96.md ]] || fail 'Notas da entrega 1.0.96 ausentes.'
grep -q '^  flutter_map_mbtiles: \^1.0.4' pubspec.yaml \
  || fail 'Dependencia flutter_map_mbtiles nao esta configurada.'
[[ -f lib/models/offline_map_package.dart ]] \
  || fail 'Modelo de pacote de mapa offline nao encontrado.'
[[ -f lib/services/offline_map_service.dart ]] \
  || fail 'OfflineMapService nao encontrado.'
[[ -f lib/widgets/offline_map_manager_sheet.dart ]] \
  || fail 'Gerenciador visual de mapas offline nao encontrado.'
[[ -f test/offline_map_package_test.dart ]] \
  || fail 'Testes do modelo de mapa offline nao encontrados.'
grep -q 'MbTilesTileProvider.fromPath' lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa completo nao abre o pacote MBTiles ativo.'
grep -q 'OfflineMapMode.automatic' lib/screens/map_monitoring_screen.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Modo automatico de mapa offline nao encontrado.'
grep -q 'OfflineMapMode.online' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Modo Online nao encontrado no gerenciador de mapas.'
grep -q 'OfflineMapMode.offline' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Modo Offline nao encontrado no gerenciador de mapas.'
grep -q 'downloadPackage' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Download direto de pacote MBTiles nao esta ligado a interface.'
grep -q "SQLite format 3" lib/services/offline_map_service.dart \
  || fail 'Validacao basica de arquivo MBTiles/SQLite nao encontrada.'
grep -q 'cameraPreviewBuilder' lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen.dart \
  || fail 'Camera principal nao esta ligada ao mapa completo.'
grep -q '_primaryCameraOffset' lib/screens/map_monitoring_screen.dart \
  && grep -q '_secondaryCameraOffset' lib/screens/map_monitoring_screen.dart \
  || fail 'Offsets independentes das cameras flutuantes do mapa nao encontrados.'
grep -q 'onPanUpdate:' lib/screens/map_monitoring_screen.dart \
  || fail 'Camera flutuante do mapa completo nao pode ser arrastada.'
if grep -q 'tile.openstreetmap.org' lib/services/offline_map_service.dart; then
  fail 'Downloader offline nao pode usar o servidor publico de tiles do OpenStreetMap.'
fi
grep -q "final useOnline = mode != OfflineMapMode.offline;" lib/screens/map_monitoring_screen.dart \
  || fail 'Modo Offline precisa bloquear completamente a camada de rede.'
grep -q "ValueKey<String>" lib/screens/map_monitoring_screen.dart \
  || fail 'Camada MBTiles nao protege a troca de pacote com chave propria.'
grep -q "TileDisplay.instantaneous" lib/screens/map_monitoring_screen.dart \
  || fail 'Camada MBTiles nao preserva o provider ao alternar Online/Offline.'
grep -q 'final rightReserve = _compactLandscape ? 8.0 : 58.0;' lib/screens/map_monitoring_screen.dart \
  || fail 'Camera flutuante nao preserva a faixa dos controles do mapa.'
grep -q 'MapUxPolicy.cameraBottomReserve' lib/screens/map_monitoring_screen.dart \
  || fail 'Camera flutuante nao preserva a barra de rota e a navegacao do sistema.'
grep -q "rasterFormats = <String>{'png', 'jpg', 'jpeg', 'webp'}" lib/services/offline_map_service.dart \
  || fail 'Downloader nao valida se o MBTiles contem tiles raster compativeis.'
grep -q 'metadata.maxZoom' lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa offline nao respeita o zoom nativo declarado pelo MBTiles.'

# Buildfix de sincronizacao de metadados - 1.0.97
grep -q '^## 1.0.97+97' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.97.'
grep -q 'Evolução 1.0.97' README.md || fail 'README nao documenta 1.0.97.'
grep -q "version: '1.0.97'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.97.'
[[ -f RELEASE-1.0.97.md ]] || fail 'Notas da entrega 1.0.97 ausentes.'
grep -q 'metadata_test = (root / "test/app_metadata_test.dart")' tool/check_version_sync.py \
  || fail 'Verificador de versao nao protege o teste de AppMetadata.'

# Mapa adaptativo, rota persistente e offline ampliado - 1.0.98
grep -q '^## 1.0.98+98' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.98.'
grep -q 'Evolução 1.0.98' README.md || fail 'README nao documenta 1.0.98.'
grep -q "version: '1.0.98'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.98.'
[[ -f RELEASE-1.0.98.md ]] || fail 'Notas da entrega 1.0.98 ausentes.'
[[ -f lib/services/map_route_service.dart ]] \
  || fail 'MapRouteService compartilhado nao encontrado.'
grep -q 'enum MonitorMapVisibilityMode { automatic, always, hidden }' lib/services/map_route_service.dart \
  || fail 'Politicas Automático/Sempre/Ocultar do mapa nao foram encontradas.'
grep -q "map_route_state.json" lib/services/map_route_service.dart \
  || fail 'Persistencia da sessao de trajeto nao foi encontrada.'
grep -q 'shouldShowInMonitor' lib/services/map_route_service.dart lib/screens/monitor_screen_portrait.dart \
  || fail 'Decisao automatica de visibilidade do mapa nao esta ligada ao Monitor.'
grep -q 'SegmentedButton<MonitorMapVisibilityMode>' lib/screens/monitor_screen_portrait.dart \
  || fail 'Controle Automático/Sempre/Ocultar nao esta exposto no Monitor.'
grep -q 'final MapRouteService _routeState = MapRouteService.instance;' lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa completo nao usa a sessao compartilhada de trajeto.'
grep -q 'final MapRouteService _mapRoute = MapRouteService.instance;' lib/screens/monitor_screen.dart \
  || fail 'Monitor nao usa a sessao compartilhada de trajeto.'
[[ -f test/map_route_point_test.dart ]] \
  || fail 'Teste de serializacao/politica do novo trajeto nao encontrado.'
grep -q 'pickOfflineMapPackage' lib/services/native_platform_service.dart android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt tool/android/MainActivity.kt \
  || fail 'Importacao nativa de MBTiles nao esta ligada de ponta a ponta.'
grep -q 'importPackage' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Importacao de MBTiles local nao esta ligada ao gerenciador.'
grep -q "label: 'Região atual'" lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejamento de regiao atual nao encontrado.'
grep -q "label: 'Selecionar região'" lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejamento de area visivel nao encontrado.'
grep -q "label: 'Trajeto'" lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejamento de corredor do trajeto nao encontrado.'
grep -q 'freeStorageBytes' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Estimativa de espaco livre nao encontrada no gerenciador offline.'
if grep -q 'tile.openstreetmap.org' lib/services/offline_map_service.dart; then
  fail 'Servico offline nao pode fazer download em massa do servidor publico do OpenStreetMap.'
fi
# Download offline direto, pausa de rota e GPX - 1.0.99
grep -q '^## 1.0.99+99' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.99.'
grep -q 'Evolução 1.0.99' README.md || fail 'README nao documenta 1.0.99.'
grep -q "version: '1.0.99'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.99.'
[[ -f RELEASE-1.0.99.md ]] || fail 'Notas da entrega 1.0.99 ausentes.'
grep -q '^  sqlite3: \^2\.9\.4$' pubspec.yaml \
  || fail 'sqlite3 2.9.4 nao esta declarado para gerar MBTiles.'
grep -q 'stadiaCacheLimitBytes = 100 \* 1024 \* 1024' lib/services/offline_map_service.dart \
  || fail 'Limite tecnico de cache da fonte offline nao encontrado.'
grep -q 'stadiaCachedBytes' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Limite de cache offline nao considera o total armazenado no aparelho.'
grep -q 'downloadStadiaRegion' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Download direto de regiao nao esta ligado ao gerenciador.'
grep -q 'downloadStadiaRoute' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Download direto de corredor do trajeto nao esta ligado ao gerenciador.'
grep -q 'pauseDownload' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Pausa do download offline nao esta ligada de ponta a ponta.'
grep -q 'cancelDownload' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Cancelamento do download offline nao esta ligado de ponta a ponta.'
grep -q 'protectSecret' lib/services/offline_map_service.dart \
  || fail 'API key da fonte offline nao usa protecao nativa.'
[[ -f lib/screens/offline_area_selection_screen.dart ]] \
  || fail 'Tela de selecao de area offline nao encontrada.'
grep -q 'pauseRoute' lib/services/map_route_service.dart lib/screens/map_monitoring_screen.dart \
  || fail 'Pausa da rota compartilhada nao esta ligada de ponta a ponta.'
grep -q 'resumeRoute' lib/services/map_route_service.dart lib/screens/map_monitoring_screen.dart \
  || fail 'Retomada da rota compartilhada nao esta ligada de ponta a ponta.'
grep -q 'buildGpx' lib/services/map_route_service.dart lib/screens/map_monitoring_screen.dart \
  || fail 'Exportacao GPX nao esta ligada de ponta a ponta.'
grep -q 'saveBytesWithPicker' lib/screens/map_monitoring_screen.dart \
  || fail 'GPX nao usa o seletor nativo para salvar o arquivo.'
grep -q 'routeSegments' lib/services/map_route_service.dart lib/screens/map_monitoring_screen.dart lib/screens/monitor_screen_portrait.dart \
  || fail 'Segmentacao da rota pausada nao esta refletida nos mapas.'
grep -q 'Fora da área offline' lib/screens/map_monitoring_screen.dart \
  || fail 'Aviso de saida da area offline nao encontrado.'
grep -q 'MbTilesTileProvider' lib/screens/monitor_screen.dart \
  || fail 'Mini-mapa nao usa o pacote MBTiles ativo.'
[[ -f lib/screens/monitor_screen_offline_map.dart ]] \
  || fail 'Suporte MBTiles do mini-mapa nao foi mantido em modulo separado.'
grep -q "part 'monitor_screen_offline_map.dart';" lib/screens/monitor_screen.dart \
  || fail 'MonitorScreen nao referencia o modulo offline extraido.'
if grep -q 'tile.openstreetmap.org' lib/services/offline_map_service.dart; then
  fail 'Servico offline 1.0.99 nao pode baixar tiles do servidor publico do OpenStreetMap.'
fi

# Buildfix Android-APK-68 - 1.0.100
grep -q '^## 1.0.100+100' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.100.'
grep -q 'Evolução 1.0.100' README.md || fail 'README nao documenta 1.0.100.'
grep -q "version: '1.0.100'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.100.'
[[ -f RELEASE-1.0.100.md ]] || fail 'Notas da entrega 1.0.100 ausentes.'
if grep -q 'setState(' lib/screens/monitor_screen_offline_map.dart; then
  fail 'Modulo offline do mini-mapa voltou a chamar setState diretamente pela extension.'
fi
if grep -q 'if (_positionSubscription == null)' lib/services/map_route_service.dart; then
  fail 'MapRouteService voltou ao padrao que gera prefer_conditional_assignment.'
fi
if grep -q 'earliestExpiry!' lib/services/offline_map_service.dart; then
  fail 'OfflineMapService voltou a usar non-null assertion redundante em earliestExpiry.'
fi

cmp -s android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt tool/android/MainActivity.kt \
  || fail 'MainActivity Android e template tool/android divergiram.'

# Limite offline inteligente e mapa de navegacao - 1.0.101
grep -q '^## 1.0.101+101' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.101.'
grep -q 'Evolução 1.0.101' README.md || fail 'README nao documenta 1.0.101.'
grep -q "version: '1.0.101'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.101.'
[[ -f RELEASE-1.0.101.md ]] || fail 'Notas da entrega 1.0.101 ausentes.'
grep -q 'Ajustar ao limite disponível' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejador offline nao oferece ajuste automatico ao limite.'
grep -q '_maxRadiusForZoom' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Raio offline nao possui limite dinamico por zoom/cache.'
grep -q '_maxRouteBufferForZoom' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Margem do trajeto nao possui limite dinamico por zoom/cache.'
grep -q '_resizeSelection' lib/screens/offline_area_selection_screen.dart \
  || fail 'Selecao offline nao permite redimensionar a area visual.'
grep -q 'Arraste a área' lib/screens/offline_area_selection_screen.dart \
  || fail 'Selecao offline nao indica a area visual arrastavel.'
grep -q "label: altitudeMeters == null" lib/screens/map_monitoring_screen.dart \
  || fail 'Painel do mapa completo nao mostra altitude.'
grep -q "label: _direction(headingDegrees)" lib/screens/map_monitoring_screen.dart \
  || fail 'Painel do mapa completo nao mostra rumo.'
grep -q "following ? 'Seguindo' : 'Mapa livre'" lib/screens/map_monitoring_screen.dart \
  || fail 'Mapa completo nao explicita Seguindo/Mapa livre.'

# Ajuda de configuracao da API de mapas offline - 1.0.102
grep -q '^## 1.0.102+102' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.102.'
grep -q 'Evolução 1.0.102' README.md || fail 'README nao documenta 1.0.102.'
grep -q "version: '1.0.102'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.102.'
[[ -f RELEASE-1.0.102.md ]] || fail 'Notas da entrega 1.0.102 ausentes.'
grep -q 'Como conseguir a chave?' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Configuracao da fonte nao oferece ajuda para obter a API key.'
grep -q 'https://client.stadiamaps.com/dashboard/' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Ajuda da API nao possui link direto para o painel Stadia Maps.'
grep -q 'https://docs.stadiamaps.com/authentication/#api-keys' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Ajuda da API nao possui link para a documentacao oficial.'
grep -q 'Future<bool> openExternalUrl' lib/services/native_platform_service.dart \
  || fail 'Ponte Flutter nao expoe abertura segura de link externo.'
grep -q '"openExternalUrl" ->' android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity nao trata abertura de link externo.'
grep -q 'Intent.ACTION_VIEW' android/app/src/main/kotlin/com/vigiaia/app/MainActivity.kt \
  || fail 'MainActivity nao abre o painel oficial no navegador.'

# Creditos de mapas e buildfix Android-APK-71 - 1.0.103
grep -q '^## 1.0.103+103' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.103.'
grep -q 'Evolução 1.0.103' README.md || fail 'README nao documenta 1.0.103.'
grep -q "version: '1.0.103'" lib/screens/app_info_screen_components.dart \
  || fail 'Tela de Mudancas nao documenta 1.0.103.'
[[ -f RELEASE-1.0.103.md ]] || fail 'Notas da entrega 1.0.103 ausentes.'
grep -q 'stadiaRasterCreditsPerTile = 1' lib/services/offline_map_service.dart \
  || fail 'Custo de credito do tile raster nao esta centralizado.'
grep -q 'stadiaFreePlanReferenceCredits = 200000' lib/services/offline_map_service.dart \
  || fail 'Referencia de creditos do plano gratuito nao encontrada.'
grep -q 'stadiaCreditsUsedThisMonth' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Contador mensal local de creditos nao encontrado.'
grep -q 'stadiaMonthlyCreditLimit' lib/services/offline_map_service.dart lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Limite mensal configuravel de creditos nao encontrado.'
grep -q 'Créditos estimados' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejador offline nao mostra estimativa de creditos.'
grep -q 'creditTooLarge' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Planejador offline nao bloqueia download acima do saldo local.'
grep -q '_maxZoomForBounds(baseBounds, planningBudgetBytes).toDouble(),' lib/widgets/offline_map_manager_sheet.dart \
  || fail 'Correcao do non-null assertion do Android-APK-71 nao encontrada.'
[[ -f test/offline_map_credit_budget_test.dart ]] \
  || fail 'Teste do orçamento de creditos offline nao encontrado.'

# Otimizacao Android-APK-74 - 1.0.106
grep -q '^## 1.0.106+106' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.106.'
grep -q 'Otimização 1.0.106' README.md || fail 'README nao documenta 1.0.106.'
grep -q "version: '1.0.106'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.106.'
[[ -f RELEASE-1.0.106.md ]] || fail 'Notas da entrega 1.0.106 ausentes.'
grep -q 'gradle/actions/setup-gradle@v6' .github/workflows/android-apk.yml || fail 'Workflow nao usa setup-gradle v6.'
grep -q "gradle-version: '9.1.0'" .github/workflows/android-apk.yml || fail 'Workflow nao fixa Gradle 9.1.0.'
grep -q 'cache-cleanup: never' .github/workflows/android-apk.yml || fail 'Workflow nao prioriza build rapido no cache Gradle.'
grep -q 'VIGIAIA_CI_MULTI_APK' android/app/build.gradle.kts || fail 'Build Android nao possui modo multi-APK do CI.'
grep -q 'VIGIAIA_CI_MULTI_APK' .github/workflows/android-apk.yml || fail 'Workflow nao ativa multi-APK em uma unica compilacao.'
grep -q 'gradle :app:assembleRelease --build-cache --parallel' .github/workflows/android-apk.yml || fail 'Workflow nao usa assembleRelease unico otimizado.'
! grep -q 'flutter build apk --release --split-per-abi' .github/workflows/android-apk.yml || fail 'Workflow ainda executa a segunda compilacao split-per-abi.'
grep -q '^org.gradle.caching=true$' android/gradle.properties || fail 'Gradle build cache nao esta ativado.'
grep -q '^org.gradle.parallel=true$' android/gradle.properties || fail 'Gradle paralelo nao esta ativado.'
grep -q 'output-metadata.json' .github/workflows/android-apk.yml || fail 'Workflow nao descobre APKs via output-metadata.json.'

grep -q 'VigiaIA-v${VERSION}-source.zip' tool/package_source.sh || fail 'Empacotador nao inclui a versao completa no nome do ZIP.'
# Correcao Android-APK-75 - 1.0.107
grep -q '^## 1.0.107+107' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.107.'
grep -q 'Correção 1.0.107' README.md || fail 'README nao documenta 1.0.107.'
grep -q "version: '1.0.107'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.107.'
[[ -f RELEASE-1.0.107.md ]] || fail 'Notas da entrega 1.0.107 ausentes.'
if grep -q 'id("kotlin-android")' android/app/build.gradle.kts; then
  fail 'Android-APK-75: modulo app voltou a aplicar kotlin-android explicitamente.'
fi
if grep -q 'kotlinOptions[[:space:]]*{' android/app/build.gradle.kts; then
  fail 'Android-APK-75: bloco kotlinOptions legado voltou ao modulo app.'
fi
grep -q '^kotlin {' android/app/build.gradle.kts || fail 'Android-APK-75: bloco kotlin moderno ausente.'
grep -q 'jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17' android/app/build.gradle.kts \
  || fail 'Android-APK-75: jvmTarget moderno JVM_17 ausente.'


# Evolucao do mapa no monitor - 1.0.109
grep -Fq '## 1.0.109+109' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.109.'
grep -q 'Evolução 1.0.109' README.md || fail 'README nao documenta 1.0.109.'
grep -q "version: '1.0.109'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.109.'
[[ -f RELEASE-1.0.109.md ]] || fail 'Notas da entrega 1.0.109 ausentes.'
grep -q "Mostrar mapa" lib/screens/monitor_screen_fullscreen.dart || fail 'Menu do monitor nao oferece Mostrar mapa.'
grep -q "Ocultar mapa" lib/screens/monitor_screen_fullscreen.dart || fail 'Menu do monitor nao oferece Ocultar mapa.'
grep -q "Mapa automático" lib/screens/monitor_screen_fullscreen.dart || fail 'Menu do monitor nao oferece Mapa automatico.'
grep -q '_setMonitorMapVisibilityQuick' lib/screens/monitor_screen_fullscreen.dart || fail 'Atalho rapido de mapa nao foi implementado.'
[[ -f android/app/src/main/res/mipmap/ic_launcher.xml ]] || fail 'Android-APK-76: mipmap/ic_launcher ausente.'
[[ -f android/app/src/main/res/values/styles.xml ]] || fail 'Android-APK-76: values/styles.xml ausente.'
[[ -f android/app/src/main/res/values-night/styles.xml ]] || fail 'Android-APK-76: values-night/styles.xml ausente.'
[[ -f android/app/src/main/res/drawable/launch_background.xml ]] || fail 'Android-APK-76: launch_background ausente.'
grep -q 'name="LaunchTheme"' android/app/src/main/res/values/styles.xml || fail 'Android-APK-76: LaunchTheme ausente.'
grep -q 'name="NormalTheme"' android/app/src/main/res/values/styles.xml || fail 'Android-APK-76: NormalTheme ausente.'
grep -q 'android/app/src/main/res/values/styles.xml' .github/workflows/android-apk.yml || fail 'Workflow nao verifica integridade dos recursos Android.'

# Evolucao do quinto botao e correcao Android-APK-78 - 1.0.110
grep -Fq '## 1.0.110+110' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.110.'
grep -q 'Evolução 1.0.110' README.md || fail 'README nao documenta 1.0.110.'
grep -q "version: '1.0.110'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.110.'
[[ -f RELEASE-1.0.110.md ]] || fail 'Notas da entrega 1.0.110 ausentes.'
grep -q "label: 'Mapa'" lib/screens/monitor_screen_portrait.dart || fail 'Botao Mapa nao foi adicionado a fileira fixa.'
grep -q 'MonitorMapVisibilityMode.hidden' lib/screens/monitor_screen_portrait.dart || fail 'Botao Mapa nao oculta o mini mapa.'
grep -q 'MonitorMapVisibilityMode.always' lib/screens/monitor_screen_portrait.dart || fail 'Botao Mapa nao mostra o mini mapa.'
[[ -f .gitignore ]] || fail 'Android-APK-78: .gitignore ausente.'
grep -Fxq '*.jks' .gitignore || fail 'Android-APK-78: .gitignore nao bloqueia arquivos JKS.'
grep -Fxq '*.keystore' .gitignore || fail 'Android-APK-78: .gitignore nao bloqueia arquivos keystore.'
grep -Fxq 'android/key.properties' .gitignore || fail 'Android-APK-78: .gitignore nao bloqueia key.properties.'
grep -Fq "'.gitignore'" tool/package_source.sh || fail 'Empacotador nao exige .gitignore no ZIP-fonte.'



# Evolucao do mapa e percurso com lista offline e alertas - 1.0.111
grep -Fq '## 1.0.112+112' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.112.'
grep -q 'Evolução 1.0.112' README.md || fail 'README nao documenta 1.0.112.'
grep -q "version: '1.0.112'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.112.'
[[ -f RELEASE-1.0.112.md ]] || fail 'Notas da entrega 1.0.112 ausentes.'
[[ -f lib/services/route_explorer_service.dart ]] || fail 'RouteExplorerService ausente.'
[[ -f lib/models/route_explorer_models.dart ]] || fail 'Modelos de RouteExplorer ausentes.'
[[ -f lib/screens/monitor_screen_map_explorer.dart ]] || fail 'Painel Mapa e percurso ausente.'
grep -q '_showMapExplorerSheet' lib/screens/monitor_screen_portrait.dart || fail 'Botao Mapa do retrato nao abre o painel Mapa e percurso.'
grep -q '_showMapExplorerSheet' lib/screens/monitor_screen_landscape_dashboard.dart || fail 'Botao Mapa da paisagem nao abre o painel Mapa e percurso.'
grep -q 'Próximos pontos' lib/screens/monitor_screen_map_explorer.dart || fail 'Botao Mapa nao abre Proximos pontos.'
grep -q 'Configurações do mapa e percurso' lib/screens/monitor_screen_map_explorer.dart || fail 'Configuracoes do mapa nao foram separadas.'
grep -q 'Mapas offline' lib/screens/monitor_screen_map_explorer.dart || fail 'Painel Mapa e percurso nao oferece Mapas offline.'
grep -q 'searchNow' lib/services/route_explorer_service.dart || fail 'RouteExplorerService nao implementa busca.'
grep -q 'saveCurrentResultsOffline' lib/services/route_explorer_service.dart || fail 'RouteExplorerService nao implementa lista offline.'
grep -q '_evaluateAlerts' lib/services/route_explorer_service.dart || fail 'RouteExplorerService nao implementa alertas de aproximacao.'

# Redesenho Mapa/Câmera - 1.0.112
grep -q "enum _MonitorPrimaryContentMode" lib/screens/monitor_screen.dart || fail 'Modo principal camera/mapa ausente.'
grep -q "_MonitorPrimaryContentMode.map" lib/screens/monitor_screen_portrait.dart || fail 'Retrato nao suporta mapa na area principal.'
grep -q "label: Text('Mapa')" lib/screens/monitor_screen_multicamera.dart || fail 'Menu Camera nao oferece Mapa.'
grep -q "alertDistanceMeters" lib/models/route_explorer_models.dart || fail 'Distancia configuravel de alerta ausente.'
grep -q "clearOfflineResults" lib/services/route_explorer_service.dart || fail 'Exclusao de pontos offline ausente.'


# Assets da Home + Histórico/Câmeras compactos - 1.0.119
grep -Fq '## 1.0.119+119' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.119.'
grep -q 'Evolução 1.0.119' README.md || fail 'README nao documenta 1.0.119.'
grep -q "version: '1.0.119'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.119.'
[[ -f RELEASE-1.0.119.md ]] || fail 'Notas da entrega 1.0.119 ausentes.'
for asset in live transmission remote esp32; do
  [[ -f "assets/images/modes/${asset}.png" ]] || fail "Asset de modo ausente: ${asset}.png"
done
grep -q "imageAsset: 'assets/images/modes/live.png'" lib/screens/home_screen_redesign.dart || fail 'Home nao usa o asset Ao vivo.'
grep -q "imageAsset: 'assets/images/modes/transmission.png'" lib/screens/home_screen_redesign.dart || fail 'Home nao usa o asset Transmissao.'
grep -q "imageAsset: 'assets/images/modes/remote.png'" lib/screens/home_screen_redesign.dart || fail 'Home nao usa o asset Remoto.'
grep -q "imageAsset: 'assets/images/modes/esp32.png'" lib/screens/home_screen_redesign.dart || fail 'Home nao usa o asset ESP32.'
grep -q "'Veículos'" lib/screens/events_screen.dart || fail 'Historico nao usa rotulo Veiculos corrigido.'
grep -q "child: Text('Duas câmeras')" lib/screens/multi_camera_screen_components.dart || fail 'Acao de segunda camera nao foi preservada no menu.'
grep -q 'minimumSize: const Size(0, 38)' lib/screens/multi_camera_screen_components.dart || fail 'Botao Monitorar compacto ausente.'

# Voz configuravel + qualidade Bike - 1.0.118
grep -Fq '## 1.0.118+118' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.118.'
grep -q 'Evolução 1.0.118' README.md || fail 'README nao documenta 1.0.118.'
grep -q "version: '1.0.118'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.118.'
[[ -f RELEASE-1.0.118.md ]] || fail 'Notas da entrega 1.0.118 ausentes.'
grep -q 'class VoiceAlertPreferences' lib/models/alert_preferences.dart || fail 'Preferencias finas de voz ausentes.'
grep -q 'mutedSlots' lib/models/alert_preferences.dart || fail 'Controle por slot de audio ausente.'
grep -q 'ttsFallbackEnabled = false' lib/models/alert_preferences.dart || fail 'Fallback TTS nao inicia desativado.'
grep -q 'dynamicTtsEnabled = true' lib/models/alert_preferences.dart || fail 'Controle de TTS dinamico ausente.'
grep -q 'suppressed_by_user' lib/services/alert_voice_service.dart || fail 'AlertVoiceService nao respeita falas silenciadas.'
grep -q 'native_failed_tts_disabled' lib/services/alert_voice_service.dart || fail 'Fallback TTS opcional nao esta implementado.'
grep -q 'Ativar todas' lib/screens/audio_settings_screen.dart || fail 'Tela de audio nao permite ativar todas as falas.'
grep -q 'Silenciar' lib/screens/audio_settings_screen.dart || fail 'Tela de audio nao permite silenciar todas as falas.'
grep -q 'onEnabledChanged' lib/screens/audio_settings_screen.dart || fail 'Switch individual por fala ausente.'
grep -q '_announceScenario' lib/screens/esp32_settings_screen.dart || fail 'Emulador ESP32 nao dispara falas integradas.'
if grep -q 'future: true' lib/models/audio_slot.dart; then fail 'Slots Bike ainda aparecem marcados como futuros.'; fi
grep -q 'expect(config.streamFpsCap, 7)' test/bike_mode_config_test.dart || fail 'Perfil Economia nao foi atualizado para 7 FPS.'
grep -q 'expect(config.powerProfile.targetJpegWidth, 960)' test/bike_mode_config_test.dart || fail 'Perfil Economia nao preserva 960 px.'
grep -q 'expect(config.powerProfile.targetJpegQuality, 76)' test/bike_mode_config_test.dart || fail 'Perfil Economia nao preserva JPEG 76.'
grep -q 'expect(config.streamFpsCap, 5)' test/bike_mode_config_test.dart || fail 'Economia extrema nao foi atualizada para 5 FPS.'
grep -q 'expect(config.powerProfile.targetJpegQuality, 72)' test/bike_mode_config_test.dart || fail 'Economia extrema nao usa JPEG 72.'
python3 tool/verify_audio_resource_catalog.py || fail 'Catalogo de audio integrado divergiu.'

# Reorganizacao Home/Bike/ESP32/Transmissao - 1.0.117
grep -Fq '## 1.0.117+117' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.117.'
grep -q 'Evolução 1.0.117' README.md || fail 'README nao documenta 1.0.117.'
grep -q "version: '1.0.117'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.117.'
[[ -f RELEASE-1.0.117.md ]] || fail 'Notas da entrega 1.0.117 ausentes.'
grep -q "title: 'Ao vivo'" lib/screens/home_screen_redesign.dart || fail 'Home nao oferece Ao vivo.'
grep -q "title: 'Transmissão'" lib/screens/home_screen_redesign.dart || fail 'Home nao oferece Transmissao.'
grep -q "title: 'Remoto'" lib/screens/home_screen_redesign.dart || fail 'Home nao oferece Remoto.'
grep -q "title: 'ESP32'" lib/screens/home_screen_redesign.dart || fail 'Home nao oferece ESP32.'
if grep -q "title: 'Modo Bike'" lib/screens/home_screen_redesign.dart; then fail 'Bike ainda aparece como card operacional na Home.'; fi
grep -q 'crossAxisCount: 5' lib/screens/home_screen_redesign.dart || fail 'Acessos rapidos nao estao em cinco colunas.'
grep -q "title: 'Bike e economia'" lib/screens/settings_screen.dart || fail 'Bike e economia nao esta em Ajustes.'
if grep -q "title: 'Modo Bike'" lib/screens/launch_mode_screen.dart; then fail 'Bike ainda aparece como modo inicial.'; fi
grep -q 'parsed == AppLaunchMode.bike ? AppLaunchMode.normal' lib/services/app_launch_mode_service.dart || fail 'Migracao do modo Bike legado ausente.'
grep -q "tooltip: 'Ferramentas do ESP32'" lib/screens/esp32_settings_screen.dart || fail 'Engrenagem do ESP32 ausente.'
grep -q "'Emulador de sensores'" lib/screens/esp32_settings_screen.dart || fail 'Emulador ESP32 nao foi movido para ferramentas.'
grep -q "tooltip: 'Bike e economia'" lib/screens/camera_mode_screen.dart || fail 'Engrenagem de economia ausente na Transmissao.'
grep -q 'Bateria deste aparelho' lib/screens/camera_mode_screen.dart || fail 'Bateria local nao aparece na Transmissao.'
grep -q 'transmissionFrameInterval' lib/models/bike_mode_config.dart || fail 'Intervalo de transmissao separado da IA ausente.'
grep -q 'analysisInterval: _bikeConfig.transmissionFrameInterval' lib/services/remote_camera_server_service.dart || fail 'Servidor remoto nao usa politica de FPS da transmissao.'

# Correcao Android-APK-84 - 1.0.116
grep -Fq '## 1.0.116+116' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.116.'
grep -q 'Correção 1.0.116' README.md || fail 'README nao documenta 1.0.116.'
grep -q "version: '1.0.116'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.116.'
[[ -f RELEASE-1.0.116.md ]] || fail 'Notas da entrega 1.0.116 ausentes.'
grep -q 'this.dense = false' lib/widgets/vigia_ui.dart || fail 'VigiaStatusPill nao oferece variante densa.'
grep -q 'dense: compact' lib/widgets/vigia_ui.dart || fail 'Card compacto nao usa pills densas.'
grep -q 'padding: EdgeInsets.all(compact ? 9 : 18)' lib/widgets/vigia_ui.dart || fail 'Card compacto nao recebeu padding seguro do Android-APK-84.'
grep -q 'final compact = constraints.maxWidth < 66' lib/widgets/vigia_ui.dart || fail 'Acesso rapido nao possui compactacao adaptativa.'
grep -q 'VigiaIA/1.0.131' lib/services/route_explorer_service.dart || fail 'User-Agent do RouteExplorer nao acompanha a versao atual.'
grep -q "modo compacto cabe em celula estreita da Home" test/vigia_ui_test.dart || fail 'Teste de overflow do card compacto ausente.'
grep -q "acao rapida Diagnostico cabe na grade responsiva" test/vigia_ui_test.dart || fail 'Teste de overflow do acesso rapido ausente.'

# Compactacao Home/Mapa + ESP32 dedicado - 1.0.115
grep -Fq '## 1.0.115+115' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.115.'
grep -q 'Evolução 1.0.115' README.md || fail 'README nao documenta 1.0.115.'
grep -q "version: '1.0.115'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.115.'
[[ -f RELEASE-1.0.115.md ]] || fail 'Notas da entrega 1.0.115 ausentes.'
grep -q 'compact: true' lib/screens/home_screen_redesign.dart || fail 'Cards compactos da Home ausentes.'
grep -q "title: 'ESP32'" lib/screens/home_screen_redesign.dart || fail 'Home nao oferece modulo ESP32 dedicado.'
grep -q 'Esp32SettingsScreen' lib/screens/home_screen_redesign.dart || fail 'Card ESP32 nao abre a configuracao existente.'
if grep -q "title: 'ESP32 e sensores'" lib/screens/settings_screen.dart; then
  fail 'Atalho duplicado de ESP32 continua em Ajustes > Monitoramento.'
fi
grep -q '_compactCategoryLabel' lib/screens/monitor_screen_map_explorer.dart || fail 'Categorias compactas do mapa ausentes.'
grep -q "label: const Text('Salvar pacote')" lib/screens/monitor_screen_map_explorer.dart || fail 'Acao offline Salvar pacote ausente.'
grep -q "label: 'Automático'" lib/screens/monitor_screen_map_explorer.dart || fail 'Preferencia compacta de mini mapa ausente.'
grep -q "modo compacto cabe em celula estreita da Home" test/vigia_ui_test.dart || fail 'Teste de regressao do card compacto ausente.'
grep -q "acao rapida Diagnostico cabe na grade responsiva" test/vigia_ui_test.dart || fail 'Teste de regressao dos acessos rapidos ausente.'

# Correcao Android-APK-82 - 1.0.114
grep -Fq '## 1.0.114+114' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.114.'
grep -q 'Correção 1.0.114' README.md || fail 'README nao documenta 1.0.114.'
grep -q "version: '1.0.114'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.114.'
[[ -f RELEASE-1.0.114.md ]] || fail 'Notas da entrega 1.0.114 ausentes.'
if grep -q 'minSize:' lib/core/vigia_design.dart; then
  fail 'ButtonStyle.minSize invalido reapareceu no design system.'
fi
grep -q 'minimumSize:' lib/core/vigia_design.dart || fail 'ButtonStyle.minimumSize ausente do design system.'
if grep -q '^[[:space:]]*setState(' lib/screens/home_screen_redesign.dart; then
  fail 'Extension da Home voltou a chamar setState diretamente.'
fi
if grep -q 'class _LiveDot' lib/screens/home_screen_components.dart || grep -q 'class _MetricChip' lib/screens/home_screen_components.dart; then
  fail 'Componentes privados sem uso do Android-APK-82 reapareceram na Home.'
fi
if grep -q '_showLandscapeQuickActions' lib/screens/monitor_screen_landscape_dashboard.dart; then
  fail 'Metodo privado sem uso do Android-APK-82 reapareceu no monitor paisagem.'
fi

# Fundacao do redesign amplo - 1.0.113
grep -Fq '## 1.0.113+113' CHANGELOG.md || fail 'CHANGELOG nao documenta 1.0.113.'
grep -q 'Evolução 1.0.113' README.md || fail 'README nao documenta 1.0.113.'
grep -q "version: '1.0.113'" lib/screens/app_info_screen_components.dart || fail 'Tela de Mudancas nao documenta 1.0.113.'
[[ -f RELEASE-1.0.113.md ]] || fail 'Notas da entrega 1.0.113 ausentes.'
[[ -f lib/core/vigia_design.dart ]] || fail 'Design system compartilhado ausente.'
[[ -f lib/widgets/vigia_ui.dart ]] || fail 'Componentes visuais compartilhados ausentes.'
grep -q "title: 'Ao vivo'" lib/screens/home_screen*.dart || fail 'Home nao destaca Ao vivo.'
grep -q "title: 'Transmissão'" lib/screens/home_screen*.dart || fail 'Home nao destaca Transmissao.'
grep -q "title: 'Remoto'" lib/screens/home_screen*.dart || fail 'Home nao destaca Remoto.'
grep -q "label: 'Diagnóstico'" lib/screens/home_screen*.dart || fail 'Home nao oferece acesso rapido ao Diagnostico.'
grep -q "label: 'Ajustes'" lib/widgets/main_navigation_bar.dart || fail 'Navegacao principal nao inclui Ajustes.'
