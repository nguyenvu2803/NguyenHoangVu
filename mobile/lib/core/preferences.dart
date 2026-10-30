import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme.dart';

class AppPreferences extends ChangeNotifier {
  final FlutterSecureStorage storage;
  AppPreferences({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  static const backgrounds = <String, Color>{
    'mint': paper,
    'sand': Color(0xFFFFF3E3),
    'sky': Color(0xFFEAF3FC),
    'rose': Color(0xFFFFEDF0),
  };
  double fontScale = 1;
  String background = 'mint';
  bool mirrorCamera = true;
  Color get backgroundColor => backgrounds[background] ?? paper;

  Future<void> load() async {
    try {
      final raw = await storage.read(key: 'appearance_v1');
      if (raw == null) return;
      final value = jsonDecode(raw) as Map;
      final scale = value['fontScale'];
      if (scale is num && scale.isFinite) {
        fontScale = scale.toDouble().clamp(.85, 1.3);
      }
      if (backgrounds.containsKey(value['background'])) {
        background = value['background'] as String;
      }
      mirrorCamera = value['mirrorCamera'] != false;
      notifyListeners();
    } catch (_) {
      // Invalid preferences must not prevent login.
    }
  }

  Future<void> update({double? scale, String? color, bool? mirror}) async {
    final nextScale = (scale ?? fontScale).clamp(.85, 1.3).toDouble();
    final nextColor = backgrounds.containsKey(color) ? color! : background;
    final nextMirror = mirror ?? mirrorCamera;
    await storage.write(
      key: 'appearance_v1',
      value: jsonEncode({
        'fontScale': nextScale,
        'background': nextColor,
        'mirrorCamera': nextMirror,
      }),
    );
    fontScale = nextScale;
    background = nextColor;
    mirrorCamera = nextMirror;
    notifyListeners();
  }
}
