import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'posture_data.dart';

/// 坐姿检测服务
///
/// 检测用户的书写姿势，包括：
/// - 脊柱角度
/// - 眼屏距离
/// - 头部倾斜角度
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
    );
  }

  /// 计算脊柱角度
  ///
  /// 通过双肩连线与水平线的夹角判断
  static double? _calculateSpineAngle(Pose pose) {
    final left = pose.landmarks[PoseLandmarkType.leftShoulder];
    final right = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (left == null || right == null) return null;

    final dx = right.type.x - left.type.x;
    final dy = right.type.y - left.type.y;

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
    final dx = rightEye.type.x - leftEye.type.x;
    final dy = rightEye.type.y - leftEye.type.y;
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

    final dx = rightEar.type.x - leftEar.type.x;
    final dy = rightEar.type.y - leftEar.type.y;

    // 计算倾斜角度
    final angle = math.atan2(dy, dx) * 180 / math.pi;

    return angle;
  }

  /// 生成反馈信息
  static String _generateFeedback({
    required double? spineAngle,
    required double? eyeScreenDistance,
    required double? headTilt,
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
