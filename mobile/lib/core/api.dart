import 'dart:convert';
import 'package:http/http.dart' as http;
import 'demo.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  final String? code;
  ApiException(this.message, [this.status = 0, this.code]);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nguyen-hoai-nam-2380601398-api.onrender.com/v1',
  );
  static const allowInsecure = bool.fromEnvironment('ALLOW_INSECURE_DEV');
  static const connectionTimeout = Duration(seconds: 90);
  final String endpoint;
  final http.Client client;
  final Duration timeout;
  Api({String? endpoint, http.Client? client, this.timeout = connectionTimeout})
    : endpoint = (endpoint ?? baseUrl).replaceAll(RegExp(r'/$'), ''),
      client = client ?? http.Client();
  bool demo = const bool.fromEnvironment('DEMO_MODE');
  final DemoStore demoStore = DemoStore();
  String? accessToken;
  String? refreshToken;
  Future<void> Function()? onTokenRotation;
  Future<void> Function()? onSessionExpired;
  Future<void>? _refreshing;
  bool get configured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || (allowInsecure && uri.scheme == 'http'));
  }

  Future<dynamic> request(
    String method,
    String path, [
    Json? body,
    bool retry = true,
  ]) async {
    if (demo) return demoStore.request(method, path, body);
    if (!configured) throw ApiException('Cần cấu hình API HTTPS công khai.');
    final sentToken = accessToken;
    final request = http.Request(method, Uri.parse('$endpoint$path'));
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (sentToken != null && !path.startsWith('/auth/'))
        'Authorization': 'Bearer $sentToken',
    });
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } catch (_) {
      throw ApiException(
        'Mất kết nối hoặc máy chủ đang khởi động. Tải lại dữ liệu trước khi gửi lại thao tác.',
      );
    }
    if (response.statusCode == 401 &&
        retry &&
        refreshToken != null &&
        !path.startsWith('/auth/')) {
      // Concurrent 401s share one rotation; a late 401 must not consume another token.
      if (sentToken == accessToken) {
        _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
        await _refreshing;
      }
      return this.request(method, path, body, false);
    }
    dynamic envelope;
    try {
      envelope = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      /* Handled below. */
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && !path.startsWith('/auth/')) {
        await expire();
      }
      final error = envelope is Map ? envelope['error'] : null;
      throw ApiException(
        error is Map && error['message'] is String
            ? error['message']
            : 'Máy chủ trả lỗi ${response.statusCode}',
        response.statusCode,
        error is Map ? error['code']?.toString() : null,
      );
    }
    if (envelope is! Map || !envelope.containsKey('data')) {
      throw ApiException('Phản hồi máy chủ không đúng hợp đồng API.');
    }
    return envelope['data'];
  }

  Future<void> _refresh() async {
    try {
      final result = await request('POST', '/auth/refresh', {
        'refreshToken': refreshToken,
      }, false);
      acceptTokens(Json.from(result));
      await onTokenRotation?.call();
    } catch (_) {
      // Rotation may have succeeded before a timeout: never replay the old refresh token.
      await expire();
      rethrow;
    }
  }

  Future<void> expire() async {
    accessToken = null;
    refreshToken = null;
    await onSessionExpired?.call();
  }

  void acceptTokens(Json result) {
    accessToken = result[demo ? 'access_token' : 'accessToken'];
    refreshToken = result[demo ? 'refresh_token' : 'refreshToken'];
  }

  Future<String> exportCsv() async {
    if (demo) {
      return 'Name,Date,Check in,Check out\nNguyen Hoang Vu,2026-10-29,08:25,17:30\n';
    }
    throw ApiException('Dùng báo cáo tháng để xuất CSV trong ứng dụng.');
  }
}
