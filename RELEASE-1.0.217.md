# Vigia IA 1.0.217+217

## Mapas e cicloviagem

- Painel de navegação detalhado mais compacto e ações de gravação preservadas.
- Antes de iniciar, visualize o trajeto e alternativas no mapa, consulte o planejamento e escolha a rota.
- Salve a última rota no aparelho pelo ícone de disquete na prévia. Para reabrir, entre em Vigia IA > Abrir rota salva, mesmo sem rede.
- Plano de vários dias permite ajustar horário de partida, frequência e duração de pausas e tempo de almoço; informa previsão simplificada de chegada.
- Localidades candidatas a paradas devem estar a até 1,5 km em linha reta da rota. O app não verifica acesso por estrada, serviços ou segurança.

## Limitações e validação

- Calcular uma rota NOVA requer Valhalla online. Rota salva não inclui mapas base, que devem ser baixados separadamente.
- Estimativas não consideram vento, relevo, clima, desvios viários, horários de funcionamento ou reservas; não há promessa de ponto de água/hospedagem.
- Validação estrutural e testagem automatizada do projeto executadas conforme `VALIDATION.md`; `flutter analyze`, `flutter test` e APK dependem de SDK/CI.
