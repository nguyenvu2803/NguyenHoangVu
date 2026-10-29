// Visual reference only. All conversation text and translations are fixtures.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/chat.dart';
import 'package:nguyen_hoang_vu/core/message_translation.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/core/theme.dart';
import 'package:nguyen_hoang_vu/screens/chat.dart';

class _ReferenceChat extends ChatController {
  _ReferenceChat() : super(Api(), 'manager') {
    messages.addAll([
      {
        'id': '1',
        'senderId': 'me',
        'text': 'Please check my shift tomorrow.',
        'sourceLanguage': 'en',
        'createdAt': '2026-10-29T01:00:00Z',
      },
      {
        'id': '2',
        'senderId': 'manager',
        'text': 'Ca của bạn bắt đầu lúc 08:00.',
        'sourceLanguage': 'vi',
        'createdAt': '2026-10-29T01:01:00Z',
      },
      {
        'id': '3',
        'senderId': 'me',
        'text': 'Cảm ơn, mình sẽ đến đúng giờ.',
        'sourceLanguage': 'vi',
        'createdAt': '2026-10-29T01:02:00Z',
      },
    ]);
  }
  @override
  void start() {
    online = true;
  }

  @override
  void pause() {}
}

class _ReferenceTranslator implements MessageTranslator {
  @override
  Future<void> prepare() async {}
  @override
  Future<String> translate(String text, String source, String target) async =>
      switch (text) {
        'Ca của bạn bắt đầu lúc 08:00.' => 'Your shift starts at 08:00.',
        'Cảm ơn, mình sẽ đến đúng giờ.' => 'Thank you, I will be on time.',
        _ => text,
      };
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('Capture fixture chat mobile reference', (tester) async {
    await initializeDateFormatting('vi_VN');
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final family in ['Manrope', 'Lora']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: appTheme(),
          home: Banner(
            message: 'FIXTURE',
            location: BannerLocation.topEnd,
            child: ChatConversation(
              session: Session(Api())
                ..user = {'id': 'me', 'role': 'employee', 'status': 'active'},
              peer: {'id': 'manager', 'fullName': 'Mai Anh · Quản lý'},
              controller: _ReferenceChat(),
              translator: _ReferenceTranslator(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bật dịch · tải gói lần đầu (cần mạng)'));
    await tester.pumpAndSettle();
    final boundary =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await picture.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        await File('../docs/ui-fixture-chat-mobile.png').writeAsBytes(bytes);
      } finally {
        picture.dispose();
      }
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
