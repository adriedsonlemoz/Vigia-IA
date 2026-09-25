# Vigia IA 1.0.141+141

## Buildfix Android-APK-106

- O `flutter analyze` do workflow passou sem problemas.
- A falha estava isolada no teste `map_poi_details_sheet_test.dart`: a comodidade `Água potável` fica abaixo da área inicialmente visível e o `ListView` ainda não a havia construído.
- O teste agora rola o painel antes de verificar a comodidade, refletindo o comportamento real de uma lista lazy.
- Nenhuma funcionalidade de produção foi adicionada ou removida nesta correção; o PiP 1.0.140 e o painel de POI permanecem inalterados.
