enum VideoSourceState {
  idle,
  connecting,
  streaming,
  reconnecting,
  stopped,
  error,
}

class VideoSourceStatus {
  const VideoSourceStatus(this.state, {this.message});

  final VideoSourceState state;
  final String? message;
}
