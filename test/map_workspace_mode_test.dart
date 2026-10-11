import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_workspace_mode.dart';
import 'package:vigiaia/widgets/map_workspace_mode_picker.dart';

void main() {
  test('modos visuais nao confundem papeis do aparelho nem estado de gravacao', () {
    expect(MapWorkspaceMode.values.length, 4);
    expect(MapWorkspaceMode.explore.label, 'Explorar');
    expect(MapWorkspaceMode.ride.label, 'Pedalar');
    expect(MapWorkspaceMode.navigate.label, 'Navegar');
    expect(MapWorkspaceMode.monitor.label, 'Monitorar');
  });

  testWidgets('seletor preserva modo atual ao cancelar e entrega opcao escolhida',
      (tester) async {
    MapWorkspaceMode? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showMapWorkspaceModePicker(
              context, selected: MapWorkspaceMode.explore,
            );
          },
          child: const Text('Abrir modos'),
        )),
      ),
    ));

    await tester.tap(find.text('Abrir modos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace-explore')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace-ride')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace-navigate')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace-monitor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('workspace-ride')));
    await tester.pumpAndSettle();
    expect(result, MapWorkspaceMode.ride);
  });

  testWidgets('voltar do Android cancela o seletor sem alterar o modo', (tester) async {
    MapWorkspaceMode? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showMapWorkspaceModePicker(
              context, selected: MapWorkspaceMode.navigate,
            );
          },
          child: const Text('Modos'),
        )),
      ),
    ));
    await tester.tap(find.text('Modos'));
    await tester.pumpAndSettle();
    // Botao Voltar do Android fecha a rota modal; pageBack() procura um
    // BackButton/ CupertinoNavigationBarBackButton, inexistente neste sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace-navigate')), findsNothing);
    expect(result, isNull);
  });

  testWidgets('toque fora do seletor cancela sem escolher outro modo', (tester) async {
    MapWorkspaceMode? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showMapWorkspaceModePicker(
              context, selected: MapWorkspaceMode.ride,
            );
          },
          child: const Text('Modos'),
        )),
      ),
    ));

    await tester.tap(find.text('Modos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace-ride')), findsOneWidget);
    // A barreira escura acima do bottom sheet o dispensa sem selecionar.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace-ride')), findsNothing);
    expect(result, isNull);
  });
}

