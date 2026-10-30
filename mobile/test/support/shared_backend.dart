import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyen_hoang_vu/core/api.dart';

const userId = 'b8f6a384-aacb-4d84-b12d-231a317bf431';
const branchId = '00921473-2b23-4f45-84ba-840319d7a341';
const shiftId = '63bf08ee-8358-45a0-b28d-75ef02d179ac';

class SharedBackend {
  final String role, status;
  final bool quickFaceLogin;
  SharedBackend({
    this.role = 'employee',
    this.status = 'active',
    this.quickFaceLogin = true,
  });
  final calls = <Json>[];
  Json profile = {};
  Json get user => {
    'id': userId,
    'fullName': 'Nguyễn Hoàng Vũ',
    'username': 'hoangvu',
    'email': 'test@example.org',
    'role': role,
    'status': status,
    'branchId': branchId,
    'emailVerified': true,
    ...profile,
  };
  List<Json> employees = [];
  late List<Json> shifts = [
    {
      'id': shiftId,
      'title': 'Ca sáng',
      'branchId': branchId,
      'branchName': 'Văn phòng',
      'employeeId': userId,
      'employeeName': 'Nguyễn Hoàng Vũ',
      'startsAt': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
      'endsAt': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 8))
          .toIso8601String(),
      'status': 'scheduled',
      'planLocked': false,
    },
  ];
  List<Json> branches = [
    {
      'id': branchId,
      'name': 'Văn phòng',
      'address': '12 Đường số 1',
      'latitude': 10.8,
      'longitude': 106.7,
      'radiusMeters': 100,
    },
  ];
  Json get report => {
    'month': '2026-10',
    'timeZone': 'Asia/Ho_Chi_Minh',
    'rows': [
      for (final s in shifts)
        {
          ...s,
          'workDate': '2026-10-29',
          'timing': {'state': 'not_checked_in'},
        },
    ],
    'totals': {
      'shiftCount': shifts.length,
      'completedCount': 0,
      'lateCount': 0,
    },
  };
  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/v1', '');
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : Json.from(jsonDecode(request.body));
    calls.add({
      'method': request.method,
      'path': path,
      'body': body,
      'query': request.url.queryParameters,
    });
    dynamic result;
    if (path == '/health') {
      result = {
        'status': 'ok',
        if (quickFaceLogin) 'features': {'quickFaceLogin': true},
      };
    } else if (path == '/auth/login' ||
        path == '/auth/register' ||
        path == '/auth/resend-otp') {
      result = {
        'challengeId': 'challenge-1',
        'maskedEmail': 't***@example.org',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'retryAfterSeconds': 60,
      };
    } else if (path == '/auth/verify-otp') {
      result = {
        'accessToken': 'test-access',
        'refreshToken': 'test-refresh',
        'user': user,
      };
    } else if (path == '/auth/logout') {
      result = {'loggedOut': true};
    } else if (path == '/me') {
      if (request.method == 'PATCH') profile.addAll(body);
      result = user;
    } else if (path == '/dashboard') {
      result = {
        'employeeCount': 1,
        'pendingEmployeeCount': 0,
        'shiftCount': 1,
        'checkedInCount': 0,
        'shifts': shifts,
        'attendance': [],
      };
    } else if (path == '/face/status') {
      result = {
        'enrolled': false,
        'enrolledAt': null,
        if (quickFaceLogin) 'canEnrollQuickLogin': true,
      };
    } else if (path == '/reports/monthly') {
      result = report;
    } else if (path == '/employees') {
      if (request.method == 'POST') {
        employees.add({...body, 'id': 'new-employee', 'emailVerified': false});
      }
      result = employees.isEmpty ? [user] : [user, ...employees];
    } else if (path == '/branches') {
      result = branches;
    } else if (path == '/shifts') {
      result = shifts;
    } else if ([
      '/attendance',
      '/corrections',
      '/location-shares',
    ].contains(path)) {
      result = [];
    } else {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Unexpected test request $path',
          },
        }),
        404,
      );
    }
    return http.Response(
      jsonEncode({'data': result}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  Api get api => Api(endpoint: 'https://fixture.example/v1', client: client);
}
