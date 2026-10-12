# Vigia IA — Release 1.0.227+227

Data: 12/10/2026 · versionCode 227 · correção Android APK #188

## Falha observada

O workflow #188 compilou as fontes 1.0.226+226 até o estágio de testes: `flutter analyze` sem problemas; **429 testes passaram e 1 falhou** em `map_poi_details_sheet_test.dart`. A tela de POI apresentou dois overflows horizontais de 60 e 35 pixels devido ao rótulo `_InfoPill` sem restrição de largura. APK não foi gerado no #188.

## Correção

- `Flexible`/`softWrap` nos textos das etiquetas de origem e distância de POI.
- Botões “Mostrar no mapa” e “Ir até lá” organizados em coluna em tela estreita/fonte ampliada; callbacks originais mantidos.
- Teste de widget para 320/360/412 dp e texto 1,0x/1,5x.
- Regressores Python para impedimento das mesmas falhas.
- Funcionalidades anteriores preservadas; sem novas dependências ou alterações em banco de dados/permissões.

## Estado de validação

`bash tool/verify_project.sh` e testes Python executados localmente. Não há SDK Flutter local para executar o analyzer, Flutter widget tests nem APK. É necessário executar o GitHub Actions sobre **1.0.227+227** antes de instalar; nenhuma compilação Android é declarada aprovada nesta entrega.

## Próximo planejamento

Retomar melhorias de HUD e diálogos responsivos após confirmação do workflow, na 1.0.228 ou versão posterior, sem acumular modificações grandes no buildfix.
