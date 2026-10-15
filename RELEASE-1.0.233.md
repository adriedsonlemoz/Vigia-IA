# Vigia IA 1.0.233+233 — primeira etapa da refatoração gradual

Data: 2026-10-15.

## Alteração

Extrai widgets de indicadores de bateria/GPS/velocidade e controles de zoom em dois módulos de apresentação, sem mudanças de interface, serviços, persistência ou funcionalidades. A tela principal permaneceu proprietária dos callbacks.

## Verificação

O projeto foi confrontado com o ZIP funcional 1.0.232. Verificações locais de contratos, imports, versionamento, YAML/JSON/XML e pacote serão executadas. Os novos testes de widget exigem Flutter SDK: o `flutter analyze`, `flutter test` e build Android precisam de aprovação no GitHub Actions antes de promover a versão como funcional.

## Compatibilidade

Nenhuma migração de dados ou alteração em permissões, rotas, mapas, câmeras, GPS, IA, ESP32, rádio ou serviços foi efetuada. O projeto Android tem Gradle configurado para derivar `versionCode=233` e `versionName=1.0.233` de `pubspec.yaml`.
