import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/preferences.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/main.dart';
import 'package:nguyen_hoang_vu/screens/face_camera.dart';
import 'package:nguyen_hoang_vu/screens/auth.dart';
import 'package:nguyen_hoang_vu/screens/settings.dart';
import 'support/shared_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final stored = <String, String>{};
  setUpAll(() async => initializeDateFormatting('vi_VN'));
  setUp(() {
    stored.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            switch (call.method) {
              case 'write':
                stored[args['key']] = args['value'];
                return null;
              case 'read':
                return stored[args['key']];
              case 'delete':
                stored.remove(args['key']);
                return null;
              default:
                return null;
            }
          },
        );
  });

  test(
    'Appearance persists font, background and mirror across restart',
    () async {
      final first = AppPreferences();
      await first.update(scale: 1.3, color: 'sky', mirror: false);
      final restored = AppPreferences();
      await restored.load();
      expect(restored.fontScale, 1.3);
      expect(restored.backgroundColor, const Color(0xFFEAF3FC));
      expect(restored.mirrorCamera, false);
      await restored.update(scale: 20, color: 'bad');
      expect(restored.fontScale, 1.3);
      expect(restored.background, 'sky');
    },
  );

  test(
    'Face key survives logout, stays scoped to API, and face unlock skips OTP',
    () async {
      final calls = <String>[];
      final api = Api(
        endpoint: 'https://one.example/v1',
        client: MockClient((r) async {
          calls.add(r.url.path);
          if (r.url.path.endsWith('/face-unlock')) {
            expect(jsonDecode(r.body), {
              'username': 'hoangvu',
              'deviceKey': 'device-secret',
              'imageBase64': 'photo',
            });
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'a',
                  'refreshToken': 'r',
                  'user': {'id': 'u', 'username': 'hoangvu'},
                },
              }),
              200,
            );
          }
          return http.Response('{"data":{"loggedOut":true}}', 200);
        }),
      );
      final session = Session(api)..user = {'id': 'u', 'username': 'hoangvu'};
      await session.saveFaceDevice({'deviceKey': 'device-secret'});
      await session.logout();
      expect((await session.savedFaceAccount())?['username'], 'hoangvu');
      expect(
        await Session(
          Api(endpoint: 'https://two.example/v1'),
        ).savedFaceAccount(),
        isNull,
      );
      await session.unlockWithFace('photo');
      expect(session.user?['id'], 'u');
      expect(calls, ['/v1/auth/face-unlock']);
      await session.forgetFaceDevice();
      await expectLater(
        session.unlockWithFace('photo'),
        throwsA(isA<ApiException>()),
      );
      expect(calls.length, 1);
    },
  );

  test(
    'Camera mirror flips pixels and normalizes orientation before upload',
    () {
      final photo = img.Image(width: 120, height: 80);
      img.fillRect(
        photo,
        x1: 0,
        y1: 0,
        x2: 59,
        y2: 79,
        color: img.ColorRgb8(255, 0, 0),
      );
      img.fillRect(
        photo,
        x1: 60,
        y1: 0,
        x2: 119,
        y2: 79,
        color: img.ColorRgb8(0, 0, 255),
      );
      final input = img.encodePng(photo);
      final plain = img.decodeJpg(prepareFacePhoto((input, false)))!;
      final mirror = img.decodeJpg(prepareFacePhoto((input, true)))!;
      expect(plain.getPixel(10, 10).r, greaterThan(200));
      expect(mirror.getPixel(10, 10).b, greaterThan(200));
      final large = img.Image(width: 1600, height: 1200);
      final small = img.decodeJpg(
        prepareFacePhoto((img.encodePng(large), true)),
      )!;
      expect(small.width, 1024);
      expect(small.height, 768);
    },
  );

  for (final quick in [false, true]) {
    test('Face enrollment uses compatible payload, quick=$quick', () async {
      var enrolled = false;
      final session = Session(
        Api(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/health')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'status': 'ok',
                    if (quick) 'features': {'quickFaceLogin': true},
                  },
                }),
                200,
              );
            }
            expect(r.method, 'POST');
            expect(r.url.path, '/v1/face/enroll');
            expect(jsonDecode(r.body), {
              'imageBase64': 'camera-photo',
              if (quick) 'enableQuickLogin': true,
            });
            enrolled = true;
            return http.Response(
              jsonEncode({
                'data': {
                  'enrolled': true,
                  if (quick) 'deviceKey': 'new-device-secret',
                },
              }),
              201,
            );
          }),
        ),
      )..user = {'id': 'u', 'username': 'hoangvu'};
      await session.saveFaceDevice({'deviceKey': 'old-device-secret'});
      final supported = await session.supportsQuickFaceLogin();
      expect(supported, quick);
      await session.enrollFace('camera-photo', quickLogin: supported);
      expect(enrolled, true);
      final saved = await session.savedFaceAccount();
      if (quick) {
        expect(saved?['deviceKey'], 'new-device-secret');
      } else {
        expect(saved, isNull);
      }
    });
  }

  for (final directSession in [false, true]) {
    test('Face login handles session or OTP, direct=$directSession', () async {
      final user = SharedBackend().user;
      final otp = {
        'challengeId': 'face-challenge',
        'maskedEmail': 't***@example.org',
        'expiresAt': '2030-01-01T00:10:00Z',
        'retryAfterSeconds': 60,
      };
      final calls = <String>[];
      final session = Session(
        Api(
          client: MockClient((r) async {
            calls.add(r.url.path);
            expect(r.url.path, '/v1/auth/face-login');
            expect(jsonDecode(r.body), {
              'username': 'hoangvu',
              'imageBase64': 'camera-photo',
            });
            return http.Response(
              jsonEncode({
                'data': directSession
                    ? {
                        'accessToken': 'face-access',
                        'refreshToken': 'face-refresh',
                        'user': user,
                      }
                    : otp,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final challenge = await session.loginWithFace('hoangvu', 'camera-photo');
      if (directSession) {
        expect(challenge, isNull);
        expect(session.user?['id'], user['id']);
        expect(session.api.accessToken, 'face-access');
        expect(session.api.refreshToken, 'face-refresh');
      } else {
        expect(challenge, otp);
        expect(session.user, isNull);
        expect(session.api.accessToken, isNull);
      }
      expect(calls, ['/v1/auth/face-login']);
    });
  }

  testWidgets('Malformed OTP response never opens null-email OTP form', (
    tester,
  ) async {
    final session = Session(
      Api(
        client: MockClient(
          (r) async => http.Response('{"data":{"unexpected":true}}', 200),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AuthScreen(session: session)));
    await tester.enterText(find.byType(TextFormField).at(0), 'hoangvu');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await tester.ensureVisible(find.text('Tiếp tục với OTP'));
    await tester.tap(find.text('Tiếp tục với OTP'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Máy chủ chưa trả thông tin OTP hợp lệ.'),
      findsOneWidget,
    );
    expect(find.text('Kiểm tra email.'), findsNothing);
    expect(find.textContaining('đến null'), findsNothing);
    expect(session.user, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Legacy API Settings offers compatible face enrollment consent', (
    tester,
  ) async {
    final be = SharedBackend(quickFaceLogin: false);
    final session = Session(be.api)..user = be.user;
    await tester.pumpWidget(MaterialApp(home: SettingsPage(session: session)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Thiết lập khuôn mặt'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Thiết lập khuôn mặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thiết lập khuôn mặt'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký khuôn mặt?'), findsOneWidget);
    expect(
      find.textContaining(
        'máy chủ có thể cho đăng nhập trực tiếp hoặc yêu cầu OTP email.',
      ),
      findsOneWidget,
    );
    expect(be.calls.where((c) => c['path'] == '/face/enroll'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Saved quick key on legacy server falls back to face and OTP', (
    tester,
  ) async {
    final be = SharedBackend(quickFaceLogin: false);
    final session = Session(be.api)..user = be.user;
    await session.saveFaceDevice({'deviceKey': 'previous-device-secret'});
    session.user = null;
    await tester.pumpWidget(MaterialApp(home: AuthScreen(session: session)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.tap(find.text('Đăng nhập bằng khuôn mặt'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Máy chủ có thể cho đăng nhập trực tiếp hoặc yêu cầu OTP email.',
      ),
      findsOneWidget,
    );
    expect(be.calls.where((c) => c['path'] == '/auth/face-unlock'), isEmpty);
    expect(be.calls.where((c) => c['path'] == '/health'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  test('OTP clock uses server Date, not incorrect device wall clock', () async {
    final api = Api(
      client: MockClient(
        (r) async => http.Response(
          '{"data":{}}',
          200,
          headers: {'date': 'Tue, 01 Jan 2030 00:00:00 GMT'},
        ),
      ),
    );
    await api.request('GET', '/health');
    expect(
      api.serverNow.difference(DateTime.utc(2030)).inSeconds.abs(),
      lessThan(2),
    );
  });

  testWidgets(
    'OTP form lets server validate expiry when local countdown is zero',
    (tester) async {
      var verified = false;
      final be = SharedBackend();
      final session = Session(
        Api(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/auth/login')) {
              return http.Response(
                jsonEncode({
                  'data': {
                    'challengeId': 'current-challenge',
                    'maskedEmail': 't***@example.org',
                    'expiresAt': '2000-01-01T00:00:00Z',
                    'retryAfterSeconds': 60,
                  },
                }),
                200,
              );
            }
            verified = true;
            expect(jsonDecode(r.body), {
              'challengeId': 'current-challenge',
              'code': '123456',
            });
            return http.Response(
              jsonEncode({
                'data': {
                  'accessToken': 'a',
                  'refreshToken': 'r',
                  'user': {...be.user, 'status': 'pending'},
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(AttendanceApp(session: session));
      await tester.enterText(find.byType(TextFormField).at(0), 'hoangvu');
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.ensureVisible(find.text('Tiếp tục với OTP'));
      await tester.tap(find.text('Tiếp tục với OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Xác nhận & đăng nhập'));
      await tester.pumpAndSettle();
      expect(verified, true);
      expect(find.text('Kiểm tra trạng thái duyệt'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Settings fit 320px, apply global appearance and save real profile contract for all roles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final role in ['employee', 'manager', 'admin']) {
        final be = SharedBackend(role: role);
        final session = Session(be.api)..user = be.user;
        await tester.pumpWidget(
          AttendanceApp(key: ValueKey(role), session: session),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Cài đặt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rất lớn'));
        await tester.pumpAndSettle();
        expect(session.preferences.fontScale, 1.3);
        await tester.ensureVisible(find.text('Xanh trời'));
        await tester.tap(find.text('Xanh trời'));
        await tester.pumpAndSettle();
        expect(session.preferences.background, 'sky');
        final settingsContext = tester.element(find.text('Giao diện của bạn'));
        expect(
          Theme.of(settingsContext).scaffoldBackgroundColor,
          AppPreferences.backgrounds['sky'],
        );
        expect(
          MediaQuery.textScalerOf(settingsContext).scale(10),
          closeTo(13, .01),
        );
        await tester.scrollUntilVisible(
          find.text('Họ và tên'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Vũ đã cập nhật',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Hỗ trợ đội ngũ',
        );
        await tester.ensureVisible(find.text('Lưu hồ sơ'));
        await tester.tap(find.text('Lưu hồ sơ'));
        await tester.pumpAndSettle();
        final patch = be.calls.singleWhere(
          (c) => c['path'] == '/me' && c['method'] == 'PATCH',
        );
        expect(patch['body'], {
          'fullName': 'Vũ đã cập nhật',
          'phone': '0912345678',
          'bio': 'Hỗ trợ đội ngũ',
        });
        expect(session.user?['fullName'], 'Vũ đã cập nhật');
        expect(session.user?['role'], role);
        expect(tester.takeException(), isNull, reason: role);
        Navigator.of(tester.element(find.text('Cập nhật hồ sơ'))).pop();
        await tester.pumpAndSettle();
        for (var index = 0; index < 5; index++) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'role=$role page=$index font=130% width=320',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
