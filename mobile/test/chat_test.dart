import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/chat.dart';

Json message(String id, String text) => {
  'id': id,
  'clientMessageId': 'uuid-$id',
  'senderId': 'peer',
  'recipientId': 'me',
  'text': text,
  'sourceLanguage': 'vi',
  'createdAt': '2026-10-29T00:00:00Z',
};
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), true);
}

void main() {
  test(
    'initial empty history keeps zero cursor so a later burst loads every page',
    () async {
      var calls = 0;
      final api = Api(
        client: MockClient((request) async {
          final query = request.url.queryParameters;
          calls++;
          if (calls == 1)
            return http.Response(
              jsonEncode({
                'data': {'messages': [], 'hasMore': false},
              }),
              200,
            );
          expect(query['afterId'], calls == 2 ? '0' : '1');
          return http.Response(
            jsonEncode({
              'data': {
                'messages': [message(calls == 2 ? '1' : '2', 'burst')],
                'hasMore': calls == 2,
              },
            }),
            200,
          );
        }),
      );
      final chat = ChatController(api, 'peer');
      addTearDown(chat.dispose);
      await chat.sync();
      await chat.sync();
      expect(chat.messages.map((row) => row['id']), ['1', '2']);
      expect(calls, 3);
    },
  );
  test(
    'SSE decodes split UTF-8, CRLF, comments and multiline data; ignores incomplete event',
    () async {
      final raw = utf8.encode(
        ': heartbeat\r\nevent: messages\r\ndata: Xin chào\r\ndata: dòng hai\r\n\r\nevent: discarded\ndata: incomplete',
      );
      final events = await decodeChatEvents(
        Stream.fromIterable(raw.map((byte) => [byte])),
      ).toList();
      expect(events.length, 1);
      expect(events.single.type, 'messages');
      expect(events.single.data, 'Xin chào\ndòng hai');
    },
  );
  test('timeout retry retains UUID; changed draft receives new UUID', () async {
    final bodies = <Json>[];
    var fail = true;
    final api = Api(
      client: MockClient((request) async {
        final body = Json.from(jsonDecode(request.body));
        bodies.add(body);
        if (fail) {
          fail = false;
          throw Exception('response lost');
        }
        return http.Response(
          jsonEncode({'data': message('9007199254740993', body['text'])}),
          200,
        );
      }),
    );
    final chat = ChatController(api, 'peer');
    addTearDown(chat.dispose);
    expect(await chat.send('Hello', 'en'), false);
    expect(await chat.send('Hello', 'en'), true);
    expect(bodies[0]['clientMessageId'], bodies[1]['clientMessageId']);
    expect(await chat.send('Changed', 'en'), true);
    expect(bodies[1]['clientMessageId'], isNot(bodies[2]['clientMessageId']));
    expect(chat.messages.length, 1);
  });
  test(
    'history cursors preserve unseen incoming messages even after a newer send acknowledgement',
    () async {
      final queries = <Map<String, String>>[];
      final api = Api(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'data': message('9007199254740995', 'sent')}),
              201,
            );
          }
          final query = request.url.queryParameters;
          queries.add(query);
          final rows = query.containsKey('afterId')
              ? [
                  message('9007199254740994', 'incoming'),
                  message('9007199254740995', 'sent'),
                ]
              : [message('9007199254740993', 'first')];
          return http.Response(
            jsonEncode({
              'data': {'messages': rows, 'hasMore': false},
            }),
            200,
          );
        }),
      );
      final chat = ChatController(api, 'peer');
      addTearDown(chat.dispose);
      await chat.sync();
      await chat.send('sent', 'en');
      await chat.sync();
      expect(queries.last['afterId'], '9007199254740993');
      expect(chat.messages.map((row) => row['text']), [
        'first',
        'incoming',
        'sent',
      ]);
    },
  );
  test(
    'SSE uses Authorization header and fetches new history on event, then pause closes stream',
    () async {
      final bytes = StreamController<List<int>>();
      var changed = false, closed = false;
      final api = Api(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/me')
                  ? {'id': 'me'}
                  : {
                      'messages': changed ? [message('1', 'new message')] : [],
                      'hasMore': false,
                    },
            }),
            200,
          ),
        ),
      )..accessToken = 'secret-test-token';
      final client = _StreamClient(bytes, (request) {
        expect(request.headers['Authorization'], 'Bearer secret-test-token');
        expect(request.url.queryParameters, {'peerId': 'peer'});
      }, () => closed = true);
      final chat = ChatController(api, 'peer', streamClient: () => client);
      addTearDown(chat.dispose);
      chat.start();
      await until(() => client.opened);
      bytes.add(utf8.encode('event: ready\ndata: {}\n\n'));
      await until(() => chat.online);
      changed = true;
      bytes.add(utf8.encode('event: messages\ndata: {"latestId":"1"}\n\n'));
      await until(() => chat.messages.isNotEmpty);
      expect(chat.messages.single['text'], 'new message');
      chat.pause();
      expect(chat.online, false);
      expect(closed, true);
    },
  );
  test(
    'old deployed API returns actionable message and does not reconnect forever',
    () async {
      var calls = 0;
      final api = Api(
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({'data': {}}),
            request.url.path.endsWith('/me') ? 200 : 404,
          );
        }),
      );
      final chat = ChatController(api, 'peer');
      addTearDown(chat.dispose);
      chat.start();
      await until(() => chat.error != null);
      expect(chat.error, contains('cập nhật API'));
      expect(calls, 2);
      expect(chat.online, false);
    },
  );
}

class _StreamClient extends http.BaseClient {
  final StreamController<List<int>> bytes;
  final void Function(http.BaseRequest) inspect;
  final void Function() onClose;
  bool opened = false;
  _StreamClient(this.bytes, this.inspect, this.onClose);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    inspect(request);
    opened = true;
    return http.StreamedResponse(bytes.stream, 200);
  }

  @override
  void close() {
    onClose();
    unawaited(bytes.close());
  }
}
