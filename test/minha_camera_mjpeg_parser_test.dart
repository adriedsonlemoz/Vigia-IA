import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/minha_camera_mjpeg_parser.dart';

void main() {
  test('extrai quadros separados e ignora headers MIME', () {
    final parser = MinhaCameraMjpegParser();
    final bytes = <int>[45,45,102,114,97,109,101,13,10,0xff,0xd8,1,2,0xff,0xd9,
      13,10,45,45,102,114,97,109,101,13,10,0xff,0xd8,7,8,0xff,0xd9];
    expect(parser.add(bytes), [<int>[0xff,0xd8,1,2,0xff,0xd9],
      <int>[0xff,0xd8,7,8,0xff,0xd9]]);
  });
  test('suporta SOI/EOI separados entre chunks de rede', () {
    final parser = MinhaCameraMjpegParser();
    expect(parser.add([12,0xff]), isEmpty);
    expect(parser.add([0xd8,1,2,0xff]), isEmpty);
    expect(parser.add([0xd9,10]), [<int>[0xff,0xd8,1,2,0xff,0xd9]]);
  });
  test('abandona quadros excedentes e recupera fluxo', () {
    final parser = MinhaCameraMjpegParser(maxFrameBytes: 5);
    expect(parser.add([0xff,0xd8,1,2,3,4,5,6]), isEmpty);
    expect(parser.add([0xff,0xd8,8,0xff,0xd9]),
        [<int>[0xff,0xd8,8,0xff,0xd9]]);
  });
  test('reset limpa frame parcialmente recebido', () {
    final parser = MinhaCameraMjpegParser();
    parser.add([0xff,0xd8,1]);
    parser.reset();
    expect(parser.add([0xff,0xd9]), isEmpty);
  });
}
