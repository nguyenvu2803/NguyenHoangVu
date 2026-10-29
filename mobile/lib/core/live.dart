import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'api.dart';

List<Json> objects(dynamic value) =>
    (value as List).map((e) => Json.from(e)).toList();
String dateTimeText(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '');
  return time == null
      ? '—'
      : DateFormat('dd/MM/yyyy · HH:mm', 'vi_VN').format(time.toLocal());
}

String clockText(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '');
  return time == null ? '—' : DateFormat('HH:mm').format(time.toLocal());
}

String stateText(dynamic state) => switch (state) {
  'pending' => 'Chờ duyệt',
  'active' => 'Đang hoạt động',
  'suspended' => 'Tạm khóa',
  'approved' => 'Đã duyệt',
  'rejected' => 'Từ chối',
  'scheduled' => 'Đã xếp ca',
  'in_progress' => 'Đang làm',
  'completed' => 'Hoàn tất',
  'upcoming' => 'Sắp tới',
  'not_checked_in' => 'Chưa vào ca',
  'missing_check_in' => 'Thiếu giờ vào',
  'missing_check_out' => 'Thiếu giờ ra',
  _ => state?.toString() ?? '—',
};
String shiftLabel(Json s) =>
    '${s['title']} · ${dateTimeText(s['startsAt'])} · ${s['employeeName'] ?? ''}';

Uri locationMapUri(Json share) {
  final latitude = share['latitude'], longitude = share['longitude'];
  if (latitude is! num ||
      longitude is! num ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    throw ApiException('Tọa độ chia sẻ không hợp lệ.');
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
}

String encodeShiftQr(String shiftId) =>
    jsonEncode({'app': 'NguyenHoangVu', 'version': 1, 'shiftId': shiftId});
String decodeShiftQr(String raw, List<Json> ownShifts) {
  dynamic data;
  try {
    data = jsonDecode(raw);
  } catch (_) {
    throw ApiException('QR không đúng định dạng ca NguyenHoangVu.');
  }
  if (data is! Map ||
      data['app'] != 'NguyenHoangVu' ||
      data['version'] != 1 ||
      !ownShifts.any((s) => s['id'] == data['shiftId'])) {
    throw ApiException('QR không thuộc ca được phân cho bạn.');
  }
  return data['shiftId'] as String;
}

String faceImageBase64(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
    throw ApiException('Ảnh phải nhỏ hơn hoặc bằng 2 MiB.');
  }
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final png =
      bytes.length >= 8 &&
      bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
  if (!jpeg && !png) throw ApiException('Chỉ nhận ảnh JPEG hoặc PNG.');
  return base64Encode(bytes);
}

Future<String?> captureFace() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  return image == null ? null : faceImageBase64(await image.readAsBytes());
}

class LiveData {
  final Api api;
  Json user;
  LiveData(this.api, this.user);
  Json dashboard = {}, report = {}, face = {};
  List<Json> shifts = [],
      attendance = [],
      corrections = [],
      employees = [],
      branches = [],
      locations = [];
  String month = DateFormat('yyyy-MM').format(DateTime.now());
  bool get manages => user['role'] == 'admin' || user['role'] == 'manager';
  bool get admin => user['role'] == 'admin';
  List<Json> get ownShifts =>
      shifts.where((s) => s['employeeId'] == user['id']).toList();
  Future<void> load() async {
    final values = await Future.wait([
      api.request('GET', '/dashboard'),
      api.request('GET', '/shifts'),
      api.request('GET', '/attendance'),
      api.request('GET', '/corrections'),
      api.request('GET', '/employees'),
      api.request('GET', '/branches'),
      api.request('GET', '/location-shares'),
      api.request('GET', '/face/status'),
      api.request('GET', '/reports/monthly?month=$month'),
    ]);
    dashboard = Json.from(values[0]);
    shifts = objects(values[1]);
    attendance = objects(values[2]);
    corrections = objects(values[3]);
    employees = objects(values[4]);
    branches = objects(values[5]);
    locations = objects(values[6]);
    face = Json.from(values[7]);
    report = Json.from(values[8]);
    shifts.sort(
      (a, b) => a['startsAt'].toString().compareTo(b['startsAt'].toString()),
    );
  }

  Json? recordFor(String shiftId) {
    for (final row in attendance) {
      if (row['shiftId'] == shiftId) return row;
    }
    return null;
  }
}

String reportCsv(Json report) {
  String cell(dynamic value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = <List<dynamic>>[
    [
      'Nhân viên',
      'Ca',
      'Ngày',
      'Vào',
      'Ra',
      'Phút sau điều chỉnh',
      'Phút thiết bị gốc',
      'Trạng thái',
    ],
    for (final row in objects(report['rows'] ?? []))
      [
        row['employeeName'],
        row['title'],
        row['workDate'],
        row['checkInAt'],
        row['checkOutAt'],
        row['timing']?['rawSpanMinutes'],
        row['timing']?['recordedSpanMinutes'],
        stateText(row['timing']?['state']),
      ],
  ];
  return '\uFEFF${lines.map((line) => line.map(cell).join(',')).join('\r\n')}';
}

Json rhythmSummary(List<Json> rows) {
  final sorted = [...rows]
    ..sort(
      (a, b) => a['startsAt'].toString().compareTo(b['startsAt'].toString()),
    );
  int shortRests = 0, longShifts = 0, missing = 0;
  DateTime? latestEnd;
  for (final row in sorted) {
    final start = DateTime.tryParse(row['startsAt'] ?? '');
    final end = DateTime.tryParse(row['endsAt'] ?? '');
    if (start != null && end != null) {
      if (end.difference(start).inMinutes > 600) longShifts++;
      if (latestEnd != null && start.difference(latestEnd).inMinutes < 660) {
        shortRests++;
      }
      if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
    }
    if ([
      'missing_check_in',
      'missing_check_out',
    ].contains(row['timing']?['state'])) {
      missing++;
    }
  }
  return {
    'shortRests': shortRests,
    'longShifts': longShifts,
    'missing': missing,
  };
}
