import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api.dart';
import '../core/live.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/editor.dart';
import 'attendance_flow.dart' show currentPosition;
import 'live_manage.dart' show showShiftQr;

class LiveShifts extends StatefulWidget {
  final LiveData data;
  final Future<void> Function(Future<void> Function()) act;
  const LiveShifts({super.key, required this.data, required this.act});
  @override
  State<LiveShifts> createState() => _LiveShiftsState();
}

class _LiveShiftsState extends State<LiveShifts> {
  String? selected;
  Future<void> scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ShiftScanner()),
    );
    if (raw == null || !mounted) return;
    try {
      setState(() => selected = decodeShiftQr(raw, widget.data.ownShifts));
    } catch (e) {
      toast(context, e);
    }
  }

  Future<void> punch(Json shift, bool checkout) => widget.act(() async {
    if (!await confirm(
      context,
      checkout ? 'Xác nhận ra ca?' : 'Xác nhận vào ca?',
      '${shift['title']}\nỨng dụng lấy GPS mới và gửi tới máy chủ. Giờ chấm công do máy chủ ghi nhận.',
    )) {
      return;
    }
    final position = await currentPosition();
    await widget.data.api
        .request('POST', '/attendance/${checkout ? 'check-out' : 'check-in'}', {
          'shiftId': shift['id'],
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
        });
    if (mounted) {
      toast(
        context,
        checkout ? 'Đã ghi nhận giờ ra ca.' : 'Đã ghi nhận giờ vào ca.',
      );
    }
  });
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final shifts = d.ownShifts;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          eyebrow: 'CA CỦA BẠN',
          title: 'Đúng ca. Đúng nơi.',
          subtitle: 'Quét QR chọn ca hoặc chọn trực tiếp. GPS xác nhận vị trí.',
        ),
        OutlinedButton.icon(
          onPressed: scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Quét QR chọn ca'),
        ),
        const SizedBox(height: 20),
        if (shifts.isEmpty)
          const EmptyState(
            'Chưa được phân ca',
            'Liên hệ admin hoặc quản lý chi nhánh để xếp ca.',
          ),
        for (final s in shifts)
          Builder(
            builder: (context) {
              final record = d.recordFor(s['id']);
              final window = s['timeWindow'] as Map?;
              final opens = DateTime.tryParse(window?['checkInOpensAt'] ?? '');
              final closes = DateTime.tryParse(
                window?['checkInClosesAt'] ?? s['endsAt'] ?? '',
              );
              final outCloses = DateTime.tryParse(
                window?['checkOutClosesAt'] ?? '',
              );
              final checkout = record?['checkInAt'] != null;
              final complete = record?['checkOutAt'] != null;
              final inWindow = checkout
                  ? outCloses == null || !now.isAfter(outCloses)
                  : (opens == null || !now.isBefore(opens)) &&
                        (closes == null || !now.isAfter(closes));
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Panel(
                  color: selected == s['id'] ? mint : Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${s['title']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'QR của ca',
                            onPressed: () => showShiftQr(context, s),
                            icon: const Icon(Icons.qr_code_2),
                          ),
                        ],
                      ),
                      Text(
                        '${s['branchName'] ?? ''}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${dateTimeText(s['startsAt'])}\n${dateTimeText(s['endsAt'])}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Tag(
                            stateText(
                              record?['timing']?['state'] ?? s['status'],
                            ),
                          ),
                          if (selected == s['id']) const Tag('Đã chọn bằng QR'),
                          if (record?['timing']?['late'] == true)
                            const Tag('Đi muộn', color: Colors.deepOrange),
                        ],
                      ),
                      if (record != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Vào: ${dateTimeText(record['checkInAt'])}\nRa: ${dateTimeText(record['checkOutAt'])}\nGiờ thiết bị gốc: ${clockText(record['recordedCheckInAt'])} – ${clockText(record['recordedCheckOutAt'])}',
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (!complete)
                        FilledButton.icon(
                          onPressed: inWindow ? () => punch(s, checkout) : null,
                          icon: Icon(checkout ? Icons.logout : Icons.login),
                          label: Text(
                            checkout ? 'Ra ca với GPS' : 'Vào ca với GPS',
                          ),
                        ),
                      if (!complete && !inWindow)
                        const Text(
                          'Ngoài cửa sổ chấm công. Nếu thiếu giờ, tạo đơn điều chỉnh.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class ShiftScanner extends StatefulWidget {
  const ShiftScanner({super.key});
  @override
  State<ShiftScanner> createState() => _ShiftScannerState();
}

class _ShiftScannerState extends State<ShiftScanner> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool returned = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quét QR chọn ca')),
    body: Column(
      children: [
        Expanded(
          child: kIsWeb
              ? const Center(
                  child: Text('Quét QR trên APK Android hoặc bản iOS.'),
                )
              : MobileScanner(
                  controller: controller,
                  errorBuilder: (context, error) => const Center(
                    child: Text(
                      'Không mở được camera. Kiểm tra quyền camera trong cài đặt.',
                    ),
                  ),
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue;
                      if (!returned && raw != null) {
                        returned = true;
                        Navigator.pop(context, raw);
                        break;
                      }
                    }
                  },
                ),
        ),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Quét QR NguyenHoangVu của ca được phân. QR chọn ca; GPS và máy chủ xác nhận chấm công.',
          ),
        ),
      ],
    ),
  );
}

