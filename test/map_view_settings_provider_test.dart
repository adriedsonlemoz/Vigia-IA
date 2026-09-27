import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vigiaia/services/map_view_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('provedor do mapa tem mapa atual como padrao', () {
    expect(MapProvider.current.label, 'Mapa atual');
    expect(MapProvider.google.label, 'Google Maps');
  });

  test('configuracao do provedor usa nomes estaveis para persistencia', () {
    expect(MapProvider.current.name, 'current');
    expect(MapProvider.google.name, 'google');
    expect(jsonEncode({'provider': MapProvider.google.name}), '{"provider":"google"}');
  });

  test('o arquivo de suporte pode ser resolvido pelo path provider', () async {
    final directory = await getApplicationSupportDirectory();
    expect(directory.path, isNotEmpty);
    expect(File(directory.path).path, isNotEmpty);
  });
}
