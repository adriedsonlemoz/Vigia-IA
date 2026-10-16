import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/screens/mcrp_camera_screen.dart';
import 'package:vigiaia/services/mcrp_saved_cameras_store.dart';

/// A widget test runs in fake async time. Filesystem Futures inside testWidgets
/// can remain pending and trigger the Flutter test runner's ten-minute timeout.
/// Persistence itself is exercised by mcrp_saved_cameras_store_test.dart.
class _MemoryMcrpCamerasStore extends McrpSavedCamerasStore {
  _MemoryMcrpCamerasStore(SavedMcrpCamera initial)
      : _items = [initial],
        super(directoryProvider: () async => throw UnsupportedError(
          'O teste de widgets não deve acessar o sistema de arquivos.'));

  List<SavedMcrpCamera> _items;

  @override
  Future<List<SavedMcrpCamera>> load() async => List.unmodifiable(_items);

  @override
  Future<List<SavedMcrpCamera>> remove(String liveUrl) async {
    _items = _items.where((item) => item.liveUrl != liveUrl).toList();
    return List.unmodifiable(_items);
  }
}

void main() {
  testWidgets('lista câmera sem expor token e permite remover cadastro',
      (tester) async {
    const token = '0123456789abcdef0123456789abcdef';
    const url = 'http://192.168.1.42:8765/live/$token';
    final store = _MemoryMcrpCamerasStore(
      const SavedMcrpCamera(name: 'Traseira da bicicleta', liveUrl: url),
    );

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
  }, timeout: const Timeout(Duration(seconds: 40)));
}