Future<bool> editCorrection(
  BuildContext context,
  LiveData d, [
  Json? row,
]) => showEditor(
  context,
  title: row == null ? 'Tạo đơn điều chỉnh công' : 'Sửa đơn chờ duyệt',
  initial: row ?? {},
  fields: [
    if (row == null)
      FormFieldSpec(
        'shiftId',
        'Ca cần điều chỉnh',
        options: {for (final s in d.ownShifts) s['id']: shiftLabel(s)},
      ),
    const FormFieldSpec(
      'requestedCheckIn',
      'Ngày giờ vào đề nghị (giờ thiết bị)',
      type: 'datetime',
      required: false,
    ),
    const FormFieldSpec(
      'requestedCheckOut',
      'Ngày giờ ra đề nghị (giờ thiết bị)',
      type: 'datetime',
      required: false,
    ),
    const FormFieldSpec('reason', 'Lý do (ít nhất 5 ký tự)', type: 'multiline'),
  ],
  save: (body) async {
    if (body['reason'].toString().length < 5) {
      throw ApiException('Lý do cần ít nhất 5 ký tự.');
    }
    if (body['requestedCheckIn'] == null && body['requestedCheckOut'] == null) {
      throw ApiException('Chọn ít nhất giờ vào hoặc giờ ra.');
    }
    if (body['requestedCheckIn'] != null &&
        body['requestedCheckOut'] != null &&
        DateTime.parse(
          body['requestedCheckOut'],
        ).isBefore(DateTime.parse(body['requestedCheckIn']))) {
      throw ApiException('Giờ ra không được trước giờ vào.');
    }
    await d.api.request(
      row == null ? 'POST' : 'PATCH',
      '/corrections${row == null ? '' : '/${row['id']}'}',
      body,
    );
  },
);

class LiveCorrections extends StatelessWidget {
  final LiveData data;
  final Future<void> Function(Future<void> Function()) act;
  const LiveCorrections({super.key, required this.data, required this.act});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageTitle(
        eyebrow: 'ĐỐI SOÁT',
        title: 'Minh bạch từng giờ.',
        subtitle: 'Đề nghị sửa giờ thiếu; giữ lại bằng chứng thiết bị gốc.',
      ),
      FilledButton.icon(
        onPressed: () => act(() async {
          await editCorrection(context, data);
        }),
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn điều chỉnh'),
      ),
      const SizedBox(height: 20),
      if (data.corrections.isEmpty)
        const EmptyState(
          'Chưa có đơn điều chỉnh',
          'Khi thiếu giờ vào hoặc ra, chọn ca và gửi lý do.',
        ),
      for (final r in data.corrections.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(stateText(r['status'])),
                const SizedBox(height: 10),
                Text(
                  '${r['reason']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Nhân viên: ${data.employees.where((e) => e['id'] == r['employeeId']).map((e) => e['fullName']).firstOrNull ?? r['employeeId']}',
                ),
                Text(
                  'Vào đề nghị: ${dateTimeText(r['requestedCheckIn'])}\nRa đề nghị: ${dateTimeText(r['requestedCheckOut'])}',
                ),
                if (r['resolutionNote'] != null)
                  Text('Phản hồi: ${r['resolutionNote']}'),
                if (r['resolvedAt'] != null)
                  Text('Duyệt lúc: ${dateTimeText(r['resolvedAt'])}'),
                if (r['afterAttendance'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Sau đối soát: ${dateTimeText(r['afterAttendance']['checkInAt'])} – ${dateTimeText(r['afterAttendance']['checkOutAt'])}',
                    ),
                  ),
                if (r['status'] == 'pending')
                  Wrap(
                    children: [
                      if (r['employeeId'] == data.user['id']) ...[
                        TextButton(
                          onPressed: () => act(() async {
                            await editCorrection(context, data, r);
                          }),
                          child: const Text('Sửa đơn'),
                        ),
                        TextButton(
                          onPressed: () => act(() async {
                            if (await confirm(
                              context,
                              'Rút đơn?',
                              'Đơn đang chờ duyệt sẽ bị xóa.',
                            )) {
                              await data.api.request(
                                'DELETE',
                                '/corrections/${r['id']}',
                              );
                            }
                          }),
                          child: const Text('Rút đơn'),
                        ),
                      ] else if (data.manages) ...[
                        for (final approved in [true, false])
                          TextButton(
                            onPressed: () => act(() async {
                              await showEditor(
                                context,
                                title: approved
                                    ? 'Duyệt điều chỉnh'
                                    : 'Từ chối điều chỉnh',
                                fields: const [
                                  FormFieldSpec(
                                    'resolutionNote',
                                    'Ghi chú phản hồi',
                                    type: 'multiline',
                                    required: false,
                                  ),
                                ],
                                save: (body) async {
                                  await data.api.request(
                                    'PATCH',
                                    '/corrections/${r['id']}',
                                    {
                                      'status': approved
                                          ? 'approved'
                                          : 'rejected',
                                      ...body,
                                    },
                                  );
                                },
                              );
                            }),
                            child: Text(approved ? 'Duyệt' : 'Từ chối'),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
