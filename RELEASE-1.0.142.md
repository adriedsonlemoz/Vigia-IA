# Vigia IA 1.0.142+142

## Buildfix Android-APK-107

- O `flutter analyze` do workflow passou sem problemas.
- O Android-APK-107 mostrou que uma única rolagem fixa ainda podia ser consumida pela expansão do `DraggableScrollableSheet`, mantendo `Água potável` fora da árvore renderizada.
- `map_poi_details_sheet_test.dart` agora usa `scrollUntilVisible` no `Scrollable` do painel, rolando até o conteúdo existir e ficar visível.
- O teste continua verificando a ação `Ir até lá`; nenhuma funcionalidade de produção foi alterada.
