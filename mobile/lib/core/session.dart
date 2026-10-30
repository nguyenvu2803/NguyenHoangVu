import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'api.dart';
import 'preferences.dart';

class Session extends ChangeNotifier {
  final Api api;
  Json? user;
  final AppPreferences preferences;
  final storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final biometrics = LocalAuthentication();
  Session(this.api, {AppPreferences? preferences})
    : preferences = preferences ?? AppPreferences() {
    api.onTokenRotation = syncBiometricToken;
    api.onSessionExpired = clear;
  }
  bool get isAdmin => user?['role'] == 'admin';
  bool get isCustomer => user?['role'] == 'customer';

  String get _faceStorageKey =>
      'face_device_${sha256.convert(utf8.encode(api.endpoint))}';

  Future<Json?> savedFaceAccount() async {
    if (api.demo || kIsWeb) return null;
    final raw = await storage.read(key: _faceStorageKey);
    if (raw == null) return null;
    try {
      final value = Json.from(jsonDecode(raw));
      if (value['username'] is String && value['deviceKey'] is String) {
        return value;
      }
    } catch (_) {
      /* Invalid device registration can be replaced in Settings. */
    }
    return null;
  }

  Future<void> saveFaceDevice(Json enrollment) async {
    if (enrollment['deviceKey'] is! String) {
      throw ApiException('Máy chủ chưa hỗ trợ đăng nhập khuôn mặt không OTP.');
    }
    await storage.write(
      key: _faceStorageKey,
      value: jsonEncode({
        'username': user!['username'],
        'deviceKey': enrollment['deviceKey'],
      }),
    );
  }

  Future<void> forgetFaceDevice() => storage.delete(key: _faceStorageKey);

  Future<void> unlockWithFace(String image) async {
    final account = await savedFaceAccount();
    if (account == null) {
      throw ApiException(
        'Đăng nhập mật khẩu và OTP, vào Cài đặt để thiết lập khuôn mặt trên thiết bị này.',
      );
    }
    final result = await api.request('POST', '/auth/face-unlock', {
      ...account,
      'imageBase64': image,
    });
    await accept(Json.from(result));
  }

  Future<void> accept(Json result) async {
    api.acceptTokens(result);
    user = Map<String, dynamic>.from(result['user']);
    if (!api.demo && !kIsWeb) {
      final enrolled = await storage.read(key: 'biometric_user_id');
      if (enrolled != null && enrolled != user!['id'].toString()) {
        await storage.delete(key: 'biometric_refresh');
        await storage.delete(key: 'biometric_user_id');
      }
    }
    notifyListeners();
  }

  Future<void> enterDemo([int role = 0]) async {
    api.demo = true;
    api.demoStore.roleIndex = role;
    user = Map<String, dynamic>.from(api.demoStore.user);
    notifyListeners();
  }

  Future<void> enableBiometrics() async {
    if (api.demo || kIsWeb) {
      throw ApiException(
        'Sinh trắc học cần bản Android/iOS và tài khoản máy chủ thật.',
      );
    }
    if (!await biometrics.canCheckBiometrics) {
      throw ApiException('Thiết bị chưa đăng ký Face ID hoặc vân tay.');
    }
    final ok = await biometrics.authenticate(
      localizedReason: 'Xác nhận bật đăng nhập Face ID / vân tay',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!ok) throw ApiException('Chưa xác thực sinh trắc học');
    await storage.write(key: 'biometric_refresh', value: api.refreshToken);
    await storage.write(
      key: 'biometric_user_id',
      value: user!['id'].toString(),
    );
  }

  Future<void> biometricLogin() async {
    if (api.demo) {
      throw ApiException('Sinh trắc học cần đăng nhập với API thật.');
    }
    if (kIsWeb) {
      throw ApiException('Face ID / vân tay chỉ hỗ trợ ứng dụng Android/iOS.');
    }
    final token = await storage.read(key: 'biometric_refresh');
    if (token == null) {
      throw ApiException(
        'Đăng nhập bằng OTP rồi bật sinh trắc học trong Hồ sơ trước.',
      );
    }
    final ok = await biometrics.authenticate(
      localizedReason: 'Xác nhận đăng nhập NguyenHoangVu',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!ok) return;
    final result = await api.request('POST', '/auth/refresh', {
      'refreshToken': token,
    });
    await accept(result);
    await storage.write(key: 'biometric_refresh', value: api.refreshToken);
  }

  Future<void> syncBiometricToken() async {
    if (api.demo || kIsWeb || api.refreshToken == null) return;
    if (user != null &&
        await storage.read(key: 'biometric_user_id') ==
            user!['id'].toString()) {
      await storage.write(key: 'biometric_refresh', value: api.refreshToken);
    }
  }

  // Lock preserves the explicitly enrolled device session; logout revokes it.
  Future<void> lock() async {
    await syncBiometricToken();
    user = null;
    api.accessToken = null;
    notifyListeners();
  }

  Future<void> clear() async {
    user = null;
    api.accessToken = null;
    api.refreshToken = null;
    notifyListeners();
    if (!api.demo && !kIsWeb) {
      await storage.delete(key: 'biometric_refresh');
      await storage.delete(key: 'biometric_user_id');
    }
  }

  Future<void> reloadUser() async {
    user = Json.from(await api.request('GET', '/me'));
    notifyListeners();
  }

  Future<void> updateProfile(Json changes) async {
    user = Json.from(await api.request('PATCH', '/me', changes));
    notifyListeners();
  }

  Future<void> logout() async {
    final token = api.refreshToken;
    try {
      if (token != null) {
        await api.request('POST', '/auth/logout', {
          api.demo ? 'refresh_token' : 'refreshToken': token,
        });
      }
    } finally {
      await clear();
      api.demo = const bool.fromEnvironment('DEMO_MODE');
    }
  }
}
