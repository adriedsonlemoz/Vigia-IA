import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/utils/storage_size_formatter.dart';

void main() {
  test('formata bytes em unidades legiveis', () {
    expect(StorageSizeFormatter.formatBytes(74_500_000_000), '74,5 GB');
    expect(StorageSizeFormatter.formatBytes(820_000_000), '820 MB');
    expect(StorageSizeFormatter.formatBytes(1_200_000_000_000), '1,2 TB');
  });

  test('formata limites armazenados em MiB sem numeros crus', () {
    expect(StorageSizeFormatter.formatMebibytes(1024), '1,0 GB');
    expect(StorageSizeFormatter.formatMebibytes(4096), '4,0 GB');
    expect(StorageSizeFormatter.formatMebibytes(512), '512 MB');
  });

  test('nao apresenta tamanho negativo', () {
    expect(StorageSizeFormatter.formatBytes(-10), '0 B');
  });
}
