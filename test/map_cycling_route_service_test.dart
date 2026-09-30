import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_cycling_route_service.dart';

void main() {
  final service = MapCyclingRouteService();

  Map<String, Object> trip({
    required String shape,
    required double lengthKm,
    required double timeSeconds,
    required String instruction,
  }) {
    return <String, Object>{
      'summary': <String, Object>{
        'length': lengthKm,
        'time': timeSeconds,
      },
      'legs': <Object>[
        <String, Object>{
          'shape': shape,
          'maneuvers': <Object>[
            <String, Object>{
              'instruction': instruction,
              'begin_shape_index': 0,
              'end_shape_index': 2,
              'length': lengthKm,
              'time': timeSeconds,
            },
          ],
        },
      ],
    };
  }

  test('parser preserva rota principal e alternativas distintas', () {
    final body = jsonEncode(<String, Object>{
      'trip': trip(
        shape: '~fy~d@~h{xrA?owHowH?',
        lengthKm: 1.1,
        timeSeconds: 330,
        instruction: 'Siga em frente',
      ),
      'alternates': <Object>[
        <String, Object>{
          'trip': trip(
            shape: '~fy~d@~h{xrA_|BozDozD_|B',
            lengthKm: 1.2,
            timeSeconds: 300,
            instruction: 'Siga pela alternativa',
          ),
        },
        <String, Object>{
          'trip': trip(
            shape: '~fy~d@~h{xrAn}@_yF_vJo}@',
            lengthKm: 1.35,
            timeSeconds: 360,
            instruction: 'Siga pela segunda alternativa',
          ),
        },
      ],
    });

    final routes = service.parseRoutes(body);

    expect(routes, hasLength(3));
    expect(routes.first.distanceMeters, 1100);
    expect(routes[1].durationSeconds, 300);
    expect(routes[2].maneuvers.single.instruction, 'Siga pela segunda alternativa');
    expect(routes.every((route) => route.points.length == 3), isTrue);
  });

  test('parser remove alternativa duplicada da rota principal', () {
    final primary = trip(
      shape: '~fy~d@~h{xrA?owHowH?',
      lengthKm: 1.1,
      timeSeconds: 330,
      instruction: 'Siga em frente',
    );
    final body = jsonEncode(<String, Object>{
      'trip': primary,
      'alternates': <Object>[
        <String, Object>{'trip': primary},
      ],
    });

    final routes = service.parseRoutes(body);

    expect(routes, hasLength(1));
  });
}
