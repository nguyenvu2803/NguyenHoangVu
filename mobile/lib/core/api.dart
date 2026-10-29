import 'dart:convert';
import 'package:http/http.dart' as http;
import 'demo.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const allowInsecure = bool.fromEnvironment('ALLOW_INSECURE_DEV');
  // Render Free may need over a minute to wake after inactivity.
  static const connectionTimeout = Duration(seconds: 90);
  bool demo = const bool.fromEnvironment('DEMO_MODE');
  final DemoStore demoStore = DemoStore();
  String? accessToken;
  String? refreshToken;
  Future<void> Function()? onTokenRotation;
  Future<dynamic>? _refreshing;
  bool get configured {
    final uri = Uri.tryParse(baseUrl);
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
    if (!configured) {
      throw ApiException(
        'Chưa cấu hình API HTTPS. Xem hướng dẫn deploy hoặc mở bản demo.',
      );
    }
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
    final request = http.Request(method, url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    });
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(connectionTimeout),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
    if (response.statusCode == 401 &&
        retry &&
        refreshToken != null &&
        !path.startsWith('/auth/')) {
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
      await _refreshing;
      return this.request(method, path, body, false);
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : null;
      throw ApiException(
        detail is String
            ? detail
            : detail is List
            ? 'Dữ liệu chưa hợp lệ. Kiểm tra các trường nhập.'
            : 'Máy chủ trả lỗi ${response.statusCode}',
        response.statusCode,
      );
    }
    return data;
  }

  Future<void> _refresh() async {
    final result = await request('POST', '/auth/refresh', {
      'refresh_token': refreshToken,
    }, false);
    acceptTokens(result);
    await onTokenRotation?.call();
  }

  void acceptTokens(Json result) {
    accessToken = result['access_token'];
    refreshToken = result['refresh_token'];
  }

  Future<String> exportCsv() async {
    if (demo) {
      return 'Name,Date,Check in,Check out\nNguyen Hoang Vu,2026-10-29,08:25,17:30\n';
    }
    final response = await http
        .get(
          Uri.parse('$baseUrl/attendance/export'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(connectionTimeout);
    if (response.statusCode != 200) {
      throw ApiException('Không xuất được báo cáo. Vui lòng đăng nhập lại.');
    }
    return utf8.decode(response.bodyBytes);
  }
}
