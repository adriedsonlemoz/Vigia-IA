# Vigia IA 1.0.135+135

## Buildfix — Android-APK-102

Corrige a etapa de análise estática do workflow removendo cinco assertions nulas redundantes no card do POI selecionado em `MapMonitoringScreen`. O Dart já promove `selectedPoi` para não nulo quando o card é exibido, portanto os operadores `!` não tinham efeito e faziam o `flutter analyze` retornar código 1.

A rota ciclável introduzida na 1.0.134 permanece funcionalmente inalterada.
