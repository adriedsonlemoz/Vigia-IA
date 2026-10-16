part of 'object_detection_service.dart';

class _LoadedDetector {
  _LoadedDetector(this.interpreter, this.runtime, this.delegate);
  final Interpreter interpreter;
  final _DetectorRuntime runtime;
  final XNNPackDelegate? delegate;

  void close() {
    interpreter.close();
    delegate?.delete();
  }
}

_LoadedDetector _loadDetector(Uint8List bytes, String name, {String reason = ''}) {
  final failures = <String>[];
  for (final accelerated in [true, false]) {
    final threads = name.startsWith('YOLO26') ? 4 : 2;
    final options = InterpreterOptions()..threads = threads;
    XNNPackDelegate? delegate;
    Interpreter? candidate;
    try {
      if (accelerated) {
        final delegateOptions = XNNPackDelegateOptions(numThreads: threads);
        try {
          delegate = XNNPackDelegate(options: delegateOptions);
        } finally {
          delegateOptions.delete();
        }
        options.addDelegate(delegate);
      }
      candidate = Interpreter.fromBuffer(bytes, options: options);
      candidate.allocateTensors();
      final backend = accelerated ? 'XNNPACK solicitado; CPU para ops restantes' : 'CPU compatível';
      final inspected = _inspectInterpreter(candidate, '$name; backend=$backend; threads=$threads; $reason');
      return _LoadedDetector(candidate, inspected, delegate);
    } catch (error) {
      candidate?.close();
      delegate?.delete();
      failures.add('$error');
    } finally {
      options.delete();
    }
  }
  throw StateError('$name: ${failures.join(' | ')}');
}
