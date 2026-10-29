import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nguyen_hoang_vu/core/message_translation.dart';
import 'package:nguyen_hoang_vu/core/theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android ML Kit downloads real models and translates Vietnamese, English and Chinese',
    (tester) async {
      final translator = DeviceMessageTranslator();
      addTearDown(translator.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: Center(
              child: Text('Đang kiểm thử mô hình dịch thật trên Android…'),
            ),
          ),
        ),
      );
      await translator.prepare().timeout(const Duration(minutes: 8));
      final english = await translator.translate('Xin chào', 'vi', 'en');
      final vietnamese = await translator.translate('Hello', 'en', 'vi');
      final chinese = await translator.translate('Hello', 'en', 'zh');
      expect(
        english.toLowerCase(),
        anyOf(contains('hello'), matches(r'^hi[.!]?$')),
      );
      expect(
        vietnamese.toLowerCase(),
        anyOf(contains('chào'), contains('xin')),
      );
      expect(chinese, contains('好'));
      // Display actual native results; this test does not claim a production chat session.
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('NguyenHoangVu · Kiểm thử dịch')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.translate, size: 56, color: forest),
                  const SizedBox(height: 24),
                  const Text(
                    'ML Kit trên Android',
                    style: TextStyle(fontFamily: 'Lora', fontSize: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Xin chào → $english\nHello → $vietnamese\nHello → $chinese',
                    style: const TextStyle(fontSize: 20, height: 2),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kết quả từ mô hình thật. Kiểm thử độc lập, chưa phải hội thoại trên API public.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final bytes = await binding.takeScreenshot('native-translation');
      final directory = await getApplicationDocumentsDirectory();
      await File(
        '${directory.path}/native-translation.png',
      ).writeAsBytes(bytes);
      debugPrint(
        'Native ML Kit results: vi-en=$english; en-vi=$vietnamese; en-zh=$chinese',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
