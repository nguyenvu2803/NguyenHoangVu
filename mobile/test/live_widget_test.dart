import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/main.dart';
import 'support/shared_backend.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  Future<void> size(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'Username/password then email OTP reaches live-schema dashboard',
    (tester) async {
      await size(tester, 390);
      final be = SharedBackend();
      final session = Session(be.api);
      await tester.pumpWidget(AttendanceApp(session: session));
      await tester.enterText(find.byType(TextFormField).at(0), 'hoangvu');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'correct-password',
      );
      await tapVisible(tester, find.text('Tiếp tục với OTP'));
      expect(find.text('Kiểm tra email.'), findsOneWidget);
      expect(be.calls.single['body'], {
        'username': 'hoangvu',
        'password': 'correct-password',
      });
      await tester.enterText(find.byType(TextFormField), '123456');
      await tapVisible(tester, find.text('Xác nhận & đăng nhập'));
      expect(
        be.calls.where((c) => c['path'] == '/auth/verify-otp').single['body'],
        {'challengeId': 'challenge-1', 'code': '123456'},
      );
      expect(find.text('Nhịp cân bằng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Register strict schema; pending user cannot enter dashboard', (
    tester,
  ) async {
    await size(tester, 390);
    final be = SharedBackend(status: 'pending');
    await tester.pumpWidget(AttendanceApp(session: Session(be.api)));
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    final inputs = find.byType(TextFormField);
    for (final entry in [
      (0, 'Nguyễn Hoàng Vũ'),
      (1, 'hoangvu'),
      (2, 'test@example.org'),
      (3, 'correct-password'),
    ]) {
      await tester.enterText(inputs.at(entry.$1), entry.$2);
    }
    await tapVisible(tester, find.text('Tạo tài khoản'));
    expect(be.calls.single['body'].keys.toSet(), {
      'fullName',
      'username',
      'email',
      'password',
    });
    await tester.enterText(find.byType(TextFormField), '123456');
    await tapVisible(tester, find.text('Xác nhận & đăng nhập'));
    expect(find.text('Kiểm tra trạng thái duyệt'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(be.calls.where((c) => c['path'] == '/dashboard'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Live screens fit 320px for three roles; manager cannot write employees',
    (tester) async {
      await size(tester, 320);
      for (final role in ['employee', 'manager', 'admin']) {
        final be = SharedBackend(role: role);
        final session = Session(be.api)..user = be.user;
        session.api.accessToken = 'fixture';
        await tester.pumpWidget(
          AttendanceApp(key: ValueKey(role), session: session),
        );
        await tester.pumpAndSettle();
        for (var index = 0; index < 5; index++) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'role=$role page=$index',
          );
          if (index == 3 && role != 'employee') {
            expect(
              find.text('Thêm nhân viên'),
              role == 'admin' ? findsOneWidget : findsNothing,
            );
            await tapVisible(tester, find.text('Chi nhánh'));
            expect(
              find.text('Thêm chi nhánh'),
              role == 'admin' ? findsOneWidget : findsNothing,
            );
            await tapVisible(tester, find.text('Ca làm'));
            expect(find.text('Phân ca'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('Admin create sends camelCase fields without readonly metadata', (
    tester,
  ) async {
    await size(tester, 390);
    final be = SharedBackend(role: 'admin');
    final session = Session(be.api)..user = be.user;
    await tester.pumpWidget(AttendanceApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Thêm nhân viên'));
    final fields = find.byType(TextFormField);
    for (final entry in [
      (0, 'Nhân viên kiểm thử'),
      (1, 'test_employee'),
      (2, 'employee@example.org'),
      (3, 'temporary-password'),
    ]) {
      await tester.enterText(fields.at(entry.$1), entry.$2);
    }
    await tapVisible(tester, find.text('Lưu thay đổi'));
    final payload = be.calls
        .where((c) => c['path'] == '/employees' && c['method'] == 'POST')
        .single['body'];
    expect(payload, {
      'fullName': 'Nhân viên kiểm thử',
      'username': 'test_employee',
      'email': 'employee@example.org',
      'password': 'temporary-password',
      'role': 'employee',
      'status': 'pending',
    });
    expect(find.text('Nhân viên kiểm thử'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Desktop admin sidebar and report route render', (tester) async {
    await size(tester, 1440);
    final be = SharedBackend(role: 'admin');
    await tester.pumpWidget(
      AttendanceApp(session: Session(be.api)..user = be.user),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tapVisible(tester, find.text('Quản lý'));
    expect(find.text('Vận hành có nhịp.'), findsOneWidget);
    await tester.tap(find.byTooltip('Báo cáo tháng'));
    await tester.pumpAndSettle();
    expect(find.text('Giờ công rõ ràng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
