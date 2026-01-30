import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'posture_data.dart';

/// 坐姿检测服务
///
/// 检测用户的书写姿势，包括：
/// - 脊柱角度
/// - 眼屏距离
/// - 头部倾斜角度
/// - 人脸检测
/// - 手部检测（含书写区域判定）
class PostureDetector {
  /// 坐姿检测阈值
  static const double minEyeScreenDistance = 30.0; // cm
  static const double maxSpineAngle = 15.0; // degrees
  static const double maxHeadTilt = 20.0; // degrees

  /// 分析姿态数据
  ///
  /// 返回坐姿分析结果
  static PostureAnalysis analyzePose(Pose pose) {
    // 计算各项指标
    final spineAngle = _calculateSpineAngle(pose);
    final eyeScreenDistance = _estimateEyeScreenDistance(pose);
    final headTilt = _calculateHeadTilt(pose);

    // 判断是否正确
    final isSpineCorrect = spineAngle != null && spineAngle < maxSpineAngle;
    final isDistanceCorrect = eyeScreenDistance != null &&
        eyeScreenDistance >= minEyeScreenDistance;
    final isHeadCorrect = headTilt != null && headTilt.abs() < maxHeadTilt;

    final isCorrect = isSpineCorrect && isDistanceCorrect && isHeadCorrect;

    // 人脸和手部检测
    final isFaceDetected = _hasFaceDetected(pose);
    final hasVisibleHands = _hasVisibleHands(pose);

    return PostureAnalysis(
      isCorrect: isCorrect,
      spineAngle: spineAngle ?? 0.0,
      eyeScreenDistance: eyeScreenDistance ?? 0.0,
      headTiltAngle: headTilt ?? 0.0,
      isSpineCorrect: isSpineCorrect,
      isDistanceCorrect: isDistanceCorrect,
      isHeadCorrect: isHeadCorrect,
      feedback: _generateFeedback(
        spineAngle: spineAngle,
        eyeScreenDistance: eyeScreenDistance,
        headTilt: headTilt,
      ),
      hasVisibleHands: hasVisibleHands,
      isFaceDetected: isFaceDetected,
    );
  }

  /// 计算脊柱角度
  ///
  /// 通过双肩连线与水平线的夹角判断
  static double? _calculateSpineAngle(Pose pose) {
    final left = pose.landmarks[PoseLandmarkType.leftShoulder];
    final right = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (left == null || right == null) return null;

    final dx = right.x - left.x;
    final dy = right.y - left.y;

    // 计算角度（弧度转度）
    final angle = (math.atan2(dy, dx) * 180 / math.pi).abs();

    // 如果是垂直的，调整角度
    // 0° 表示水平，90° 表示垂直
    // 我们想要的是与垂直方向的夹角
    final deviation = (90 - angle).abs();

    return deviation;
  }

  /// 估算眼屏距离
  ///
  /// 通过面部大小估算距离（假设已知面部实际宽度）
  static double? _estimateEyeScreenDistance(Pose pose) {
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return null;

    // 计算两眼之间的像素距离
    final dx = rightEye.x - leftEye.x;
    final dy = rightEye.y - leftEye.y;
    final pixelDistance = math.sqrt(dx * dx + dy * dy);

    // 假设两眼之间实际距离约 6.5cm
    const realEyeDistance = 6.5; // cm

    // 根据像素距离估算实际距离
    // 这里是一个简化的估算，实际可能需要相机标定
    // 假设参考像素距离为 100 像素时距离为 50cm
    const referencePixelDistance = 100.0;
    const referenceDistance = 50.0; // cm

    if (pixelDistance < 1) return null;

    final estimatedDistance = (realEyeDistance * referenceDistance / pixelDistance) *
        (referencePixelDistance / pixelDistance);

    return estimatedDistance;
  }

  /// 计算头部倾斜角度
  ///
  /// 通过双耳位置计算
  static double? _calculateHeadTilt(Pose pose) {
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];

    if (leftEar == null || rightEar == null) return null;

