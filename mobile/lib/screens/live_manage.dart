import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/api.dart';
import '../core/live.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/editor.dart';

Future<bool> editEmployee(BuildContext context, LiveData d, [Json? row]) =>
    showEditor(
      context,
      title: row == null ? 'Thêm nhân viên' : 'Sửa / duyệt nhân viên',
      initial: row ?? {'role': 'employee', 'status': 'pending'},
      fields: [
        const FormFieldSpec('fullName', 'Họ và tên'),
        const FormFieldSpec('username', 'Tên đăng nhập'),
        const FormFieldSpec('email', 'Email', type: 'email'),
        FormFieldSpec(
          'password',
          row == null ? 'Mật khẩu' : 'Mật khẩu mới (bỏ trống để giữ)',
          type: 'password',
          required: row == null,
        ),
        const FormFieldSpec(
          'role',
          'Vai trò',
          options: {
            'employee': 'Nhân viên',
            'manager': 'Quản lý chi nhánh',
            'admin': 'Quản trị viên',
          },
        ),
        const FormFieldSpec(
          'status',
          'Trạng thái',
          options: {
            'pending': 'Chờ duyệt',
            'active': 'Đang hoạt động',
            'suspended': 'Tạm khóa',
          },
        ),
        FormFieldSpec(
          'branchId',
          'Chi nhánh',
          required: false,
          options: {for (final b in d.branches) b['id']: b['name']},
        ),
      ],
      save: (body) async {
        if (!RegExp(r'^[a-z0-9][a-z0-9_.]{2,31}$').hasMatch(body['username'])) {
          throw ApiException(
            'Tên đăng nhập cần 3–32 ký tự thường, số, _ hoặc .',
          );
        }
        if (row != null) body.removeWhere((k, v) => v == row[k]);
        if (body.isEmpty) return;
        await d.api.request(
          row == null ? 'POST' : 'PATCH',
          '/employees${row == null ? '' : '/${row['id']}'}',
          body,
        );
      },
    );

Future<bool> editBranch(
  BuildContext context,
  LiveData d, [
  Json? row,
]) => showEditor(
  context,
  title: row == null ? 'Thêm chi nhánh' : 'Sửa chi nhánh',
  initial: {...?row, ...?row?['timePolicy']},
  fields: const [
    FormFieldSpec('name', 'Tên chi nhánh'),
    FormFieldSpec('address', 'Địa chỉ'),
    FormFieldSpec('latitude', 'Vĩ độ', type: 'double'),
    FormFieldSpec('longitude', 'Kinh độ', type: 'double'),
    FormFieldSpec('radiusMeters', 'Bán kính GPS (20–5000 mét)', type: 'int'),
    FormFieldSpec(
      'checkInEarlyMinutes',
      'Cho vào sớm (phút)',
      type: 'int',
      required: false,
    ),
    FormFieldSpec(
      'lateGraceMinutes',
      'Dung sai đi muộn (phút)',
      type: 'int',
      required: false,
    ),
    FormFieldSpec(
      'earlyLeaveGraceMinutes',
      'Dung sai về sớm (phút)',
      type: 'int',
      required: false,
    ),
    FormFieldSpec(
      'checkOutLateMinutes',
      'Cho ra trễ (phút)',
      type: 'int',
      required: false,
    ),
  ],
  save: (body) async {
    if ((body['latitude'] as num).abs() > 90 ||
        (body['longitude'] as num).abs() > 180 ||
        body['radiusMeters'] < 20 ||
        body['radiusMeters'] > 5000) {
      throw ApiException('Tọa độ hoặc bán kính chưa hợp lệ.');
    }
    const keys = [
      'checkInEarlyMinutes',
      'lateGraceMinutes',
      'earlyLeaveGraceMinutes',
      'checkOutLateMinutes',
    ];
    final policy = {
      for (final key in keys)
        if (body.containsKey(key)) key: body.remove(key),
    };
    if (policy.isNotEmpty) {
      if (policy.length != 4 || policy.values.any((v) => v < 0 || v > 1440)) {
        throw ApiException('Chính sách giờ cần đủ 4 số, mỗi số từ 0–1440.');
      }
      body['timePolicy'] = policy;
    }
    await d.api.request(
      row == null ? 'POST' : 'PATCH',
      '/branches${row == null ? '' : '/${row['id']}'}',
      body,
    );
  },
);

Future<bool> editShift(
  BuildContext context,
  LiveData d, [
  Json? row,
]) => showEditor(
  context,
  title: row?['planLocked'] == true
      ? 'Ca đã có lịch sử · chỉ sửa tên'
      : row == null
      ? 'Phân ca làm việc'
      : 'Sửa ca làm việc',
  initial: row ?? {},
  fields: [
    const FormFieldSpec('title', 'Tên ca'),
    if (row?['planLocked'] != true) ...[
      FormFieldSpec(
        'branchId',
        'Chi nhánh',
        options: {for (final b in d.branches) b['id']: b['name']},
      ),
      FormFieldSpec(
        'employeeId',
        'Nhân viên đã duyệt email',
        options: {
          for (final e in d.employees.where(
            (e) => e['status'] == 'active' && e['emailVerified'] == true,
          ))
            e['id']: '${e['fullName']} · ${e['username']}',
        },
      ),
      const FormFieldSpec(
        'startsAt',
        'Ngày giờ bắt đầu (giờ thiết bị)',
        type: 'datetime',
      ),
      const FormFieldSpec(
        'endsAt',
        'Ngày giờ kết thúc (giờ thiết bị)',
        type: 'datetime',
      ),
    ],
  ],
  save: (body) async {
    if (body.containsKey('startsAt')) {
      if (!DateTime.parse(
        body['endsAt'],
      ).isAfter(DateTime.parse(body['startsAt']))) {
        throw ApiException(
          'Giờ kết thúc phải sau giờ bắt đầu. Ca qua đêm chọn ngày kết thúc kế tiếp.',
        );
      }
      final employee = d.employees.firstWhere(
        (e) => e['id'] == body['employeeId'],
      );
      if (employee['branchId'] != body['branchId']) {
        throw ApiException('Nhân viên phải thuộc chi nhánh được chọn.');
      }
    }
    await d.api.request(
      row == null ? 'POST' : 'PATCH',
      '/shifts${row == null ? '' : '/${row['id']}'}',
      body,
    );
  },
);

