import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/common.dart';
import '../widgets/editor.dart';
import 'records.dart';

class ManagePage extends StatefulWidget {
  final Workspace data;
  const ManagePage({super.key, required this.data});
  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  String table = 'employees', query = '';
  final tabs = {
    'employees': 'Nhân viên',
    'branches': 'Chi nhánh',
    'shifts': 'Ca làm',
    'assignments': 'Phân ca',
    'locations': 'Vị trí',
    'audit': 'Nhật ký',
  };
  List<Json> get rows => switch (table) {
    'employees' => widget.data.employees,
    'branches' => widget.data.branches,
    'shifts' => widget.data.shifts,
    'assignments' => widget.data.assignments,
    'locations' => widget.data.locations,
    _ => widget.data.audits,
  };
  List<FormFieldSpec> fields(bool isNew) {
    final d = widget.data;
    return switch (table) {
      'employees' => [
        const FormFieldSpec('name', 'Họ tên'),
        if (isNew) ...[
          const FormFieldSpec('email', 'Email', type: 'email'),
          const FormFieldSpec('password', 'Mật khẩu ban đầu', type: 'password'),
        ],
        const FormFieldSpec('phone', 'Điện thoại (+84…)', required: false),
        const FormFieldSpec('department', 'Phòng ban'),
        const FormFieldSpec('title', 'Chức danh'),
        const FormFieldSpec(
          'role',
          'Vai trò',
          options: {
            'employee': 'Nhân viên',
            'customer': 'Khách hàng',
            'admin': 'Quản trị viên',
          },
        ),
      ],
      'branches' => const [
        FormFieldSpec('name', 'Tên chi nhánh'),
        FormFieldSpec('address', 'Địa chỉ'),
        FormFieldSpec('latitude', 'Vĩ độ', type: 'double'),
        FormFieldSpec('longitude', 'Kinh độ', type: 'double'),
        FormFieldSpec('radius', 'Bán kính chấm công (m)', type: 'int'),
      ],
      'shifts' => [
        const FormFieldSpec('name', 'Tên ca'),
        const FormFieldSpec('start', 'Giờ bắt đầu', type: 'time'),
        const FormFieldSpec('end', 'Giờ kết thúc', type: 'time'),
        FormFieldSpec(
          'branch_id',
          'Chi nhánh',
          type: 'selectInt',
          options: {for (final b in d.branches) '${b['id']}': b['name']},
        ),
        const FormFieldSpec(
          'break_minutes',
          'Nghỉ giữa ca (phút)',
          type: 'int',
        ),
      ],
      'assignments' => [
        FormFieldSpec(
          'user_id',
          'Nhân viên',
          type: 'selectInt',
          options: {
            for (final u in d.employees.where(
              (e) => e['active'] == true && e['role'] != 'customer',
            ))
              '${u['id']}': u['name'],
          },
        ),
        FormFieldSpec(
          'shift_id',
          'Ca làm việc',
          type: 'selectInt',
          options: {
            for (final s in d.shifts)
              '${s['id']}': '${s['name']} · ${s['start']} — ${s['end']}',
          },
        ),
        const FormFieldSpec('work_date', 'Ngày làm việc', type: 'date'),
      ],
      _ => [],
    };
  }

  Future<void> edit([Json? item]) async {
    final defaults = switch (table) {
      'employees' => {
        'role': 'employee',
        'department': 'Sản phẩm',
        'title': 'Nhân viên',
      },
      'branches' => {'radius': 200},
      'shifts' => {'start': '08:30', 'end': '17:30', 'break_minutes': 60},
      'assignments' => {'work_date': widget.data.today},
      _ => <String, dynamic>{},
    };
    final currentTable = table;
    final saved = await showEditor(
      context,
      title:
          '${item == null ? 'Thêm' : 'Cập nhật'} ${tabs[table]!.toLowerCase()}',
      fields: fields(item == null),
      initial: item ?? defaults,
      save: (values) async {
        await widget.data.api.request(
          item == null ? 'POST' : 'PUT',
          '/$currentTable${item == null ? '' : '/${item['id']}'}',
          values,
        );
      },
    );
    if (saved) await widget.data.reload();
  }

