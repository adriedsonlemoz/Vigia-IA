# Vigia IA 1.0.113+113

## Entrega

Primeira etapa do redesign amplo da interface. Esta versão cria a fundação visual compartilhada e reorganiza a Home para priorizar os modos principais e os acessos rápidos, sem remover as funções de monitoramento existentes.

## O que mudou

- design system central em `lib/core/vigia_design.dart`;
- componentes compartilhados em `lib/widgets/vigia_ui.dart`;
- Home com Monitor ao vivo, Modo transmissão e Modo Bike em destaque;
- acessos rápidos para Câmeras, Mapa, Histórico, Diagnóstico e Ajustes;
- configurações do monitor preservadas e recolhidas em Preparar monitoramento;
- navegação principal com cinco destinos e comportamento adaptativo mantido.

## Compatibilidade preservada

- IA, áudio, transmissão, multicâmera, ESP32, Bike, histórico e diagnóstico continuam usando as implementações existentes;
- RouteExplorerService, MapRouteService e mapas offline não foram duplicados;
- identidade `Vigia IA` / `vigiaia` / `com.vigiaia.app` preservada;
- workflow Android otimizado e política de assinatura preservados;
- nenhuma imagem ou mockup novo foi incorporado ao aplicativo.

## Validação local

Executar:

```bash
python3 tool/check_version_sync.py
bash tool/verify_project.sh
```

Flutter/Android SDK não estão disponíveis no ambiente desta entrega; `flutter analyze`, `flutter test` e a geração do APK devem ser confirmados no workflow Android.
