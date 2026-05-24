import 'package:dio/dio.dart';

class ChatErrorText {
  static String friendly(Object error) {
    if (error is DioException) {
      return _fromDio(error);
    }

    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Connection refused')) {
      return '连接不上后端。请确认电脑后端正在运行，并且手机和电脑在同一个网络里。';
    }

    if (text.contains('TimeoutException') || text.contains('timeout')) {
      return '后端响应超时了。可以稍后重试，或者检查模型服务是否正在生成。';
    }

    return '这次请求失败了：$text';
  }

  static String _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '后端响应超时了。请检查服务是否还在运行。';
      case DioExceptionType.connectionError:
        return '连接不上后端。请检查 API 地址、电脑防火墙和同一 Wi-Fi。';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 500) {
          return '后端处理失败了。请看电脑端后端日志里的错误信息。';
        }
        return '后端返回了异常状态：$code';
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.badCertificate:
        return '连接证书异常。';
      case DioExceptionType.unknown:
        return '网络请求失败。请确认后端地址是否正确。';
    }
  }
}