Future<void> showShiftQr(BuildContext context, Json shift) => showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('QR chọn ca'),
    content: SizedBox(
      width: 280,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: encodeShiftQr(shift['id']), size: 240),
            Text(shiftLabel(shift)),
            const SizedBox(height: 12),
            const Text(
              'Nhân viên quét mã để chọn ca. Chấm công vẫn cần GPS và xác nhận máy chủ; QR không chứa OTP hay token.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  ),
);

class LiveManagement extends StatefulWidget {
  final LiveData data;
  final Future<void> Function(Future<void> Function()) act;
  const LiveManagement({super.key, required this.data, required this.act});
  @override
  State<LiveManagement> createState() => _LiveManagementState();
}

class _LiveManagementState extends State<LiveManagement> {
  int tab = 0;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final rows =
        (tab == 0
                ? d.employees
                : tab == 1
                ? d.branches
                : d.shifts)
            .where(
              (r) =>
                  '${r['fullName']} ${r['username']} ${r['name']} ${r['title']} ${r['employeeName']}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList();
    final editable = tab == 2 ? d.manages : d.admin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          eyebrow: 'ĐỘI NGŨ',
          title: 'Vận hành có nhịp.',
          subtitle: 'Duyệt nhân viên, thiết lập chi nhánh và phân ca.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Nhân viên', 'Chi nhánh', 'Ca làm'][i]),
                selected: tab == i,
                onSelected: (_) => setState(() {
                  tab = i;
                  query = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: ValueKey(tab),
          decoration: const InputDecoration(
            labelText: 'Tìm kiếm',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 14),
        if (editable)
          FilledButton.icon(
            onPressed: () => widget.act(() async {
              if (tab == 0) {
                await editEmployee(context, d);
              } else if (tab == 1) {
                await editBranch(context, d);
              } else {
                await editShift(context, d);
              }
            }),
            icon: const Icon(Icons.add),
            label: Text(['Thêm nhân viên', 'Thêm chi nhánh', 'Phân ca'][tab]),
          ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const EmptyState(
            'Chưa có dữ liệu',
            'Tạo mới hoặc đổi từ khóa tìm kiếm.',
          ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['fullName'] ?? r['name'] ?? r['title']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  if (tab == 0) ...[
                    Text(
                      '${r['username']} · ${r['email']}',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Tag(roleName(r['role'])),
                        Tag(stateText(r['status'])),
                        Tag(
                          r['emailVerified'] == true
                              ? 'Email đã xác thực'
                              : 'Chưa xác thực email',
                          color: r['emailVerified'] == true
                              ? forest
                              : Colors.deepOrange,
                        ),
                      ],
                    ),
                  ],
                  if (tab == 1)
                    Text(
                      '${r['address']}\nGPS: ${r['latitude']}, ${r['longitude']} · ${r['radiusMeters']} m',
                    ),
                  if (tab == 2) ...[
                    Text('${r['employeeName']} · ${r['branchName']}'),
                    Text(
                      '${dateTimeText(r['startsAt'])}\n${dateTimeText(r['endsAt'])}',
                    ),
                    const SizedBox(height: 6),
                    Tag(
                      r['planLocked'] == true
                          ? 'Đã khóa kế hoạch'
                          : stateText(r['status']),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (editable)
                        TextButton.icon(
                          onPressed: () => widget.act(() async {
                            if (tab == 0) {
                              await editEmployee(context, d, r);
                            } else if (tab == 1) {
                              await editBranch(context, d, r);
                            } else {
                              await editShift(context, d, r);
                            }
                          }),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(tab == 0 ? 'Sửa / duyệt' : 'Sửa'),
                        ),
                      if (tab == 2)
                        TextButton.icon(
                          onPressed: () => showShiftQr(context, r),
                          icon: const Icon(Icons.qr_code, size: 18),
                          label: const Text('Mở QR'),
                        ),
                      if (editable)
                        TextButton.icon(
                          onPressed: () => widget.act(() async {
                            if (!await confirm(
                              context,
                              tab == 0
                                  ? 'Ngừng hoạt động nhân viên?'
                                  : 'Xóa dữ liệu?',
                              tab == 0
                                  ? 'Tài khoản sẽ bị khóa; lịch sử chấm công được giữ lại.'
                                  : 'Máy chủ sẽ từ chối nếu dữ liệu đang được sử dụng.',
                            )) {
                              return;
                            }
                            await d.api.request(
                              'DELETE',
                              '/${['employees', 'branches', 'shifts'][tab]}/${r['id']}',
                            );
                          }),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(tab == 0 ? 'Ngừng hoạt động' : 'Xóa'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Danh sách API trả tối đa 500 bản ghi mỗi loại.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}
