import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/live.dart';
import 'support/shared_backend.dart';

http.Response response(dynamic data, [int status = 200]) => http.Response(
  jsonEncode(status >= 400 ? {'error': data} : {'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  test('Live base uses public HTTPS versioned API and unwraps data', () async {
    final api = Api(
      client: MockClient((r) async {
        expect(r.url.toString(), '${Api.baseUrl}/health');
        return response({'status': 'ok'});
      }),
    );
    expect(Uri.parse(Api.baseUrl).scheme, 'https');
    expect((await api.request('GET', '/health'))['status'], 'ok');
  });
  test('Server validation code and Vietnamese message reach UI', () async {
    final api = Api(
      client: MockClient(
        (r) async => response({
          'code': 'SHIFT_PLAN_LOCKED',
          'message': 'Ca đã có lịch sử.',
        }, 409),
      ),
    );
    await expectLater(
      api.request('PATCH', '/shifts/$shiftId', {'title': 'Đổi tên'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'SHIFT_PLAN_LOCKED')
            .having((e) => e.message, 'message', 'Ca đã có lịch sử.'),
      ),
    );
  });
  test('Concurrent protected requests rotate refresh token once', () async {
    int rotations = 0;
    final api =
        Api(
            client: MockClient((r) async {
              if (r.url.path.endsWith('/auth/refresh')) {
                rotations++;
                expect(jsonDecode(r.body), {'refreshToken': 'r-old'});
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return response({
                  'accessToken': 'a-new',
                  'refreshToken': 'r-new',
                  'user': {},
                });
              }
              if (r.headers['Authorization'] == 'Bearer a-old') {
                await Future<void>.delayed(const Duration(milliseconds: 5));
                return response({
                  'code': 'TOKEN_EXPIRED',
                  'message': 'Hết hạn',
                }, 401);
              }
              expect(r.headers['Authorization'], 'Bearer a-new');
              return response([]);
            }),
          )
          ..accessToken = 'a-old'
          ..refreshToken = 'r-old';
    await Future.wait([
      api.request('GET', '/shifts'),
      api.request('GET', '/employees'),
      api.request('GET', '/attendance'),
    ]);
    expect(rotations, 1);
    expect(api.refreshToken, 'r-new');
  });
  test('Late 401 after completed rotation reuses fresh access token', () async {
    int rotations = 0;
    final api =
        Api(
            client: MockClient((r) async {
              if (r.url.path.endsWith('/auth/refresh')) {
                rotations++;
                return response({
                  'accessToken': 'new',
                  'refreshToken': 'r-new',
                });
              }
              if (r.headers['Authorization'] == 'Bearer old') {
                if (r.url.path.endsWith('/attendance')) {
                  await Future<void>.delayed(const Duration(milliseconds: 30));
                }
                return response({'message': 'expired'}, 401);
              }
              return response([]);
            }),
          )
          ..accessToken = 'old'
          ..refreshToken = 'r-old';
    await Future.wait([
      api.request('GET', '/shifts'),
      api.request('GET', '/attendance'),
    ]);
    expect(rotations, 1);
  });
  test('Ambiguous POST timeout never resends mutation', () async {
    int calls = 0;
    final api = Api(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((r) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return response({});
      }),
    );
    await expectLater(
      api.request('POST', '/attendance/check-in', {'shiftId': shiftId}),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
  test('Ambiguous refresh timeout clears consumed token and session', () async {
    bool cleared = false;
    final api =
        Api(
            timeout: const Duration(milliseconds: 10),
            client: MockClient((r) async {
              if (r.url.path.endsWith('/auth/refresh')) {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return response({'accessToken': 'new', 'refreshToken': 'next'});
              }
              return response({'message': 'expired'}, 401);
            }),
          )
          ..accessToken = 'old'
          ..refreshToken = 'r-old'
          ..onSessionExpired = () async {
            cleared = true;
          };
    await expectLater(api.request('GET', '/me'), throwsA(isA<ApiException>()));
    expect(api.refreshToken, isNull);
    expect(cleared, isTrue);
  });
  test('Unversioned or malformed success cannot masquerade as data', () async {
    final api = Api(
      client: MockClient((r) async => http.Response('{"status":"ok"}', 200)),
    );
    await expectLater(
      api.request('GET', '/health'),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'QR accepts assigned shift only; rejects foreign, malformed, wrong version',
    () {
      expect(
        decodeShiftQr(encodeShiftQr(shiftId), [
          {'id': shiftId},
        ]),
        shiftId,
      );
      for (final raw in [
        encodeShiftQr('foreign'),
        'not-json',
        '{"app":"NguyenHoangVu","version":2,"shiftId":"$shiftId"}',
      ]) {
        expect(
          () => decodeShiftQr(raw, [
            {'id': shiftId},
          ]),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
  test('Face image rejects wrong formats and images exceeding 2 MiB', () {
    expect(faceImageBase64([255, 216, 255, 1]), '/9j/AQ==');
    expect(() => faceImageBase64([1, 2, 3]), throwsA(isA<ApiException>()));
    expect(
      () => faceImageBase64(List.filled(2 * 1024 * 1024 + 1, 0)),
      throwsA(isA<ApiException>()),
    );
  });
  test('Map URL carries coordinates only and rejects invalid server data', () {
    final uri = locationMapUri({'latitude': 10.8, 'longitude': 106.7});
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters, {'api': '1', 'query': '10.8,106.7'});
    for (final row in <Json>[
      {'latitude': 91, 'longitude': 106},
      {'latitude': 10, 'longitude': double.nan},
      {'latitude': '10.8', 'longitude': 106},
      {},
    ]) {
      expect(() => locationMapUri(row), throwsA(isA<ApiException>()));
    }
  });
  test('Rhythm handles overnight shifts, overlap and missing checkout', () {
    expect(
      rhythmSummary([
        {
          'startsAt': '2026-10-29T22:00:00+07:00',
          'endsAt': '2026-10-30T07:00:00+07:00',
          'timing': {'state': 'missing_check_out'},
        },
        {
          'startsAt': '2026-10-30T13:00:00+07:00',
          'endsAt': '2026-10-31T00:00:00+07:00',
        },
      ]),
      {'shortRests': 1, 'longShifts': 1, 'missing': 1},
    );
  });
  test('CSV quotes fields and neutralizes spreadsheet formulas', () {
    final csv = reportCsv({
      'rows': [
        {'employeeName': '=HYPERLINK("bad")', 'title': 'Ca, đêm', 'timing': {}},
      ],
    });
    expect(csv, contains("\"'=HYPERLINK(\"\"bad\"\")\""));
    expect(csv, contains('"Ca, đêm"'));
  });
  test('Live workspace calls only supported versioned resources', () async {
    final backend = SharedBackend();
    final data = LiveData(backend.api, backend.user);
    await data.load();
    expect(data.ownShifts.single['id'], shiftId);
    expect(
      backend.calls.map((c) => c['path']),
      containsAll([
        '/dashboard',
        '/shifts',
        '/corrections',
        '/face/status',
        '/reports/monthly',
      ]),
    );
    expect(
      backend.calls.last['query']['month'],
      matches(RegExp(r'^\d{4}-\d{2}$')),
    );
  });
}
