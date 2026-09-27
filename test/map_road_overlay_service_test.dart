import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_road_overlay_service.dart';

void main() {
  test('somente superfície marcada e vias principais recebem classe', () {
    expect(MapRoadOverlayService.classify(<String, String>{
      'highway': 'residential', 'surface': 'gravel',
    }), 'earth');
    expect(MapRoadOverlayService.classify(<String, String>{
      'highway': 'residential', 'surface': 'asphalt',
    }), 'asphalt');
    expect(MapRoadOverlayService.classify(<String, String>{
      'highway': 'primary', 'surface': 'asphalt',
    }), 'highway');
    expect(MapRoadOverlayService.classify(<String, String>{
      'waterway': 'stream',
    }), 'water');
    expect(MapRoadOverlayService.classify(<String, String>{
      'highway': 'residential',
    }), isNull);
  });
}
