import 'package:flutter_test/flutter_test.dart';
import 'package:smartpen_frontend/services/calibration_state_manager.dart';
import 'package:smartpen_frontend/services/posture_data.dart';

void main() {
  group('CalibrationStateManager', () {
    test('初始状态应为 noFace 且未就绪', () {
      final manager = CalibrationStateManager();
      expect(manager.currentState, CalibrationState.noFace);
      expect(manager.isReadyForPractice, false);
    });

    test('收到 aligned 状态后不立即就绪', () {
      final manager = CalibrationStateManager();

      final analysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 10.0,
        eyeScreenDistance: 40.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
        hasVisibleHands: true,
        isFaceDetected: true,
      );

      manager.processAnalysis(analysis);

      // 立即检查，应该未就绪（需要等待 1 秒）
      expect(manager.isReadyForPractice, false);
    });

    test('收到 aligned 状态 1 秒后就绪', () async {
      final manager = CalibrationStateManager();

      final analysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 10.0,
        eyeScreenDistance: 40.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
        hasVisibleHands: true,
        isFaceDetected: true,
      );

      manager.processAnalysis(analysis);

      // 等待 1.1 秒
      await Future.delayed(const Duration(milliseconds: 1100));

      expect(manager.isReadyForPractice, true);
      expect(manager.lastStableState, CalibrationState.aligned);
    });

    test('手部短暂消失不触发警告（缓冲期）', () async {
      final manager = CalibrationStateManager();

      final goodAnalysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 10.0,
        eyeScreenDistance: 40.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
        hasVisibleHands: true,
        isFaceDetected: true,
      );

      manager.processAnalysis(goodAnalysis);
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(manager.isReadyForPractice, true);

      final noHandAnalysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 10.0,
        eyeScreenDistance: 40.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
        hasVisibleHands: false,
        isFaceDetected: true,
      );

      manager.processAnalysis(noHandAnalysis);

      // 立即检查，应该仍在缓冲期
      expect(manager.currentState, CalibrationState.aligned);
    });

    test('reset() 方法重置所有状态', () {
      final manager = CalibrationStateManager();

      final analysis = PostureAnalysis(
        isCorrect: true,
        spineAngle: 10.0,
        eyeScreenDistance: 40.0,
        headTiltAngle: 5.0,
        isSpineCorrect: true,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '坐姿良好',
        hasVisibleHands: true,
        isFaceDetected: true,
      );

      manager.processAnalysis(analysis);
      manager.reset();

      expect(manager.currentState, CalibrationState.noFace);
      expect(manager.isReadyForPractice, false);
    });
  });
}
