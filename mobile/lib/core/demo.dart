import 'dart:math';
import 'api.dart';

class DemoStore {
  int roleIndex = 0;
  final Map<int, String> _passwords = {
    for (var i = 1; i <= 5; i++) i: 'Vu@2026Demo!',
  };
  final List<Json> users = [
    {
      'id': 1,
      'name': 'Nguyễn Hoàng Vũ',
      'email': 'vu@demo.vn',
      'role': 'employee',
      'department': 'Thiết kế sản phẩm',
      'title': 'Product Designer',
      'phone': '+84901234567',
      'active': true,
      'verified': true,
    },
    {
      'id': 2,
      'name': 'Trần Minh Anh',
      'email': 'admin@demo.vn',
      'role': 'admin',
      'department': 'Nhân sự',
      'title': 'HR Manager',
      'phone': '',
      'active': true,
      'verified': true,
    },
    {
      'id': 3,
      'name': 'Lê Bảo Ngọc',
      'email': 'khach@demo.vn',
      'role': 'customer',
      'department': 'Đối tác',
      'title': 'Khách hàng',
      'phone': '',
      'active': true,
      'verified': true,
    },
    {
      'id': 4,
      'name': 'Phạm Gia Huy',
      'email': 'huy@demo.vn',
      'role': 'employee',
      'department': 'Kỹ thuật',
      'title': 'Mobile Developer',
      'phone': '',
      'active': true,
      'verified': true,
    },
    {
      'id': 5,
      'name': 'Đặng Thảo Linh',
      'email': 'linh@demo.vn',
      'role': 'employee',
      'department': 'Marketing',
      'title': 'Content Strategist',
      'phone': '',
      'active': true,
      'verified': true,
    },
  ];
  late final Map<String, List<Json>> tables = {
    'branches': [
      {
        'id': 1,
        'name': 'The Workroom · Sài Gòn',
        'address': '72 Lê Thánh Tôn, Quận 1, TP. HCM',
        'latitude': 10.7769,
        'longitude': 106.7009,
        'radius': 200,
      },
    ],
    'shifts': [
      {
        'id': 1,
        'name': 'Ca hành chính',
        'start': '08:30',
        'end': '17:30',
        'branch_id': 1,
        'break_minutes': 60,
      },
      {
        'id': 2,
        'name': 'Ca linh hoạt',
        'start': '09:00',
        'end': '18:00',
        'branch_id': 1,
        'break_minutes': 60,
      },
    ],
    'assignments': List.generate(
      7,
      (i) => {
        'id': i + 1,
        'user_id': 1,
        'shift_id': 1,
        'work_date': date(DateTime.now().add(Duration(days: i))),
      },
    ),
    'attendance': List.generate(9, (i) {
      final day = DateTime.now().subtract(Duration(days: i + 1));
      return {
        'id': i + 1,
        'user_id': 1,
        'shift_id': 1,
        'work_date': date(day),
        'check_in': DateTime(
          day.year,
          day.month,
          day.day,
          8,
          i == 3 ? 42 : 25,
        ).toIso8601String(),
        'check_out': DateTime(
          day.year,
          day.month,
          day.day,
          17,
          32,
        ).toIso8601String(),
        'late_minutes': i == 3 ? 12 : 0,
        'distance': 34,
        'method': 'gps_qr',
      };
    }),
    'leaves': [
      {
        'id': 1,
        'user_id': 1,
        'kind': 'Nghỉ phép',
        'start_date': date(DateTime.now().add(const Duration(days: 5))),
        'end_date': date(DateTime.now().add(const Duration(days: 5))),
        'reason': 'Đưa gia đình đi khám sức khỏe định kỳ.',
        'status': 'pending',
      },
      {
        'id': 2,
        'user_id': 4,
        'kind': 'Việc cá nhân',
        'start_date': date(DateTime.now().add(const Duration(days: 2))),
        'end_date': date(DateTime.now().add(const Duration(days: 2))),
        'reason': 'Giải quyết công việc gia đình.',
        'status': 'pending',
      },
    ],
    'locations': [],
    'audit': [
      {
        'id': 1,
        'actor_id': 2,
        'action': 'assignment.create',
        'detail': 'Phân ca tuần mới',
        'created_at': DateTime.now().toIso8601String(),
      },
    ],
  };
  Json get user => users[roleIndex];
  String date(DateTime value) => value.toIso8601String().substring(0, 10);

