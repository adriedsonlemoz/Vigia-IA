import 'dart:typed_data';

/// Extrai JPEGs de um fluxo MJPEG em blocos arbitrários (inclusive marcadores
/// divididos entre blocos). Memória limitada, sem assumir Content-Length.
class MinhaCameraMjpegParser {
  MinhaCameraMjpegParser({this.maxFrameBytes = 2 * 1024 * 1024});

  final int maxFrameBytes;
  final BytesBuilder _jpeg = BytesBuilder(copy: false);
  bool _inside = false;
  int _previous = -1;
  int _size = 0;

  void reset() {
    _jpeg.clear();
    _inside = false;
    _previous = -1;
    _size = 0;
  }

  List<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    for (final byte in chunk) {
      if (!_inside) {
        if (_previous == 0xff && byte == 0xd8) {
          _inside = true;
          _jpeg.add(const <int>[0xff, 0xd8]);
          _size = 2;
          _previous = byte;
        } else {
          _previous = byte;
        }
        continue;
      }
      _jpeg.addByte(byte);
      _size++;
      if (_previous == 0xff && byte == 0xd9) {
        frames.add(_jpeg.takeBytes());
        _inside = false;
        _size = 0;
      } else if (_size > maxFrameBytes) {
        // Quadro incompleto, incorreto ou hostil; não acumular sem limite.
        reset();
      }
      _previous = byte;
    }
    return frames;
  }
}
