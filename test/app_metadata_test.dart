import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/core/app_metadata.dart';

void main() {
  test('metadados publicos do Vigia IA estao sincronizados', () {
    expect(AppMetadata.name, 'Vigia IA');
    expect(AppMetadata.version, '1.0.127');
    expect(AppMetadata.build, 127);
  });
}
