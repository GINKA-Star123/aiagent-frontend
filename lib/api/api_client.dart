import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_models.dart';
import '../memory/memory_models.dart';

class ApiClient {
  /// 手机端使用的轻量 API 门面。
  ///
  /// Dio 响应标准化集中放在这里，页面只需要处理 typed model 和友好的错误，
  /// 不需要直接面对原始 HTTP payload。
  ApiClient({
    required ApiConfig config,
    String token = '',
    List<String>? baseUrls,
  }) : _config = config,
       _token = token,
       _baseUrls = buildBaseUrls(baseUrls, config.apiBaseUrl),
       _activeBaseUrl = buildBaseUrls(baseUrls, config.apiBaseUrl).first,
       _dio = Dio(_baseOptions(config, token)),
       _retryDio = Dio(_baseOptions(config, token)) {
    _dio.interceptors.add(_FailoverInterceptor(this));
  }

  final ApiConfig _config;
  final String _token;
  final List<String> _baseUrls;
  String _activeBaseUrl;
  final Dio _dio;
  final Dio _retryDio;

  static BaseOptions _baseOptions(ApiConfig config, String token) {
    return BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: Duration(seconds: config.timeoutSeconds),
      receiveTimeout: Duration(seconds: config.timeoutSeconds),
      sendTimeout: Duration(seconds: config.timeoutSeconds),
      responseType: ResponseType.json,
      headers: token.isEmpty
          ? const <String, dynamic>{}
          : <String, dynamic>{'Authorization': 'Bearer $token'},
    );
  }

  /// 多入口：去重、去尾斜杠，主入口放第一位。
  static List<String> buildBaseUrls(List<String>? urls, String fallback) {
    final result = <String>[];
    for (final raw in <String>[...?urls, fallback]) {
      final url = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if (url.isNotEmpty && !result.contains(url)) {
        result.add(url);
      }
    }
    return result.isEmpty ? <String>[fallback] : result;
  }

  String get activeBaseUrl => _activeBaseUrl;

  /// 播放器无法自定义请求头，音频地址追加 access_token（后端仅对 /audio/* 生效）。
  String authorizedAudioUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty || _token.isEmpty) {
      return normalized;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null) {
      return normalized;
    }
    final params = Map<String, String>.from(parsed.queryParameters);
    params['access_token'] = _token;
    return parsed.replace(queryParameters: params).toString();
  }

  void close() {
    _dio.close(force: true);
    _retryDio.close(force: true);
  }

  /// 401/403 表示激活码失效或未激活，界面应回到激活页。
  static bool isAuthFailure(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      return code == 401 || code == 403;
    }
    return false;
  }

  /// 网络级失败（可排队重发）；4xx 与业务错误不算。
  static bool isNetworkFailure(Object error) {
    if (error is DioException) {
      if (isAuthFailure(error)) {
        return false;
      }
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.badCertificate:
          return true;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          final data = error.response?.data;
          final degraded = data is Map && data['degraded'] == true;
          return !degraded && (code == 502 || code == 503 || code == 504);
        default:
          return false;
      }
    }
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('Connection refused') ||
        text.contains('Failed host lookup');
  }

  bool _isRetryable(DioException error) {
    // 多部件上传的 FormData 不能安全重放。
    if (error.requestOptions.data is FormData) {
      return false;
    }
    return isNetworkFailure(error);
  }

  Map<String, dynamic>? degradedPayload(Object error) {
    if (error is! DioException) {
      return null;
    }
    final data = error.response?.data;
    if (data is Map && data['degraded'] == true) {
      return data.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<Response<dynamic>?> _retryOnOtherBase(DioException error) async {
    if (!_isRetryable(error)) {
      return null;
    }
    final tried = error.requestOptions.baseUrl;
    for (final base in _baseUrls) {
      if (base == tried) {
        continue;
      }
      final options = error.requestOptions;
      options.baseUrl = base;
      try {
        final response = await _retryDio.fetch<dynamic>(options);
        _activeBaseUrl = base;
        return response;
      } on DioException {
        continue;
      }
    }
    return null;
  }

  Future<HealthResponse> getHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    final data = _requireMap(response.data);
    return HealthResponse.fromJson(data);
  }

  Future<void> sendTelemetryBatch({
    required String batchId,
    required Map<String, dynamic> app,
    required List<Map<String, dynamic>> events,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/telemetry/batch',
      data: {'batch_id': batchId, 'app': app, 'events': events},
    );
  }

  Future<ChatResponse> sendChat({
    required String userId,
    required String username,
    required String text,
    String clientMessageId = '',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat',
        data: {
          'user_id': userId,
          'username': username,
          'text': text,
          if (clientMessageId.isNotEmpty) 'client_message_id': clientMessageId,
        },
      );

      final data = _requireMap(response.data);
      _throwIfNotOk(data, 'POST /chat');

      return ChatResponse.fromJson(data, apiBaseUrl: _activeBaseUrl);
    } on DioException catch (error) {
      final degraded = degradedPayload(error);
      if (degraded != null) {
        return ChatResponse.fromJson(degraded, apiBaseUrl: _activeBaseUrl);
      }
      rethrow;
    }
  }

  Future<SessionOpeningResponse> openSession({
    required String userId,
    required String username,
    String entry = 'chat_page',
    String recentTopic = '',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/session/open',
      data: {
        'user_id': userId,
        'username': username,
        'client_time': DateTime.now().toIso8601String(),
        'entry': entry,
        'recent_topic': recentTopic,
      },
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /session/open');

    return SessionOpeningResponse.fromJson(
      data,
      apiBaseUrl: _config.apiBaseUrl,
    );
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

    if (ok == false && data['degraded'] != true) {
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
    String clientMessageId = '',
  }) async {
    final fileName = imagePath.split(RegExp(r'[\\/]+')).last;

    final formData = FormData.fromMap({
      'user_id': userId,
      'username': username,
      'text': text,
      if (clientMessageId.isNotEmpty) 'client_message_id': clientMessageId,
      'file': await MultipartFile.fromFile(imagePath, filename: fileName),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat/multimodal',
        data: formData,
      );

      final data = _requireMap(response.data);
      _throwIfNotOk(data, 'POST /chat/multimodal');

      return ChatResponse.fromJson(data, apiBaseUrl: _activeBaseUrl);
    } on DioException catch (error) {
      final degraded = degradedPayload(error);
      if (degraded != null) {
        return ChatResponse.fromJson(degraded, apiBaseUrl: _activeBaseUrl);
      }
      rethrow;
    }
  }

  Future<UserMemoryResponse> getUserMemory(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memory/user/$userId',
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'GET /memory/user/$userId');
    return UserMemoryResponse.fromJson(data);
  }

  Future<void> clearUserMemory(String userId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/memory/user/$userId',
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'DELETE /memory/user/$userId');
  }

  Future<MemoryPreferenceState> getMemoryPreferences(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/memory/user/$userId/preferences',
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'GET /memory/user/$userId/preferences');

    return MemoryPreferenceState.fromJson(_requireMap(data['preferences']));
  }

  Future<MemoryPreferenceState> setMemoryEnabled({
    required String userId,
    required bool enabled,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/memory/user/$userId/preferences',
      data: {
        'long_term_enabled': enabled,
        'reason': enabled ? 'flutter_enable_memory' : 'flutter_disable_memory',
      },
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'PUT /memory/user/$userId/preferences');

    return MemoryPreferenceState.fromJson(_requireMap(data['preferences']));
  }

  Future<void> editMemory({
    required String userId,
    required String memoryId,
    required String memory,
    String category = 'other',
    String importance = 'medium',
    bool? pinned,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/memory/user/$userId/memories/$memoryId',
      data: {
        'memory': memory,
        'category': category,
        'importance': importance,
        if (pinned != null) 'pinned': pinned,
        'reason': 'flutter_edit_memory',
      },
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'PATCH /memory/user/$userId/memories/$memoryId');
  }

  Future<void> setMemoryPinned({
    required String userId,
    required String memoryId,
    required bool pinned,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memory/user/$userId/memories/$memoryId/pin',
      data: {
        'pinned': pinned,
        'reason': pinned ? 'flutter_pin_memory' : 'flutter_unpin_memory',
      },
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /memory/user/$userId/memories/$memoryId/pin');
  }

  Future<void> mergeMemories({
    required String userId,
    required List<String> memoryIds,
    required String mergedMemory,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/memory/user/$userId/merge',
      data: {
        'memory_ids': memoryIds,
        'merged_memory': mergedMemory,
        'reason': 'flutter_conflict_merge',
      },
    );

    final data = _requireMap(response.data);
    _throwIfNotOk(data, 'POST /memory/user/$userId/merge');
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

class _FailoverInterceptor extends Interceptor {
  _FailoverInterceptor(this._client);

  final ApiClient _client;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = await _client._retryOnOtherBase(err);
    if (response != null) {
      handler.resolve(response);
      return;
    }
    handler.next(err);
  }
}
