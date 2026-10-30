// Visual reference only. Profile and face status are fixtures, not production evidence.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/core/theme.dart';
import 'package:nguyen_hoang_vu/screens/settings.dart';
import '../test/support/shared_backend.dart';

void main() {
  testWidgets('Capture fixture mobile settings reference', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final be = SharedBackend();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: Stack(
            children: [
              SettingsPage(session: Session(be.api)..user = be.user),
              const Positioned(
                top: 18,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    'GIAO DIỆN MẪU',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      color: muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await picture.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        await File(
          '../docs/ui-fixture-settings-mobile.png',
        ).writeAsBytes(bytes);
      } finally {
        picture.dispose();
      }
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
