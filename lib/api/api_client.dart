import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_models.dart';
import '../memory/memory_models.dart';

class ApiClient {
  /// 手机端使用的轻量 API 门面。
  ///
  /// Dio 响应标准化集中放在这里，页面只需要处理 typed model 和友好的错误，
  /// 不需要直接面对原始 HTTP payload。
  ApiClient({required ApiConfig config})
    : _config = config,
      _dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: Duration(seconds: config.timeoutSeconds),
          receiveTimeout: Duration(seconds: config.timeoutSeconds),
          sendTimeout: Duration(seconds: config.timeoutSeconds),
          responseType: ResponseType.json,
        ),
      );

  final ApiConfig _config;
  final Dio _dio;

  void close() {
    _dio.close(force: true);
  }

  Future<HealthResponse> getHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    final data = _requireMap(response.data);
    return HealthResponse.fromJson(data);
  }

  Future<ChatResponse> sendChat({
    required String userId,
    required String username,
    required String text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat',
      data: {'user_id': userId, 'username': username, 'text': text},
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /chat');

    return ChatResponse.fromJson(data, apiBaseUrl: _config.apiBaseUrl);
  }

  Map<String, dynamic> _requireMap(Object? value) {
    // Dio 在不同解码路径下可能返回 Map<dynamic, dynamic>。进入 model factory
    // 前先统一 key 类型。
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }

    throw ApiException('响应不是 JSON 对象。');
  }

  void _throwIfNotOk(Map<String, dynamic> data, String apiName) {
    // 后端错误统一使用 {ok:false, stage, error, request_id}。保留这些字段，
    // 方便手机端日志和后端请求日志对齐。
    final ok = data['ok'];

    if (ok == false) {
      final stage = data['stage']?.toString() ?? '';
      final error = data['error']?.toString() ?? '未知错误';
      final requestId = data['request_id']?.toString() ?? '';

      throw ApiException(
        '$apiName 失败\nstage=$stage\nerror=$error\nrequest_id=$requestId',
      );
    }
  }

  Future<TranscribeResponse> transcribeAudio({
    required String audioPath,
  }) async {
    final fileName = audioPath.split(RegExp(r'[\\/]+')).last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: fileName,
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/voice/transcribe',
      data: formData,
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /voice/transcribe');

    return TranscribeResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> startVoiceCall({
    required String userId,
    required String username,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/voice/realtime/start',
      data: {'user_id': userId, 'username': username},
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /voice/realtime/start');
    return data;
  }

  Future<VoiceCallTurnResponse> sendVoiceCallTurn({
    required String callId,
    required String userId,
    required String username,
    required String audioPath,
  }) async {
    final fileName = audioPath.split(RegExp(r'[\\/]+')).last;

    final formData = FormData.fromMap({
      'call_id': callId,
      'user_id': userId,
      'username': username,
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: fileName,
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/voice/realtime/turn',
      data: formData,
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /voice/realtime/turn');

    return VoiceCallTurnResponse.fromJson(data, apiBaseUrl: _config.apiBaseUrl);
  }

  Future<void> endVoiceCall({required String callId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/voice/realtime/end',
      data: {'call_id': callId},
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /voice/realtime/end');
  }

  Future<ChatResponse> sendMultimodalChat({
    required String userId,
    required String username,
    required String text,
    required String imagePath,
  }) async {
    final fileName = imagePath.split(RegExp(r'[\\/]+')).last;

    final formData = FormData.fromMap({
      'user_id': userId,
      'username': username,
      'text': text,
      'file': await MultipartFile.fromFile(imagePath, filename: fileName),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/multimodal',
      data: formData,
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /chat/multimodal');

    return ChatResponse.fromJson(data, apiBaseUrl: _config.apiBaseUrl);
  }

  Future<UserMemoryResponse> getUserMemory(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memory/user/$userId',
    );

    final data = _requireMap(response.data);
    return UserMemoryResponse.fromJson(data);
  }

  Future<void> clearUserMemory(String userId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/memory/user/$userId',
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'DELETE /memory/user/$userId');
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
