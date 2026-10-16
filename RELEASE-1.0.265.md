# Vigia IA 1.0.265+265 · Correção do Android APK 219

## Diagnóstico do CI

O exportador YOLO26s LiteRT **funcionou**: o modelo real de 38.319.452 bytes foi validado com entrada `[1,3,640,640]` e saída `[1,84,8400]`. O `flutter analyze` passou. A etapa `flutter test` somou 542 testes aprovados e uma falha: `test/detector_model_preference_test.dart` ainda exigia o padrão `Automático`, embora o padrão do produto seja `YOLO26s` desde 1.0.263.

## Correção

- Teste Flutter sincronizado com `DetectorModelPreference.yolo26s`; confirma que `Automático` continua selecionável.
- Verificador preventivo e três testes Python novos para evitar a regressão.
- Versionamento sequencial e notas/tela Sobre atualizados.
- Nenhuma alteração no modelo, decoder, transmissor, fallback, câmeras ou inferência.

## Validação pendente

A nova versão ainda precisa ser recompilada e testada via GitHub Actions. A exportação do modelo foi comprovada no APK 219, mas a presença do modelo no APK e sua execução em aparelho ainda não foram verificadas.
