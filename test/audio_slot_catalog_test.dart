import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/audio_slot.dart';

void main() {
  test('catálogo de áudio mantém 78 slots únicos e completos', () {
    expect(AudioSlotCatalog.all, hasLength(78));
    expect(AudioSlotCatalog.all.map((slot) => slot.id).toSet(), hasLength(78));
    expect(AudioSlotCatalog.all.every((slot) => slot.title.trim().isNotEmpty), isTrue);
    expect(AudioSlotCatalog.all.every((slot) => slot.phrase.trim().isNotEmpty), isTrue);
  });

  test('slots usados pelo monitor atual permanecem presentes', () {
    const current = <String>{
      AudioSlotIds.personDetected,
      AudioSlotIds.vehicleDetected,
      AudioSlotIds.animalDetected,
      AudioSlotIds.objectDetected,
      AudioSlotIds.personEntered,
      AudioSlotIds.personExited,
      AudioSlotIds.vehicleEntered,
      AudioSlotIds.vehicleExited,
      AudioSlotIds.animalEntered,
      AudioSlotIds.animalExited,
      AudioSlotIds.objectEntered,
      AudioSlotIds.objectExited,
      AudioSlotIds.cameraObstructed,
      AudioSlotIds.cameraMoved,
    };
    final ids = AudioSlotCatalog.all.map((slot) => slot.id).toSet();
    expect(ids.containsAll(current), isTrue);
  });

  test('slots Bike ficam liberados para emulador e hardware futuro', () {
    final bike = AudioSlotCatalog.all.where((slot) => slot.id.startsWith('bike_')).toList();
    expect(bike, hasLength(64));
    expect(bike.every((slot) => !slot.future), isTrue);
  });
}
