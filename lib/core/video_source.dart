import 'package:flutter/widgets.dart';

import '../models/rgb_frame.dart';
import 'video_source_status.dart';

abstract class VideoSource {
  Stream<RgbFrame> get frames;
  Stream<VideoSourceStatus> get statuses;

  Widget buildPreview();

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
