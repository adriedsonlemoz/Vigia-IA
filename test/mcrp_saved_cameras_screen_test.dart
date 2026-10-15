import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/screens/mcrp_camera_screen.dart';
import 'package:vigiaia/services/mcrp_saved_cameras_store.dart';

void main() {
  testWidgets('lista câmera sem expor token e permite remover cadastro', (tester) async {
    final directory = await Directory.systemTemp.createTemp('vigia-ui-mcrp-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = McrpSavedCamerasStore(directoryProvider: () async => directory);
    const token = '0123456789abcdef0123456789abcdef';
    await store.save(name: 'Traseira da bicicleta',
      liveUrl: 'http://192.168.1.42:8765/live/$token');
    await tester.pumpWidget(MaterialApp(home: McrpCameraScreen(savedStore: store)));
    await tester.pumpAndSettle();
    expect(find.text('Câmeras salvas (1)'), findsOneWidget);
    await tester.tap(find.text('Câmeras salvas (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Traseira da bicicleta'), findsOneWidget);
    expect(find.text('192.168.1.42:8765'), findsOneWidget);
    expect(find.textContaining(token), findsNothing);
    await tester.tap(find.byTooltip('Remover câmera salva'));
    await tester.pumpAndSettle();
    expect(find.text('Remover câmera salva?'), findsOneWidget);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(find.text('Câmeras salvas (1)'), findsNothing);
    expect(await store.load(), isEmpty);
  });
}
