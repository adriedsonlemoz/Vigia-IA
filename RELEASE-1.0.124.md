# Vigia IA 1.0.124+124

## Refinamento dos sensores ESP32

Esta versão concentra a tela ESP32 em observabilidade por sensor/recurso, sem alterações no mapa.

- O card de cada módulo passa a ter a seção **Sensores e recursos**.
- Cada capacidade diferencia **Lendo agora**, **Detectado**, **Aguardando leitura**, **Módulo offline** e **Detectado · não configurado**.
- Temperatura, Hall, pneus, bateria do módulo e energia exibem seus valores na própria linha.
- Valores reais permitem inferir capacidades básicas de firmware legado mesmo sem uma lista `capabilities`.
- Recursos anunciados pelo firmware que ainda não estão no cadastro aparecem para revisão no wizard, sem serem ativados automaticamente.
- Rede e transporte ficam separados no bloco **Conexão**, com Wi-Fi, endpoint, uptime, sequência, falhas e reconexão.
- Foram adicionados testes específicos para os estados de sensores e para a inferência de firmware legado.

## Compatibilidade

A mudança é apenas derivada do cadastro e da telemetria já existente. Nenhuma migração de dados é necessária e módulos das versões 1.0.120–1.0.123 permanecem compatíveis.

## Validação

`tool/check_version_sync.py` e `tool/verify_project.sh` devem passar antes da entrega. O ambiente de empacotamento atual não inclui Flutter/Android SDK, então `flutter analyze`, `flutter test` e APK permanecem a cargo do workflow Android.
