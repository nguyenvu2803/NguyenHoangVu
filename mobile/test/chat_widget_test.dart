import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/chat.dart';
import 'package:nguyen_hoang_vu/core/message_translation.dart';
import 'package:nguyen_hoang_vu/core/session.dart';
import 'package:nguyen_hoang_vu/core/theme.dart';
import 'package:nguyen_hoang_vu/screens/chat.dart';

class _Chat extends ChatController {
  _Chat() : super(Api(), 'peer');
  @override
  void start() {
    online = true;
  }

  @override
  void pause() {
    online = false;
  }

  void receive() {
    messages.add({
      'id': '1',
      'senderId': 'peer',
      'text': 'Xin chào',
      'sourceLanguage': 'vi',
      'createdAt': '2026-10-29T00:00:00Z',
    });
    notifyListeners();
  }
}

class _Translator implements MessageTranslator {
  final calls = <(String, Completer<String>)>[];
  @override
  Future<void> prepare() async {}
  @override
  Future<String> translate(String text, String source, String target) {
    final result = Completer<String>();
    calls.add((text, result));
    return result.future;
  }

  @override
  Future<void> close() async {
    for (final call in calls) {
      if (!call.$2.isCompleted) call.$2.complete('closed');
    }
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));
  Future<void> open(
    WidgetTester tester,
    _Chat chat,
    _Translator translator,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = Session(Api())
      ..user = {'id': 'me', 'role': 'employee', 'status': 'active'};
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: ChatConversation(
          session: session,
          peer: {'id': 'peer', 'fullName': 'Quản lý chi nhánh'},
          controller: chat,
          translator: translator,
        ),
      ),
    );
    await tester.tap(find.text('Bật dịch · tải gói lần đầu (cần mạng)'));
    await tester.pump();
  }

  testWidgets(
    'draft translation ignores stale responses after typing changes on 320px',
    (tester) async {
      final chat = _Chat(), translator = _Translator();
      await open(tester, chat, translator);
      await tester.enterText(find.byType(TextField), 'draft one');
      await tester.pump(const Duration(milliseconds: 410));
      await tester.enterText(find.byType(TextField), 'draft two');
      await tester.pump(const Duration(milliseconds: 410));
      expect(translator.calls.map((call) => call.$1), [
        'draft one',
        'draft two',
      ]);
      translator.calls[1].$2.complete('new translation');
      await tester.pump();
      translator.calls[0].$2.complete('old translation');
      await tester.pump();
      expect(find.text('Bản dịch xem trước: new translation'), findsOneWidget);
      expect(find.textContaining('old translation'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'incoming realtime message translates automatically and keeps original visible',
    (tester) async {
      final chat = _Chat(), translator = _Translator();
      await open(tester, chat, translator);
      chat.receive();
      await tester.pump();
      expect(translator.calls.single.$1, 'Xin chào');
      translator.calls.single.$2.complete('Hello');
      await tester.pump();
      expect(find.text('Xin chào'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
