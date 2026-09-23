# Vigia IA 1.0.91+91

## Resumo

Correção de build do Android-APK-59. O workflow parava em `flutter analyze` por causa do lint `unnecessary_underscores` em `monitor_screen_portrait.dart`.

## Correção

- `separatorBuilder: (_, __)` foi substituído por `separatorBuilder: (_, _)`.
- Foi adicionada uma verificação preventiva para impedir a reintrodução do padrão que causou o lint.
- A tela vertical, o mapa, a câmera, a IA e o modo transmissão permanecem funcionalmente iguais à 1.0.90.

## Escopo preservado

A alteração de política de orientação discutida anteriormente não faz parte desta entrega e permanece para a próxima etapa.
