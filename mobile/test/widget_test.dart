import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    for (final family in ['Manrope', 'Lora']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });
  testWidgets(
    'Auth opens explicit demo and renders employee dashboard on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session(Api());
      await tester.pumpWidget(AttendanceApp(session: session));
      expect(find.text('Chào ngày mới.'), findsOneWidget);
      await tester.ensureVisible(find.text('Khám phá bản demo'));
      await tester.tap(find.text('Khám phá bản demo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('DEMO'), findsOneWidget);
      expect(find.text('Sẵn sàng cho\nmột ngày tốt lành.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Admin management and customer routing stay separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = Session(Api());
    await session.enterDemo(1);
    await tester.pumpWidget(AttendanceApp(session: session));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Quản lý'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Đội ngũ & vận hành.'), findsOneWidget);
    expect(find.text('Mở QR chấm công'), findsNothing);
    await tester.tap(find.text('Chi nhánh'));
    await tester.pump();
    expect(find.text('Mở QR chấm công'), findsOneWidget);
    await session.enterDemo(2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kết nối bắt đầu từ đây.'), findsOneWidget);
    expect(find.text('Quản lý'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('All employee screens fit narrow phones and tablets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      final session = Session(Api());
      await session.enterDemo();
      await tester.pumpWidget(
        AttendanceApp(key: ValueKey(width), session: session),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width, screen=$index',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Employee creates leave through validated mobile form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = Session(Api());
    await session.enterDemo();
    await tester.pumpWidget(AttendanceApp(session: session));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Tạo đơn nghỉ'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
      find.byType(TextFormField).last,
      'Nghỉ cùng gia đình trong ngày',
    );
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Nghỉ cùng gia đình trong ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
