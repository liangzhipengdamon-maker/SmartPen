import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/character.dart';

/// 字符 API 客户端
class CharactersApi {
  final Dio _dio;
  final String baseUrl;

  CharactersApi({
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = baseUrl ?? kBackendBaseUrl,
        _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? kBackendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    // 添加拦截器用于日志
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  /// 获取字符数据
  Future<CharacterData> getCharacter(String char) async {
    try {
      final response = await _dio.get(
        '/api/characters/$char',
      );

      if (response.statusCode == 200) {
        return CharacterData.fromJson(response.data);
      } else {
        throw Exception('Failed to load character: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 批量获取字符数据
  Future<Map<String, CharacterData>> getCharacters(List<String> chars) async {
    final result = <String, CharacterData>{};

    for (final char in chars) {
      try {
        final data = await getCharacter(char);
        result[char] = data;
      } catch (e) {
        // 单个字符失败不影响其他字符
        continue;
      }
    }

    return result;
  }

  /// 提交用户书写进行评分
  Future<ScoreResult> submitHandwriting({
    required String character,
    required List<List<PointData>> userStrokes,
  }) async {
    try {
      final data = {
        'character': character,
        'user_strokes': userStrokes
            .map((stroke) => stroke.map((p) => {'x': p.x, 'y': p.y}).toList())
            .toList(),
      };

      final response = await _dio.post(
        '/api/score',
        data: data,
      );

      if (response.statusCode == 200) {
        return ScoreResult.fromJson(response.data);
      } else {
        throw Exception('Failed to submit handwriting: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 检查 API 健康状态
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('连接超时，请检查网络连接');
      case DioExceptionType.connectionError:
        return Exception('无法连接到服务器，请确保后端正在运行');
      case DioExceptionType.badResponse:
        return Exception('服务器错误: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('请求已取消');
      default:
        return Exception('网络请求失败: ${error.message}');
    }
  }
}