  Future<void> remove(Json item) async {
    final currentTable = table;
    final ok = await confirm(
      context,
      table == 'employees' ? 'Khóa tài khoản?' : 'Xóa bản ghi?',
      table == 'employees'
          ? 'Tài khoản bị khóa sẽ không đăng nhập được. Bảng công được giữ lại.'
          : 'Dữ liệu đang được tham chiếu hoặc đã chấm công sẽ không thể xóa.',
    );
    if (!ok) return;
    try {
      await widget.data.api.request('DELETE', '/$currentTable/${item['id']}');
      await widget.data.reload();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final editable = !['locations', 'audit'].contains(table);
    final records = rows
        .where((e) => e.toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'Dành cho quản trị viên',
          title: 'Đội ngũ & vận hành.',
          subtitle:
              'Quản lý nhân sự, nơi làm việc và lịch ca trong một không gian.',
          action: editable
              ? IconButton.filled(
                  tooltip: 'Thêm ${tabs[table]!.toLowerCase()}',
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add),
                )
              : null,
        ),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final tab in tabs.entries)
              ChoiceChip(
                label: Text(tab.value),
                selected: table == tab.key,
                onSelected: (_) => setState(() {
                  table = tab.key;
                  query = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: ValueKey(table),
                decoration: InputDecoration(
                  hintText: 'Tìm trong ${tabs[table]!.toLowerCase()}…',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 18),
              if (records.isEmpty)
                EmptyState(
                  'Chưa có ${tabs[table]!.toLowerCase()}',
                  table == 'locations'
                      ? 'Vị trí chỉ hiển thị khi nhân viên chủ động chia sẻ, tối đa 1 giờ.'
                      : 'Thêm dữ liệu mới để bắt đầu.',
                ),
              ...records.map((item) => _row(d, item, editable)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(Workspace d, Json item, bool editable) {
    final title = switch (table) {
      'employees' || 'branches' || 'shifts' => item['name'].toString(),
      'assignments' || 'locations' => d.employeeName(item['user_id']),
      _ => item['action'].toString(),
    };
    final subtitle = switch (table) {
      'employees' =>
        '${item['title']} · ${item['department']}\n${item['email']}',
      'branches' =>
        '${item['address']}\n${item['latitude']}, ${item['longitude']} · ${item['radius']}m',
      'shifts' =>
        '${item['start']} — ${item['end']} · Nghỉ ${item['break_minutes']}p\n${d.branchName(item['branch_id'])}',
      'assignments' =>
        '${displayDate(item['work_date'])} · ${d.shiftName(item['shift_id'])}',
      'locations' =>
        '${item['latitude']}, ${item['longitude']} · ±${item['accuracy']}m\nHết hạn ${DateTime.fromMillisecondsSinceEpoch((item['expires'] as int) * 1000).toLocal()}',
      _ => '${item['detail']}\n${item['created_at']} · #${item['actor_id']}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: mint,
                child: table == 'employees'
                    ? Text(
                        initials(title),
                        style: const TextStyle(
                          color: forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Icon(
                        switch (table) {
                          'branches' => Icons.business_outlined,
                          'shifts' => Icons.schedule,
                          'assignments' => Icons.event_available_outlined,
                          'locations' => Icons.location_on_outlined,
                          _ => Icons.history,
                        },
                        color: forest,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.8,
                        color: muted,
                      ),
                    ),
                    if (table == 'employees')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Tag(
                          item['active'] == false
                              ? 'Đã khóa'
                              : roleName(item['role']),
                          color: item['active'] == false
                              ? Colors.redAccent
                              : forest,
                        ),
                      ),
                  ],
                ),
              ),
              if (editable)
                PopupMenuButton<String>(
                  tooltip: 'Thao tác',
                  onSelected: (value) =>
                      value == 'edit' ? edit(item) : remove(item),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        table == 'employees' ? 'Khóa tài khoản' : 'Xóa',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (table == 'branches')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => BranchQr(data: d, branch: item),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 17),
                label: const Text(
                  'Mở QR chấm công',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          if (table == 'locations')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${item['latitude']},${item['longitude']}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: const Text('Xem trên bản đồ'),
              ),
            ),
        ],
      ),
    );
  }
}

class BranchQr extends StatefulWidget {
  final Workspace data;
  final Json branch;
  const BranchQr({super.key, required this.data, required this.branch});
  @override
  State<BranchQr> createState() => _BranchQrState();
}

class _BranchQrState extends State<BranchQr> {
  String? token, error;
  int remaining = 0;
  bool busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      token = null;
    });
    try {
      final result = await widget.data.api.request(
        'GET',
        '/qr/${widget.branch['id']}',
      );
      if (!mounted) return;
      setState(() {
        token = result['qr_token'];
        remaining = result['expires_in'];
      });
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => remaining--);
        if (remaining <= 5) {
          timer?.cancel();
          refresh();
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('QR chấm công'),
    content: SizedBox(
      width: 310,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.branch['name'], textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (widget.data.api.demo)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Tag(
                'QR DEMO · KHÔNG DÙNG TRÊN API THẬT',
                color: Colors.orange,
              ),
            ),
          if (token != null && remaining > 0)
            QrImageView(data: token!, size: 260, backgroundColor: Colors.white)
          else if (busy)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Text(error ?? 'QR hết hạn'),
          const SizedBox(height: 12),
          Text(
            'Tự đổi mã · Còn ${remaining > 0 ? remaining : 0}s',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhân viên cần ở trong phạm vi văn phòng và được phân ca hôm nay.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: busy ? null : refresh, child: const Text('Đổi mã')),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
