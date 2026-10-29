import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'api.dart';

class ChatEvent {
  final String type, data;
  const ChatEvent(this.type, this.data);
}

Stream<ChatEvent> decodeChatEvents(Stream<List<int>> bytes) async* {
  var type = 'message';
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield ChatEvent(type, data.join('\n'));
      type = 'message';
      data.clear();
    } else if (!line.startsWith(':')) {
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') type = value;
      if (field == 'data') data.add(value);
    }
  }
}

String chatError(Object error) => error is ApiException && error.status == 404
    ? 'Tin nhắn chưa khả dụng. Liên hệ quản trị viên để cập nhật API và kiểm tra người nhận.'
    : error.toString();

class ChatController extends ChangeNotifier {
  final Api api;
  final String peerId;
  final http.Client Function() streamClient;
  ChatController(this.api, this.peerId, {http.Client Function()? streamClient})
    : streamClient = streamClient ?? http.Client.new;
  final List<Json> messages = [];
  bool online = false, loading = false, sending = false, hasOlder = false;
  String? error;
  bool _disposed = false, _running = false, _initialized = false;
  int _epoch = 0, _failures = 0;
  String? _cursor;
  Json? _pending;
  http.Client? _stream;
  Timer? _retry;
  Future<void>? _syncing;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _merge(List<dynamic> rows) {
    final byId = {for (final row in messages) row['id'].toString(): row};
    for (final row in rows) {
      byId[row['id'].toString()] = Json.from(row);
    }
    messages
      ..clear()
      ..addAll(byId.values);
    messages.sort(
      (a, b) => BigInt.parse(
        a['id'].toString(),
      ).compareTo(BigInt.parse(b['id'].toString())),
    );
  }

  Future<void> sync() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);
  Future<void> _sync() async {
    var more = true;
    while (more && !_disposed) {
      final query = Uri(
        queryParameters: {
          'peerId': peerId,
          if (_cursor != null) 'afterId': _cursor,
        },
      ).query;
      final page = Json.from(await api.request('GET', '/chat/messages?$query'));
      if (_disposed) return;
      final rows = page['messages'] as List;
      _merge(rows);
      if (!_initialized) {
        hasOlder = page['hasMore'] == true;
        _initialized = true;
        more = false;
      } else {
        more = page['hasMore'] == true;
      }
      if (rows.isEmpty) {
        _cursor ??= '0';
        more = false;
      } else {
        final next = rows.last['id'].toString();
        if (next == _cursor) {
          throw ApiException('Con trỏ tin nhắn không tiến triển.');
        }
        _cursor = next;
      }
      _emit();
    }
  }

  Future<void> older() async {
    if (loading || !hasOlder || messages.isEmpty) return;
    loading = true;
    error = null;
    _emit();
    try {
      final query = Uri(
        queryParameters: {
          'peerId': peerId,
          'beforeId': messages.first['id'].toString(),
        },
      ).query;
      final page = Json.from(await api.request('GET', '/chat/messages?$query'));
      if (_disposed) return;
      _merge(page['messages']);
      hasOlder = page['hasMore'] == true;
    } catch (e) {
      error = chatError(e);
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<bool> send(String text, String sourceLanguage) async {
    text = text.trim();
    if (sending || text.isEmpty || _disposed) {
      return false;
    }
    if (text.length > 2000) {
      error = 'Tin nhắn quá dài. Rút ngắn nội dung trước khi gửi.';
      _emit();
      return false;
    }
    // Retain the UUID when a timeout leaves the server result unknown.
    if (_pending?['text'] != text ||
        _pending?['sourceLanguage'] != sourceLanguage) {
      _pending = {
        'clientMessageId': const Uuid().v4(),
        'recipientId': peerId,
        'text': text,
        'sourceLanguage': sourceLanguage,
      };
    }
    sending = true;
    error = null;
    _emit();
    try {
      final row = await api.request('POST', '/chat/messages', _pending);
      if (_disposed) return false;
      _merge([row]);
      _pending = null;
      return true;
    } catch (e) {
      error = chatError(e);
      return false;
    } finally {
      sending = false;
      _emit();
    }
  }

  void start() {
    if (_disposed || _running) return;
    _running = true;
    _failures = 0;
    unawaited(_connect(++_epoch));
  }

  void pause() {
    _running = false;
    _epoch++;
    _retry?.cancel();
    _stream?.close();
    _stream = null;
    online = false;
    _emit();
  }

  Future<void> _connect(int epoch) async {
    bool current() => !_disposed && _running && epoch == _epoch;
    http.Client? client;
    var terminal = false;
    try {
      error = null;
      _emit();
      await api.request(
        'GET',
        '/me',
      ); // Refresh once through the shared API client.
      await sync();
      if (!current()) return;
      client = streamClient();
      _stream = client;
      final uri = Uri.parse(
        '${api.endpoint}/chat/stream',
      ).replace(queryParameters: {'peerId': peerId});
      final request = http.Request('GET', uri)
        ..headers.addAll({
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer ${api.accessToken}',
        });
      final response = await client.send(request).timeout(api.timeout);
      if (!current()) return;
      if (response.statusCode != 200) {
        throw ApiException(
          'Không mở được kết nối tin nhắn (${response.statusCode}).',
          response.statusCode,
        );
      }
      await for (final event in decodeChatEvents(
        response.stream.timeout(const Duration(seconds: 40)),
      )) {
        if (!current()) return;
        if (event.type == 'ready') {
          online = true;
          _failures = 0;
          error = null;
          _emit();
        }
        if (event.type == 'messages') await sync();
        if (event.type == 'session_expired') break;
        if (event.type == 'access_revoked' || event.type == 'unavailable') {
          terminal = true;
          throw ApiException(
            'Quyền trò chuyện thay đổi. Quay lại và kiểm tra tài khoản.',
          );
        }
      }
    } catch (e) {
      if (current()) {
        error = chatError(e);
        if (e is ApiException && [401, 403, 404].contains(e.status)) {
          terminal = true;
        }
      }
    } finally {
      client?.close();
      if (current()) {
        online = false;
        _emit();
        if (terminal) {
          _running = false;
        } else {
          final seconds = (2 * (1 << _failures.clamp(0, 4))).clamp(2, 30);
          _failures++;
          _retry = Timer(
            Duration(seconds: seconds),
            () => unawaited(_connect(epoch)),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    pause();
    _disposed = true;
    super.dispose();
  }
}
