class AudioSlotDefinition {
  const AudioSlotDefinition({
    required this.id,
    required this.title,
    required this.phrase,
    required this.section,
    this.future = false,
  });

  final String id;
  final String title;
  final String phrase;
  final String section;
  final bool future;
}

abstract final class AudioSlotIds {
  static const personDetected = 'person_detected';
  static const vehicleDetected = 'vehicle_detected';
  static const animalDetected = 'animal_detected';
  static const objectDetected = 'object_detected';
  static const personEntered = 'person_entered';
  static const personExited = 'person_exited';
  static const vehicleEntered = 'vehicle_entered';
  static const vehicleExited = 'vehicle_exited';
  static const animalEntered = 'animal_entered';
  static const animalExited = 'animal_exited';
  static const objectEntered = 'object_entered';
  static const objectExited = 'object_exited';
  static const cameraObstructed = 'camera_obstructed';
  static const cameraMoved = 'camera_moved';
}

abstract final class AudioSlotCatalog {
  static const List<AudioSlotDefinition> all = <AudioSlotDefinition>[
    AudioSlotDefinition(id: 'person_detected', title: 'Pessoa detectada', phrase: 'Pessoa detectada.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'vehicle_detected', title: 'Automóvel detectado', phrase: 'Automóvel detectado.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'animal_detected', title: 'Animal detectado', phrase: 'Animal detectado.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'object_detected', title: 'Objeto detectado', phrase: 'Objeto detectado.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'person_entered', title: 'Pessoa entrou', phrase: 'Pessoa entrou na área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'person_exited', title: 'Pessoa saiu', phrase: 'Pessoa saiu da área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'vehicle_entered', title: 'Automóvel entrou', phrase: 'Automóvel entrou na área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'vehicle_exited', title: 'Automóvel saiu', phrase: 'Automóvel saiu da área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'animal_entered', title: 'Animal entrou', phrase: 'Animal entrou na área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'animal_exited', title: 'Animal saiu', phrase: 'Animal saiu da área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'object_entered', title: 'Objeto entrou', phrase: 'Objeto entrou na área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'object_exited', title: 'Objeto saiu', phrase: 'Objeto saiu da área.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'camera_obstructed', title: 'Câmera obstruída', phrase: 'Câmera obstruída.', section: 'Monitoramento'),
    AudioSlotDefinition(id: 'camera_moved', title: 'Câmera deslocada', phrase: 'Câmera deslocada.', section: 'Monitoramento'),

    AudioSlotDefinition(id: 'bike_front_pressure_low', title: 'Pressão baixa dianteira', phrase: 'Pressão baixa no pneu dianteiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_rear_pressure_low', title: 'Pressão baixa traseira', phrase: 'Pressão baixa no pneu traseiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_front_pressure_critical', title: 'Pressão crítica dianteira', phrase: 'Pressão crítica no pneu dianteiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_rear_pressure_critical', title: 'Pressão crítica traseira', phrase: 'Pressão crítica no pneu traseiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_front_pressure_high', title: 'Pressão alta dianteira', phrase: 'Pressão alta no pneu dianteiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_rear_pressure_high', title: 'Pressão alta traseira', phrase: 'Pressão alta no pneu traseiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_front_temperature_high', title: 'Temperatura dianteira elevada', phrase: 'Temperatura elevada no pneu dianteiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_rear_temperature_high', title: 'Temperatura traseira elevada', phrase: 'Temperatura elevada no pneu traseiro.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_front_sensor_lost', title: 'Sensor dianteiro desconectado', phrase: 'Sensor do pneu dianteiro desconectado.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_rear_sensor_lost', title: 'Sensor traseiro desconectado', phrase: 'Sensor do pneu traseiro desconectado.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_speed_sensor_connected', title: 'Sensor de velocidade conectado', phrase: 'Sensor de velocidade conectado.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_speed_sensor_disconnected', title: 'Sensor de velocidade desconectado', phrase: 'Sensor de velocidade desconectado.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_speed_limit', title: 'Limite de velocidade', phrase: 'Velocidade acima do limite configurado.', section: 'Bike · Pneus e sensores'),
    AudioSlotDefinition(id: 'bike_wheel_sensor_no_response', title: 'Sensor da roda sem resposta', phrase: 'Sensor da roda sem resposta.', section: 'Bike · Pneus e sensores'),

    AudioSlotDefinition(id: 'bike_module_connected', title: 'Módulo conectado', phrase: 'Módulo da bicicleta conectado.', section: 'Bike · ESP32'),
    AudioSlotDefinition(id: 'bike_module_disconnected', title: 'Módulo desconectado', phrase: 'Módulo da bicicleta desconectado.', section: 'Bike · ESP32'),
    AudioSlotDefinition(id: 'bike_module_communication_failed', title: 'Falha de comunicação', phrase: 'Falha de comunicação com o módulo da bicicleta.', section: 'Bike · ESP32'),
    AudioSlotDefinition(id: 'bike_module_communication_restored', title: 'Comunicação restabelecida', phrase: 'Comunicação com o módulo da bicicleta restabelecida.', section: 'Bike · ESP32'),
    AudioSlotDefinition(id: 'bike_module_battery_low', title: 'Bateria do módulo baixa', phrase: 'Bateria do módulo da bicicleta baixa.', section: 'Bike · ESP32'),
    AudioSlotDefinition(id: 'bike_module_battery_critical', title: 'Bateria do módulo crítica', phrase: 'Bateria do módulo da bicicleta crítica.', section: 'Bike · ESP32'),

    AudioSlotDefinition(id: 'bike_rear_phone_battery_low', title: 'Bateria traseira baixa', phrase: 'Bateria do celular traseiro baixa.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_battery_critical', title: 'Bateria traseira crítica', phrase: 'Bateria do celular traseiro crítica.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_charging', title: 'Celular traseiro carregando', phrase: 'Celular traseiro carregando.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_charging_interrupted', title: 'Carga traseira interrompida', phrase: 'Carregamento do celular traseiro interrompido.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_temperature_high', title: 'Temperatura traseira elevada', phrase: 'Temperatura do celular traseiro elevada.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_temperature_critical', title: 'Temperatura traseira crítica', phrase: 'Temperatura do celular traseiro crítica.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_connection_lost', title: 'Conexão traseira perdida', phrase: 'Conexão com o celular traseiro perdida.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_rear_phone_connection_restored', title: 'Conexão traseira restabelecida', phrase: 'Conexão com o celular traseiro restabelecida.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_camera_signal_lost', title: 'Sinal da câmera perdido', phrase: 'Sinal da câmera traseira perdido.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_camera_signal_restored', title: 'Sinal da câmera restabelecido', phrase: 'Sinal da câmera traseira restabelecido.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_camera_obstructed', title: 'Câmera traseira obstruída', phrase: 'Câmera traseira obstruída.', section: 'Bike · Celular traseiro'),
    AudioSlotDefinition(id: 'bike_camera_normalized', title: 'Câmera traseira normalizada', phrase: 'Câmera traseira normalizada.', section: 'Bike · Celular traseiro'),

    AudioSlotDefinition(id: 'bike_mode_enabled', title: 'Modo Bike ativado', phrase: 'Modo Bike ativado.', section: 'Bike · Operação'),
    AudioSlotDefinition(id: 'bike_mode_disabled', title: 'Modo Bike desativado', phrase: 'Modo Bike desativado.', section: 'Bike · Operação'),
    AudioSlotDefinition(id: 'bike_monitoring_started', title: 'Monitoramento iniciado', phrase: 'Monitoramento da bicicleta iniciado.', section: 'Bike · Operação'),
    AudioSlotDefinition(id: 'bike_monitoring_stopped', title: 'Monitoramento encerrado', phrase: 'Monitoramento da bicicleta encerrado.', section: 'Bike · Operação'),

    AudioSlotDefinition(id: 'bike_headlight_on', title: 'Farol dianteiro ligado', phrase: 'Farol dianteiro ligado.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_headlight_off', title: 'Farol dianteiro desligado', phrase: 'Farol dianteiro desligado.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_rear_light_on', title: 'Luz traseira ligada', phrase: 'Luz traseira ligada.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_rear_light_off', title: 'Luz traseira desligada', phrase: 'Luz traseira desligada.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_lights_auto_on', title: 'Faróis automáticos ligados', phrase: 'Faróis ligados automaticamente.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_lights_auto_off', title: 'Faróis automáticos desligados', phrase: 'Faróis desligados automaticamente.', section: 'Bike · Iluminação'),
    AudioSlotDefinition(id: 'bike_light_sensor_lost', title: 'Sensor de iluminação desconectado', phrase: 'Sensor de iluminação desconectado.', section: 'Bike · Iluminação'),

    AudioSlotDefinition(id: 'bike_brake_light_on', title: 'Luz de freio acionada', phrase: 'Luz de freio acionada.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_brake_light_failure', title: 'Falha na luz de freio', phrase: 'Falha na luz de freio.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_front_brake_on', title: 'Freio dianteiro acionado', phrase: 'Freio dianteiro acionado.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_rear_brake_on', title: 'Freio traseiro acionado', phrase: 'Freio traseiro acionado.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_left_turn_on', title: 'Seta esquerda ligada', phrase: 'Seta esquerda ligada.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_right_turn_on', title: 'Seta direita ligada', phrase: 'Seta direita ligada.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_turn_signals_off', title: 'Setas desligadas', phrase: 'Setas desligadas.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_hazard_on', title: 'Pisca-alerta ligado', phrase: 'Pisca-alerta ligado.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_hazard_off', title: 'Pisca-alerta desligado', phrase: 'Pisca-alerta desligado.', section: 'Bike · Freios e setas'),
    AudioSlotDefinition(id: 'bike_brake_sensor_lost', title: 'Sensor de freio desconectado', phrase: 'Sensor de freio desconectado.', section: 'Bike · Freios e setas'),

    AudioSlotDefinition(id: 'bike_sensor_disconnected', title: 'Sensor da bicicleta desconectado', phrase: 'Sensor da bicicleta desconectado.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_sensor_reconnected', title: 'Sensor da bicicleta reconectado', phrase: 'Sensor da bicicleta reconectado.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_aux_battery_low', title: 'Bateria auxiliar baixa', phrase: 'Bateria auxiliar baixa.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_aux_battery_critical', title: 'Bateria auxiliar crítica', phrase: 'Bateria auxiliar crítica.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_aux_battery_charging', title: 'Bateria auxiliar carregando', phrase: 'Bateria auxiliar carregando.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_aux_battery_charging_interrupted', title: 'Carga auxiliar interrompida', phrase: 'Carregamento da bateria auxiliar interrompido.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_system_started', title: 'Sistema iniciado', phrase: 'Sistema da bicicleta iniciado.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_system_ready', title: 'Sistema pronto', phrase: 'Sistema da bicicleta pronto.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_system_shutting_down', title: 'Sistema desligando', phrase: 'Sistema da bicicleta desligando.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_system_failure', title: 'Falha no sistema', phrase: 'Falha detectada no sistema da bicicleta.', section: 'Bike · Sistema e energia'),
    AudioSlotDefinition(id: 'bike_all_sensors_ok', title: 'Sensores normais', phrase: 'Todos os sensores estão funcionando normalmente.', section: 'Bike · Sistema e energia'),
  ];

  static AudioSlotDefinition? find(String id) {
    for (final slot in all) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  static List<String> get sections {
    final result = <String>[];
    for (final slot in all) {
      if (!result.contains(slot.section)) result.add(slot.section);
    }
    return List<String>.unmodifiable(result);
  }
}
