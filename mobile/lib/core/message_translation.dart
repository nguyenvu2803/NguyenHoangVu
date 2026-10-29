import 'package:google_mlkit_translation/google_mlkit_translation.dart';

const chatLanguages = {'vi': 'Tiếng Việt', 'en': 'English', 'zh': '中文'};

abstract class MessageTranslator {
  Future<void> prepare();
  Future<String> translate(String text, String source, String target);
  Future<void> close();
}

class DeviceMessageTranslator implements MessageTranslator {
  final _models = OnDeviceTranslatorModelManager();
  final _translators = <String, OnDeviceTranslator>{};
  final _cache = <String, String>{};
  bool _ready = false, _closed = false;
  static const _languages = {
    'vi': TranslateLanguage.vietnamese,
    'en': TranslateLanguage.english,
    'zh': TranslateLanguage.chinese,
  };
  @override
  Future<void> prepare() async {
    for (final code in chatLanguages.keys) {
      if (_closed) return;
      if (!await _models.isModelDownloaded(code)) {
        if (!await _models.downloadModel(code, isWifiRequired: false)) {
          throw StateError(
            'Không tải được gói ${chatLanguages[code]}. Kiểm tra mạng và dung lượng.',
          );
        }
      }
    }
    _ready = true;
  }

  @override
  Future<String> translate(String text, String source, String target) async {
    if (_closed) throw StateError('Bộ dịch đã đóng.');
    if (!_languages.containsKey(source) || !_languages.containsKey(target)) {
      throw ArgumentError('Ngôn ngữ chưa hỗ trợ.');
    }
    if (source == target || text.trim().isEmpty) return text;
    if (!_ready) throw StateError('Tải gói dịch trước khi bật dịch tự động.');
    final key = '$source\u0000$target\u0000$text';
    if (_cache.containsKey(key)) return _cache[key]!;
    final pair = '$source:$target';
    final translator = _translators.putIfAbsent(
      pair,
      () => OnDeviceTranslator(
        sourceLanguage: _languages[source]!,
        targetLanguage: _languages[target]!,
      ),
    );
    final result = await translator.translateText(text);
    if (_cache.length >= 300) _cache.clear();
    _cache[key] = result;
    return result;
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final translator in _translators.values) {
      await translator.close();
    }
    _translators.clear();
    _cache.clear();
  }
}