    final dx = rightEar.x - leftEar.x;
    final dy = rightEar.y - leftEar.y;

    // 计算倾斜角度
    final angle = math.atan2(dy, dx) * 180 / math.pi;

    return angle;
  }

  /// 新增：检测是否有可见的手部
  ///
  /// 通过检查 wrist landmarks 判断，并验证手部在"书写区域"
  ///
  /// 用户要求 #1: 手部区域判定
  /// - Y 轴阈值：wrist.y > 0.6（屏幕下方为书写区域）
  /// - 置信度阈值：0.5
  static bool _hasVisibleHands(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    // 置信度阈值
    const minConfidence = 0.5;

    // Y 轴阈值：确保手在书写区域（屏幕下方）
    // ML Kit 坐标系：(0,0) 为左上角，(1,1) 为右下角
    // y > 0.6 表示手在屏幕下方 40% 的区域（书写区域）
    const writingAreaYThreshold = 0.6;

    // 检查左手腕
    final leftValid = leftWrist != null &&
        leftWrist.likelihood > minConfidence &&
        leftWrist.y > writingAreaYThreshold;

    // 检查右手腕
    final rightValid = rightWrist != null &&
        rightWrist.likelihood > minConfidence &&
        rightWrist.y > writingAreaYThreshold;

    final hasHands = leftValid || rightValid;

    debugPrint('🖐️  Hand detection: left=$leftValid (${leftWrist?.y.toStringAsFixed(2)}), '
        'right=$rightValid (${rightWrist?.y.toStringAsFixed(2)}), '
        'hasHands=$hasHands');

    return hasHands;
  }

  /// 新增：检测是否有人脸
  ///
  /// 通过检查 nose landmark 判断
  /// 人脸检测使用简化方法（不依赖 Face Detection API）
  static bool _hasFaceDetected(Pose pose) {
    final nose = pose.landmarks[PoseLandmarkType.nose];

    // nose landmark 存在且置信度足够高
    final hasFace = nose != null && nose.likelihood > 0.3;

    debugPrint('👤 Face detection: hasFace=$hasFace (${nose?.likelihood.toStringAsFixed(2)})');

    return hasFace;
  }

  /// 生成反馈信息
  static String _generateFeedback({
    required double? spineAngle,
    required double? eyeScreenDistance,
    required double? headTilt,
    bool? hasVisibleHands,  // 新增参数（暂不使用，保留扩展性）
  }) {
    final issues = <String>[];

    if (spineAngle != null && spineAngle >= maxSpineAngle) {
      issues.add('请坐直，身体保持正直');
    }

    if (eyeScreenDistance != null && eyeScreenDistance < minEyeScreenDistance) {
      issues.add('请保持适当距离，眼睛离屏幕太近');
    }

    if (headTilt != null && headTilt.abs() >= maxHeadTilt) {
      issues.add('请保持头部正直，不要歪头');
    }

    // 注意：手部提示由 CalibrationState 的 message 处理
    // 这里保留传统的反馈逻辑

    if (issues.isEmpty) {
      return '坐姿良好，继续保持';
    }

    return issues.join('；');
  }

  /// 计算综合得分 (0-100)
  static int calculatePostureScore(PostureAnalysis analysis) {
    var score = 100;

    // 脊柱角度扣分
    if (!analysis.isSpineCorrect) {
      final deviation = analysis.spineAngle - maxSpineAngle;
      score -= (deviation * 2).toInt().clamp(0, 30);
    }

    // 距离扣分
    if (!analysis.isDistanceCorrect) {
      final deficit = minEyeScreenDistance - analysis.eyeScreenDistance;
      score -= (deficit * 2).toInt().clamp(0, 40);
    }

    // 头部倾斜扣分
    if (!analysis.isHeadCorrect) {
      final tilt = analysis.headTiltAngle.abs() - maxHeadTilt;
      score -= (tilt * 2).toInt().clamp(0, 30);
    }

    return score.clamp(0, 100);
  }
}
