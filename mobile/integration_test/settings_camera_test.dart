import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nguyen_hoang_vu/core/preferences.dart';
import 'package:nguyen_hoang_vu/core/theme.dart';
import 'package:nguyen_hoang_vu/screens/face_camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android stores settings securely and opens real camera with mirror toggle',
    (tester) async {
      final preferences = AppPreferences();
      await preferences.load();
      final beforeScale = preferences.fontScale,
          beforeColor = preferences.background;
      final beforeMirror = preferences.mirrorCamera;
      addTearDown(
        () => preferences.update(
          scale: beforeScale,
          color: beforeColor,
          mirror: beforeMirror,
        ),
      );
      await preferences.update(scale: 1.15, color: 'sky', mirror: true);
      final restored = AppPreferences();
      await restored.load();
      expect(restored.fontScale, 1.15);
      expect(restored.backgroundColor, const Color(0xFFEAF3FC));
      expect(restored.mirrorCamera, true);
      await tester.pumpWidget(
        MaterialApp(theme: appTheme(), home: const FaceCameraPage()),
      );
      for (
        var i = 0;
        i < 50 && find.byType(CameraPreview).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 400));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(find.byType(CameraPreview), findsOneWidget);
      final preview = tester.widget<CameraPreview>(find.byType(CameraPreview));
      expect(preview.controller.value.isInitialized, true);
      final mirror = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(mirror).value, true);
      await tester.tap(mirror);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(mirror).value, false);
      expect(tester.takeException(), isNull);
      // Preview only: do not save or upload a person's camera frame during automated QA.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
