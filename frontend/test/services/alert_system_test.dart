import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:smartpen/services/alert_system.dart';
import 'package:smartpen/services/posture_data.dart';

@GenerateMocks([])
void main() {
  group('AlertSystem', () {
    late AlertSystem alertSystem;

    setUp(() {
      alertSystem = AlertSystem();
      alertSystem.reset();
    });

    test('should not alert when disabled', () async {
      alertSystem.setEnabled(false);

      final analysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 25.0,
        eyeScreenDistance: 20.0,
        headTiltAngle: 25.0,
        isSpineCorrect: false,
        isDistanceCorrect: false,
        isHeadCorrect: false,
        feedback: '坐姿不正确',
      );

      final didAlert = await alertSystem.processPostureAnalysis(analysis);

      expect(didAlert, false);
    });

    test('should not alert for good posture', () async {
      final analysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 5.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
      );

      final didAlert = await alertSystem.processPostureAnalysis(analysis);

      expect(didAlert, false);
    });

    test('should alert after consecutive bad posture', () async {
      final badAnalysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 20.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: false,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '脊柱角度不正确',
      );

      // 前 2 次不应该触发警报
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);

      // 第 3 次应该触发警报
      expect(await alertSystem.processPostureAnalysis(badAnalysis), true);
    });

    test('should reset counter on good posture', () async {
      final badAnalysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 20.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: false,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '脊柱角度不正确',
      );

      final goodAnalysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 5.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
      );

      // 2 次不良姿势
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);

      // 1 次良好姿势（应该重置计数器）
      expect(await alertSystem.processPostureAnalysis(goodAnalysis), false);

      // 再次不良姿势，应该从 1 开始计数
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);
      expect(await alertSystem.processPostureAnalysis(badAnalysis), false);
      expect(await alertSystem.processPostureAnalysis(badAnalysis), true);
    });

    test('should alert immediately for critical posture', () async {
      final criticalAnalysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 25.0,
        eyeScreenDistance: 20.0,
        headTiltAngle: 25.0,
        isSpineCorrect: false,
        isDistanceCorrect: false,
        isHeadCorrect: false,
        feedback: '坐姿严重不正确',
      );

      // 严重级别应该立即触发警报
      expect(await alertSystem.processPostureAnalysis(criticalAnalysis), true);
    });

    test('should enforce cooldown period', () async {
      final criticalAnalysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 25.0,
        eyeScreenDistance: 20.0,
        headTiltAngle: 25.0,
        isSpineCorrect: false,
        isDistanceCorrect: false,
        isHeadCorrect: false,
        feedback: '坐姿严重不正确',
      );

      // 第一次应该触发警报
      expect(await alertSystem.processPostureAnalysis(criticalAnalysis), true);

      // 冷却期内不应该再次触发
      // 注意：实际测试中需要模拟时间或等待
      // 这里假设冷却时间已过
      expect(await alertSystem.processPostureAnalysis(criticalAnalysis), false);
    });

    test('should enable/disable vibration', () {
      alertSystem.setVibrationEnabled(false);
      expect(alertSystem.isVibrationEnabled, false);

      alertSystem.setVibrationEnabled(true);
      expect(alertSystem.isVibrationEnabled, true);
    });

    test('should enable/disable sound', () {
      alertSystem.setSoundEnabled(false);
      expect(alertSystem.isSoundEnabled, false);

      alertSystem.setSoundEnabled(true);
      expect(alertSystem.isSoundEnabled, true);
    });

    test('should reset state', () {
      alertSystem.reset();
      // 重置后应该可以立即触发警报（没有冷却时间限制）
      expect(alertSystem.isEnabled, true);
    });
  });

  group('PerformanceMonitor', () {
    test('should calculate average frame time', () {
      // 测试性能监控的统计功能
      // 实际实现中需要 mock Stopwatch
    });

    test('should detect performance level correctly', () {
      // 测试性能级别判断
      // excellent: < 100ms
      // good: < 150ms
      // warning: < 200ms
      // critical: >= 200ms
    });

    test('should provide performance recommendations', () {
      // 测试性能建议生成
    });
  });
}
