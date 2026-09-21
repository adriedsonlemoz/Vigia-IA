import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vigiaia/sources/remote_phone_camera_source.dart';

void main() {
  test('consulta rapidamente e não emite novamente o mesmo quadro remoto',
      () async {
    final jpeg = _testJpeg();
    final capturedAt = DateTime.now().toUtc();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var frameRequests = 0;
    final requests = server.listen((request) async {
      if (request.uri.path == '/frame.jpg') {
        frameRequests++;
        final after = int.tryParse(request.uri.queryParameters['after'] ?? '');
        request.response.headers
          ..set(HttpHeaders.cacheControlHeader, 'no-store')
          ..set('x-vigia-frame-sequence', '1');
        if (after != null && after >= 1) {
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response.headers
            ..contentType = ContentType('image', 'jpeg')
            ..set(
              'x-vigia-frame-captured-at',
              capturedAt.toIso8601String(),
            );
          request.response.add(jpeg);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final source = RemotePhoneCameraSource(
      baseUrl: 'http://${server.address.address}:${server.port}',
      accessKey: 'test-key',
      analysisInterval: const Duration(milliseconds: 900),
    );
    final emitted = <DateTime>[];
    final frames = source.frames.listen((frame) => emitted.add(frame.capturedAt));

    addTearDown(() async {
      await frames.cancel();
      await source.dispose();
      await requests.cancel();
      await server.close(force: true);
    });

    await source.start();
    await Future<void>.delayed(const Duration(milliseconds: 1050));

    expect(frameRequests, greaterThanOrEqualTo(2));
    expect(emitted, <DateTime>[capturedAt]);
  });
}

Uint8List _testJpeg() {
  final image = img.Image(width: 2, height: 2);
  image
    ..setPixelRgb(0, 0, 18, 42, 64)
    ..setPixelRgb(1, 0, 18, 42, 64)
    ..setPixelRgb(0, 1, 18, 42, 64)
    ..setPixelRgb(1, 1, 18, 42, 64);
  return Uint8List.fromList(img.encodeJpg(image, quality: 70));
}
