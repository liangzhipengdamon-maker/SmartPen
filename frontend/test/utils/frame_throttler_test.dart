import 'package:flutter_test/flutter_test.dart';
import 'package:smartpen_frontend/utils/frame_throttler.dart';

void main() {
  group('FrameThrottler', () {
    test('shouldProcess 在 100ms 内首次调用返回 true', () {
      final throttler = FrameThrottler();
      expect(throttler.shouldProcess(), isTrue);
    });

    test('shouldProcess 在 100ms 内再次调用返回 false', () {
      final throttler = FrameThrottler();
      throttler.shouldProcess(); // 第一次调用
      expect(throttler.shouldProcess(), isFalse); // 100ms 内第二次调用
    });

    test('shouldProcess 在 100ms 后再次调用返回 true', () async {
      final throttler = FrameThrottler();
      throttler.shouldProcess(); // 第一次调用
      await Future.delayed(Duration(milliseconds: 110)); // 等待超过 100ms
      expect(throttler.shouldProcess(), isTrue);
    });
  });
}
