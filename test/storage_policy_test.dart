import 'package:vigiaia/models/storage_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StoragePolicy preserva valores no JSON', () {
    const original = StoragePolicy(autoCleanup: false, retentionDays: 14, maxStorageMb: 768);
    final restored = StoragePolicy.fromJson(original.toJson().cast<String, dynamic>());

    expect(restored.autoCleanup, isFalse);
    expect(restored.retentionDays, 14);
    expect(restored.maxStorageMb, 768);
  });

  test('StoragePolicy limita valores inválidos do backup', () {
    final restored = StoragePolicy.fromJson(<String, dynamic>{
      'retentionDays': -50,
      'maxStorageMb': 999999,
    });

    expect(restored.retentionDays, 1);
    expect(restored.maxStorageMb, 32768);
  });
}