  Future<dynamic> request(String method, String path, Json? body) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    body ??= {};
    final parts = path.split('/').where((e) => e.isNotEmpty).toList();
    final table = parts.first;
    if (path == '/me') return Map<String, dynamic>.from(user);
    if (table == 'auth') {
      if (path == '/auth/logout') return {'ok': true};
      if (path.endsWith('login') || path.endsWith('register')) {
        final email = body['email'].toString().toLowerCase();
        final index = users.indexWhere((e) => e['email'] == email);
        if (path.endsWith('register')) {
          if (index >= 0) {
            throw ApiException('Email đã được đăng ký trong bản demo');
          }
          final id = users.fold<int>(0, (v, e) => max(v, e['id'] as int)) + 1;
          users.add({
            'id': id,
            'name': body['name'],
            'email': email,
            'phone': body['phone'] ?? '',
            'role': 'customer',
            'department': 'Đối tác',
            'title': 'Khách hàng',
            'active': true,
            'verified': true,
          });
          _passwords[id] = body['password'];
          roleIndex = users.length - 1;
        } else if (index >= 0 &&
            users[index]['active'] == true &&
            _passwords[users[index]['id']] == body['password']) {
          roleIndex = index;
        } else {
          throw ApiException(
            'Email hoặc mật khẩu không đúng. Tài khoản mẫu: vu@demo.vn / Vu@2026Demo!',
          );
        }
        return {
          'challenge_id': 'demo',
          'destination': email,
          'expires_in': 300,
        };
      }
      return {
        'user': Map<String, dynamic>.from(user),
        'access_token': 'demo',
        'refresh_token': 'demo-refresh-token-only',
      };
    }
    if (table == 'insights') {
      return {
        'week_minutes': 1532,
        'overtime_minutes': 32,
        'load_percent': 64,
        'suggestions': [
          'Bạn đang giữ nhịp làm việc cân bằng. Hãy nghỉ ngắn sau mỗi 90 phút để nạp lại năng lượng.',
        ],
        'disclaimer':
            'Gợi ý theo giờ công; không phải đánh giá y tế hay năng suất.',
      };
    }
    if (table == 'qr') {
      return {'qr_token': 'DEMO-QR-NOT-VALID-ON-SERVER', 'expires_in': 45};
    }
    if (path == '/locations/share') {
      tables['locations']!.removeWhere((e) => e['user_id'] == user['id']);
      if (method == 'POST') {
        tables['locations']!.add({
          'id': 1,
          'user_id': user['id'],
          ...body,
          'expires': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        });
      }
      return {'ok': true};
    }
    if (path == '/attendance/check-in' || path == '/attendance/check-out') {
      final today = date(DateTime.now());
      final list = tables['attendance']!;
      final existing = list
          .where((e) => e['user_id'] == user['id'] && e['work_date'] == today)
          .firstOrNull;
      if (path.endsWith('check-in')) {
        if (existing != null) throw ApiException('Bạn đã vào ca hôm nay');
        final value = {
          'id': 1000,
          'user_id': user['id'],
          'shift_id': 1,
          'work_date': today,
          'check_in': DateTime.now().toIso8601String(),
          'check_out': null,
          'late_minutes': 0,
          'method': 'gps_qr',
        };
        list.insert(0, value);
        return value;
      }
      if (existing == null || existing['check_out'] != null) {
        throw ApiException('Chưa vào ca hoặc đã kết thúc ca');
      }
      existing['check_out'] = DateTime.now().toIso8601String();
      return existing;
    }
    final list = table == 'employees' ? users : tables[table];
    if (list == null) throw ApiException('Bản demo không hỗ trợ thao tác này');
    if (method == 'GET') {
      if (user['role'] != 'admin' &&
          ['attendance', 'leaves', 'assignments'].contains(table)) {
        return list
            .where((e) => e['user_id'] == user['id'])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (parts.last == 'decision') {
      final item = list.firstWhere((e) => e['id'] == id);
      if (item['user_id'] == user['id']) {
        throw ApiException('Không thể tự duyệt đơn của mình');
      }
      item['status'] = body['status'];
      return item;
    }
    if (method == 'POST') {
      final item = {
        'id': list.fold<int>(0, (v, e) => max(v, e['id'] as int)) + 1,
        ...body,
      };
      if (table == 'leaves') {
        item.addAll({'user_id': user['id'], 'status': 'pending'});
      }
      if (table == 'employees') {
        _passwords[item['id'] as int] = item.remove('password');
        item.addAll({'active': true, 'verified': true});
      }
      list.add(item);
      return item;
    }
    final item = list.firstWhere((e) => e['id'] == id);
    if (table == 'leaves' && item['status'] != 'pending') {
      throw ApiException('Đơn đã được xử lý');
    }
    if (method == 'PUT') {
      item.addAll(body);
      return item;
    }
    if (table == 'employees') {
      item['active'] = false;
    } else {
      list.remove(item);
    }
    return {'ok': true};
  }
}
