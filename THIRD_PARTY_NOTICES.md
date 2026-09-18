# Dependencias principais

Este projeto usa pacotes Flutter e bibliotecas nativas de terceiros. Antes de distribuir publicamente o APK, revise e cumpra as licencas de todas as dependencias resolvidas pelo `pub` e, em especial, os requisitos de redistribuicao do VLC/libVLC usados por `vlc_player`.

O modelo inicial e o SSD MobileNet V1 com metadata publicado pelo Google para TensorFlow Lite Task Library e e obtido pelo script `tool/fetch_model.sh`.

A inferencia local usa o pacote `flutter_litert`, mantendo compatibilidade com modelos `.tflite` e a API Interpreter usada pelo projeto.


O pareamento por QR usa `qr_flutter` para renderização local e `mobile_scanner` para leitura. No Android, o projeto mantém a configuração padrão com o leitor ML Kit embarcado no aplicativo para que a leitura de QR não dependa de download em tempo de uso. Consulte as licenças resolvidas pelo `pub` antes da distribuição.
