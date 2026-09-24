# Vigia IA 1.0.115+115

## Entrega

Compactação da Home e das configurações do mapa, com acesso dedicado ao módulo ESP32. A mudança segue a direção do redesign iniciado na 1.0.113 e não substitui serviços existentes.

## Home

- quatro cards principais em grade 2x2 no celular: **Monitor ao vivo**, **Modo transmissão**, **Modo Bike** e **ESP32**;
- `VigiaModeCard` usa variante compacta com ícone, descrição curta e tags reduzidas;
- telas largas exibem os quatro módulos na mesma linha;
- acessos rápidos usam grade responsiva para evitar rótulos cortados.

## ESP32

- novo card dedicado na Home abre diretamente `Esp32SettingsScreen`;
- reaproveita cadastro, teste de conexão, Hall, temperatura, pneus, calibração, telemetria e câmera já existentes;
- removido o atalho duplicado de **Ajustes > Monitoramento**, sem remover qualquer função do ESP32.

## Mapa e percurso

- raio e modo de busca compactados;
- categorias menores com ícones;
- alertas, voz e notificação passam a chips compactos;
- distância do aviso passa a escolhas rápidas 1/3/5/10 km;
- ações offline organizadas em grade 2x2;
- mini mapa usa escolhas compactas Automático/Sempre/Ocultar;
- `RouteExplorerService`, `MapRouteService`, dados offline e alertas permanecem como única implementação funcional.

## Validação

Executar:

```bash
python3 tool/check_version_sync.py
bash tool/verify_project.sh
```

O ambiente local desta entrega não possui Flutter/Android SDK. O workflow deve confirmar `flutter analyze`, `flutter test` e a compilação release.
