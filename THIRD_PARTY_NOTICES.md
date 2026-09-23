# Dependencias principais

Este projeto usa pacotes Flutter e bibliotecas nativas de terceiros. Antes de distribuir publicamente o APK, revise e cumpra as licencas de todas as dependencias resolvidas pelo `pub` e, em especial, os requisitos de redistribuicao do VLC/libVLC usados por `vlc_player`.

Os modelos de detecção usados pelo projeto são o EfficientDet-Lite0 com metadata, como opção principal, e o SSD MobileNet V1 com metadata como fallback de inicialização e alternativa automática após lentidão persistente. Ambos são obtidos de artefatos publicados pelo Google para TensorFlow Lite/LiteRT por `tool/fetch_model.sh`.

A inferencia local usa o pacote `flutter_litert` fixado em `3.8.0`, com Interpreter nativo e solicitação do delegate XNNPACK, mantendo compatibilidade com modelos `.tflite` e a API Interpreter usada pelo projeto.


O pareamento por QR usa `qr_flutter` para renderização local e `mobile_scanner` para leitura. No Android, o projeto mantém a configuração padrão com o leitor ML Kit embarcado no aplicativo para que a leitura de QR não dependa de download em tempo de uso. Consulte as licenças resolvidas pelo `pub` antes da distribuição.

O suporte a mapas offline raster usa `flutter_map_mbtiles` 1.0.4 (licença MIT), que integra arquivos MBTiles locais ao `flutter_map` e depende de `mbtiles`/SQLite. Os arquivos `.mbtiles` baixados pelo usuário continuam sujeitos à licença e aos termos da fonte que os distribui; o Vigia IA não realiza download em massa do servidor público `tile.openstreetmap.org`.

A 1.0.99 adiciona uso direto de `sqlite3` 2.9.4 (licença MIT) para gerar e ler a estrutura MBTiles raster no aparelho.

O download direto de região/trajeto oferece integração opcional com **Stadia Maps**. A API key é fornecida pelo próprio usuário e não acompanha o projeto. O cache offline exige uma conta/plano do provedor que autorize esse uso. O uso, cache, atribuição e limites continuam sujeitos aos termos vigentes; o aplicativo controla o total do cache direto em até 100 MB por aparelho e mantém a atribuição da camada.
