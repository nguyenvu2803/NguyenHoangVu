// UI reference images use HTTP fixtures, never production credentials.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/main.dart';
import '../test/support/shared_backend.dart';

void main() {
  testWidgets('Capture UI references with shared API fixtures', (tester) async {
    await initializeDateFormatting('vi_VN');
    for (final family in ['Manrope', 'Lora']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    Future<void> save(String name) async {
      await tester.pump(const Duration(seconds: 1));
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await File('../docs/$name.png').writeAsBytes(bytes);
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    }

    tester.view.physicalSize = const Size(390, 900);
    final employee = SharedBackend();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: AttendanceApp(
          session: Session(employee.api)..user = employee.user,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await save('ui-fixture-dashboard-mobile');
    for (final pair in [
      (1, 'shifts'),
      (2, 'corrections'),
      (3, 'report'),
      (4, 'profile'),
    ]) {
      await tester.tap(find.byType(NavigationDestination).at(pair.$1));
      await tester.pumpAndSettle();
      await save('ui-fixture-${pair.$2}-mobile');
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(1440, 1000);
    final admin = SharedBackend(role: 'admin');
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: AttendanceApp(session: Session(admin.api)..user = admin.user),
      ),
    );
    await tester.pumpAndSettle();
    await save('ui-fixture-dashboard-desktop');
    await tester.tap(find.text('Quản trị'));
    await tester.pumpAndSettle();
    await save('ui-fixture-management-desktop');
    await tester.pumpWidget(const SizedBox());
  });
}
