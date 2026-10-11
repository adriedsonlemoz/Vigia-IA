import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vigiaia/sources/remote_phone_camera_source.dart';

void main() {
  test('preview remoto lê dimensões do JPEG sem solicitar RGB para IA', () async {
    final jpeg = _testJpeg(width: 4, height: 2);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = server.listen((request) async {
      if (request.uri.path == '/frame.jpg') {
        request.response.headers
          ..contentType = ContentType('image', 'jpeg')
          ..set('x-vigia-frame-sequence', '1');
        request.response.add(jpeg);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final source = RemotePhoneCameraSource(
      baseUrl: 'http://${server.address.address}:${server.port}',
      accessKey: 'test-key',
      emitFrames: false,
    );
    final emitted = <DateTime>[];
    final subscription = source.frames.listen((frame) => emitted.add(frame.capturedAt));
    addTearDown(() async {
      await subscription.cancel();
      await source.dispose();
      await requests.cancel();
      await server.close(force: true);
    });

    await source.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(source.previewAspectRatio, 2.0);
    expect(emitted, isEmpty);
  });

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

Uint8List _testJpeg({int width = 2, int height = 2}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 18, 42, 64);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 70));
}
