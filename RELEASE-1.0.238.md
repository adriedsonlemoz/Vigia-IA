# Vigia IA 1.0.238+238

Refatoração gradual, etapa 6. O controle visual de gravação do banner da navegação foi organizado em `lib/widgets/map_navigation_record_control.dart`, sem alteração intencional de aparência ou comportamento.

Iniciar gravação continua condicionado à disponibilidade de GPS. Os botões de pausa, retomada, encerrar e exportar GPX mantêm os mesmos callbacks, e a opção de GPX somente aparece com rota registrada. Os serviços GPS, gravação, estado persistido, cronômetro de outro painel, rádio, câmeras, ESP32, IA e mapas offline não foram alterados.

**Verificação:** gate Python preventivo, contratos estáticos, integridade ZIP; `flutter analyze`, `flutter test`, APK e teste físico dependem do CI.
