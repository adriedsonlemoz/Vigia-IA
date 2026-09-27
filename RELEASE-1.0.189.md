# Vigia IA 1.0.189+189

Esta entrega corrige a abertura que podia ficar presa no indicador circular após uma atualização. O `_StartupGate` não aguarda mais a preparação de ESP32, sensores Bike e voz antes de mostrar a interface: ele resolve apenas onboarding e modo inicial, libera a tela e inicia os serviços opcionais depois do primeiro frame.

Também foram adicionados limites de espera para as etapas de abertura e para a preparação do TTS, além de proteção contra inicializações concorrentes nos serviços Bike. Assim, uma integração opcional lenta ou sem resposta pode ficar temporariamente indisponível sem impedir o restante do Vigia IA de abrir.
