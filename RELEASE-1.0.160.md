# Vigia IA 1.0.160+160

Etapa 5 da evolução do mapa: navegação MapLibre vetorial, câmera adaptativa e follow controlável.

## Implementado

- Base vetorial no renderer 3D: Stadia Outdoors quando existe chave configurada; fallback para OpenFreeMap Liberty sem chave.
- Câmera seguindo posição e direção, com padding de navegação que mantém o usuário mais abaixo e aumenta a área útil da estrada à frente.
- Zoom e pitch adaptativos à velocidade e à distância da próxima manobra; em baixa velocidade a inclinação é reduzida e perto da conversão a câmera aproxima.
- Bearing derivado da geometria da rota quando o GPS não fornece rumo confiável.
- Gesto manual no mapa pausa o acompanhamento sem interromper GPS/rota; botão `Centralizar` retoma o follow.
- Prédios 3D por `FillExtrusionStyleLayer` quando a camada vetorial `building` está disponível, com falha não fatal e diagnóstico próprio.

## Preservado

- FlutterMap 2D montado como camada segura, gate de prontidão, transição suave, timeout de 9 segundos e fallback automático 3D → 2D.
- Offline/MBTiles no renderer 2D, rota, recálculo, GPS, voz, POIs, gravação, câmera e perfis Bicicleta/Moto/Carro/A pé.
- Nenhum efeito 3D é obrigatório para manter a navegação: ausência de prédios compatíveis não derruba o renderer.

## Validação

- Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`.
- Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android release precisam ser reconfirmados pelo workflow.
- O ZIP de código-fonte não deve conter APK/AAB.
