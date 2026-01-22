import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:smartpen/services/posture_detector.dart';
import 'package:smartpen/services/posture_data.dart';

void main() {
  group('PostureDetector', () {
    test('should analyze good posture correctly', () {
      // 创建一个标准姿态（直立、距离适中、头部正直）
      final pose = _createMockPose(
        leftShoulder: (0.3, 0.4),
        rightShoulder: (0.7, 0.4),
        leftEye: (0.35, 0.25),
        rightEye: (0.65, 0.25),
        leftEar: (0.25, 0.25),
        rightEar: (0.75, 0.25),
      );

      final analysis = PostureDetector.analyzePose(pose);

      expect(analysis.isCorrect, true);
      expect(analysis.isSpineCorrect, true);
      expect(analysis.isDistanceCorrect, true);
      expect(analysis.isHeadCorrect, true);
    });

    test('should detect incorrect spine angle', () {
      // 创建脊柱倾斜的姿态
      final pose = _createMockPose(
        leftShoulder: (0.2, 0.35),  // 左肩高
        rightShoulder: (0.6, 0.5),  // 右肩低
        leftEye: (0.35, 0.25),
        rightEye: (0.65, 0.25),
        leftEar: (0.25, 0.25),
        rightEar: (0.75, 0.25),
      );

      final analysis = PostureDetector.analyzePose(pose);

      expect(analysis.isCorrect, false);
      expect(analysis.isSpineCorrect, false);
      expect(analysis.spineAngle, greaterThan(15.0));
    });

    test('should detect incorrect eye-screen distance', () {
      // 创建距离太近的姿态（两眼距离很大表示离屏幕很近）
      final pose = _createMockPose(
        leftShoulder: (0.3, 0.4),
        rightShoulder: (0.7, 0.4),
        leftEye: (0.1, 0.25),  // 眼睛相距很远
        rightEye: (0.9, 0.25),
        leftEar: (0.0, 0.25),
        rightEar: (1.0, 0.25),
      );

      final analysis = PostureDetector.analyzePose(pose);

      expect(analysis.isCorrect, false);
      expect(analysis.isDistanceCorrect, false);
      expect(analysis.eyeScreenDistance, lessThan(30.0));
    });

    test('should detect incorrect head tilt', () {
      // 创建头部歪斜的姿态
      final pose = _createMockPose(
        leftShoulder: (0.3, 0.4),
        rightShoulder: (0.7, 0.4),
        leftEye: (0.35, 0.25),
        rightEye: (0.65, 0.25),
        leftEar: (0.2, 0.3),   // 左耳低
        rightEar: (0.7, 0.15), // 右耳高
      );

      final analysis = PostureDetector.analyzePose(pose);

      expect(analysis.isCorrect, false);
      expect(analysis.isHeadCorrect, false);
      expect(analysis.headTiltAngle.abs(), greaterThan(20.0));
    });

    test('should calculate posture score correctly', () {
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

      final score = PostureDetector.calculatePostureScore(goodAnalysis);

      expect(score, greaterThan(90));
      expect(score, lessThanOrEqualTo(100));
    });

    test('should handle missing landmarks gracefully', () {
      // 创建缺少关键点的姿态
      final pose = _createMockPose(
        leftShoulder: null,
        rightShoulder: null,
        leftEye: null,
        rightEye: null,
        leftEar: null,
        rightEar: null,
      );

      final analysis = PostureDetector.analyzePose(pose);

      expect(analysis.isCorrect, false);
      expect(analysis.spineAngle, 0.0);
      expect(analysis.eyeScreenDistance, 0.0);
      expect(analysis.headTiltAngle, 0.0);
    });
  });

  group('PostureAnalysis', () {
    test('should return correct warning level for good posture', () {
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

      expect(analysis.warningLevel, PostureWarningLevel.good);
    });

    test('should return warning level for single issue', () {
      final analysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 20.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: false,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '请坐直',
      );

      expect(analysis.warningLevel, PostureWarningLevel.warning);
    });

    test('should return critical level for multiple issues', () {
      final analysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 25.0,
        eyeScreenDistance: 20.0,
        headTiltAngle: 25.0,
        isSpineCorrect: false,
        isDistanceCorrect: false,
        isHeadCorrect: false,
        feedback: '请调整坐姿',
      );

      expect(analysis.warningLevel, PostureWarningLevel.critical);
    });

    test('should get main issue correctly', () {
      final analysis = PostureAnalysis(
        isCorrect: false,
        spineAngle: 25.0,
        eyeScreenDistance: 50.0,
        headTiltAngle: 5.0,
        isSpineCorrect: false,
        isDistanceCorrect: true,
        isHeadCorrect: true,
        feedback: '脊柱角度不正确',
      );

      expect(analysis.getMainIssue(), '脊柱角度');
    });
  });
}

/// 创建模拟姿态
Pose _createMockPose({
  required Tuple2<double, double>? leftShoulder,
  required Tuple2<double, double>? rightShoulder,
  required Tuple2<double, double>? leftEye,
  required Tuple2<double, double>? rightEye,
  required Tuple2<double, double>? leftEar,
  required Tuple2<double, double>? rightEar,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  if (leftShoulder != null) {
    landmarks[PoseLandmarkType.leftShoulder] = _createLandmark(leftShoulder.$1, leftShoulder.$2);
  }
  if (rightShoulder != null) {
    landmarks[PoseLandmarkType.rightShoulder] = _createLandmark(rightShoulder.$1, rightShoulder.$2);
  }
  if (leftEye != null) {
    landmarks[PoseLandmarkType.leftEye] = _createLandmark(leftEye.$1, leftEye.$2);
  }
  if (rightEye != null) {
    landmarks[PoseLandmarkType.rightEye] = _createLandmark(rightEye.$1, rightEye.$2);
  }
  if (leftEar != null) {
    landmarks[PoseLandmarkType.leftEar] = _createLandmark(leftEar.$1, leftEar.$2);
  }
  if (rightEar != null) {
    landmarks[PoseLandmarkType.rightEar] = _createLandmark(rightEar.$1, rightEar.$2);
  }

  return Pose(
    landmarks: landmarks,
    type: PoseType.unknown,
  );
}

/// 创建关键点
PoseLandmark _createLandmark(double x, double y) {
  return PoseLandmark(
    type: PoseLandmark(
      x: x,
      y: y,
      z: 0.0,
    ),
    type_: PoseLandmarkType.leftEye,
  );
}

/// 简单的 Tuple2 实现
class Tuple2<T1, T2> {
  final T1 $1;
  final T2 $2;
  Tuple2(this.$1, this.$2);
}
