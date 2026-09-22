import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/app_launch_mode_service.dart';

void main() {
  test('modos iniciais aceitam somente valores conhecidos', () {
    expect(AppLaunchMode.parse('normal'), AppLaunchMode.normal);
    expect(AppLaunchMode.parse('monitor'), AppLaunchMode.monitor);
    expect(AppLaunchMode.parse('bike'), AppLaunchMode.bike);
    expect(AppLaunchMode.parse('transmission'), AppLaunchMode.transmission);
    expect(AppLaunchMode.parse('camera'), isNull);
    expect(AppLaunchMode.parse(null), isNull);
  });
}
