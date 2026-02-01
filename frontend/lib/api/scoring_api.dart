import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../models/comprehensive_score.dart';

class ScoringApi {
  final Dio _dio;
  final String baseUrl;

  ScoringApi({
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = baseUrl ?? kBackendBaseUrl,
        _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? kBackendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  Future<ComprehensiveScoreResult> scoreFromPhoto({
    required String character,
    required XFile photo,
    Map<String, dynamic>? postureData,
  }) async {
    final postureJson = postureData != null ? jsonEncode(postureData) : null;
    final formData = FormData.fromMap({
      'character': character,
      if (postureJson != null) 'posture_data': postureJson,
      'image': await MultipartFile.fromFile(
        photo.path,
        filename: photo.name,
      ),
    });

    final response = await _dio.post(
      '/api/score/from_photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return ComprehensiveScoreResult.fromJson(response.data);
  }
}
