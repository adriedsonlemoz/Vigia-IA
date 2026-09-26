# Vigia IA 1.0.163+163

## Escopo
Somente ETAPA 1 do plano do mapa: estabilização real do MapLibre 3D e orientação Norte/Direção/Rota.

## Entrega
- Inicialização 3D monitorada por estágio com timeout individual e primeiro frame confirmado por eventos reais do MapLibre.
- Preflight/sanitização de style, identificação de provider e fallback Stadia → OpenFreeMap quando aplicável; FlutterMap 2D continua sendo o fallback final.
- Diagnóstico exportável com estágio, mensagem original sanitizada, style/provider, rede, fallback e duração.
- Hybrid Composition no Android para a PlatformView 3D.
- Bússola Android nativa com rotation-vector ou acelerômetro+magnetômetro, sem fabricar heading.
- Modos Norte, Direção e Rota com prioridade inteligente de sensor/GPS/geometria, suavização, dead-zone, pausa por gesto e retomada por Centralizar.
- Popup Bússola com direção, graus, fonte e troca de modo.
- Popup Novidades exclusiva da versão atual.

## Compatibilidade e fallback
- Mapa 2D, offline, rota, perfis de transporte, voz, câmeras, POIs, gravação e demais funções existentes permanecem preservados.
- Prédios 3D são opcionais: ausência de source/layer não derruba a navegação.

## Validação local
Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Flutter/Dart devem ser executados em CI/ambiente com SDK disponível.
