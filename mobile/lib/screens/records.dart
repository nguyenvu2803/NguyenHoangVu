import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/common.dart';
import '../widgets/editor.dart';

String displayTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '—';
  // API stores UTC; legacy SQLite responses omit suffix but represent UTC.
  final normalized =
      parsed.isUtc || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value.toString())
      ? parsed.toLocal()
      : parsed;
  return DateFormat('HH:mm').format(normalized);
}

String displayDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '—' : DateFormat('dd/MM/yyyy').format(date);
}

class AttendanceRow extends StatelessWidget {
  final Json item;
  final Workspace data;
  const AttendanceRow({super.key, required this.item, required this.data});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 500;
        return Row(
          children: [
            Container(
              width: 42,
              height: 44,
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${DateTime.parse(item['work_date']).day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'TH.${DateTime.parse(item['work_date']).month.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: muted, fontSize: 7),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.admin
                        ? data.employeeName(item['user_id'])
                        : data.shiftName(item['shift_id']),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wide
                        ? 'GPS + QR · ${item['work_date']}'
                        : '${displayTime(item['check_in'])} — ${displayTime(item['check_out'])}',
                    style: const TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              SizedBox(
                width: 85,
                child: Text(
                  displayTime(item['check_in']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 85,
                child: Text(
                  displayTime(item['check_out']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            Tag(
              item['check_out'] == null
                  ? 'Trong ca'
                  : (item['late_minutes'] ?? 0) > 0
                  ? 'Trễ ${item['late_minutes']}p'
                  : 'Đúng giờ',
              color: (item['late_minutes'] ?? 0) > 0
                  ? const Color(0xFFB47D4F)
                  : forest,
            ),
          ],
        );
      },
    ),
  );
}

class AttendancePage extends StatefulWidget {
  final Workspace data;
  const AttendancePage({super.key, required this.data});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String query = '', filter = 'all';
  bool exporting = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final records = d.attendance
        .where(
          (e) =>
              ('${d.employeeName(e['user_id'])} ${e['work_date']}')
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (filter == 'all' ||
                  filter == 'late' && (e['late_minutes'] ?? 0) > 0 ||
                  filter == 'active' && e['check_out'] == null),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'Mỗi ngày đều được ghi nhận',
          title: 'Bảng chấm công.',
          subtitle:
              '${d.admin ? 'Bảng công đội ngũ' : 'Lịch sử giờ làm của bạn'} · ${d.attendance.length} bản ghi gần nhất',
          action: d.admin
              ? IconButton.filled(
                  tooltip: 'Xuất CSV toàn bộ bảng công',
                  onPressed: exporting
                      ? null
                      : () async {
                          setState(() => exporting = true);
                          try {
                            final csv = await d.api.exportCsv();
                            if (!context.mounted) return;
                            final box =
                                context.findRenderObject() as RenderBox?;
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [
                                  XFile.fromData(
                                    Uint8List.fromList(utf8.encode(csv)),
                                    mimeType: 'text/csv',
                                    name: 'attendance.csv',
                                  ),
                                ],
                                fileNameOverrides: ['attendance.csv'],
                                sharePositionOrigin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) & box.size,
                              ),
                            );
                          } catch (e) {
                            if (context.mounted) toast(context, e);
                          } finally {
                            if (mounted) setState(() => exporting = false);
                          }
                        },
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                )
              : null,
        ),
        Panel(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm ngày (yyyy-mm-dd) hoặc tên nhân viên',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  children: [
                    for (final entry in {
                      'all': 'Tất cả',
                      'late': 'Đi trễ',
                      'active': 'Đang trong ca',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: filter == entry.key,
                        onSelected: (_) => setState(() => filter = entry.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              if (records.isEmpty)
                const EmptyState(
                  'Chưa có bản ghi phù hợp',
                  'Thử đổi bộ lọc hoặc chấm công ca đầu tiên.',
                )
              else
                ...records.map((item) => AttendanceRow(item: item, data: d)),
            ],
          ),
        ),
      ],
    );
  }
}

class SchedulePage extends StatefulWidget {
  final Workspace data;
  const SchedulePage({super.key, required this.data});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selected;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = first.weekday - 1;
    final records = d.assignments
        .where(
          (e) => selected == null
              ? e['work_date'].toString().startsWith(
                  DateFormat('yyyy-MM').format(month),
                )
              : e['work_date'] == d.day(selected!),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'Chủ động từng ngày',
          title: 'Lịch làm việc.',
          subtitle: d.admin
              ? 'Theo dõi lịch đội ngũ. Phân ca tại mục Quản lý.'
              : 'Xem ca được phân và sắp xếp thời gian của bạn.',
        ),
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () => setState(() {
                      month = DateTime(month.year, month.month - 1);
                      selected = null;
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Tháng ${month.month}, ${month.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () => setState(() {
                      month = DateTime(month.year, month.month + 1);
                      selected = null;
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (final day in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                    Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ((days + offset) / 7).ceil() * 7,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 54,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day < 1 || day > days) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, day);
                  final dateKey = d.day(date);
                  final assigned = d.assignments.any(
                    (e) => e['work_date'] == dateKey,
                  );
                  final isSelected =
                      selected != null && d.day(selected!) == dateKey;
                  final isToday = dateKey == d.today;
                  return Material(
                    color: isSelected
                        ? forest
                        : isToday
                        ? mint
                        : assigned
                        ? paper
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          setState(() => selected = isSelected ? null : date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: isSelected ? Colors.white : ink,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: assigned
                                  ? (isSelected ? peach : forest)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '● Có ca làm việc · Chọn ngày để lọc, chọn lại để bỏ lọc',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected == null
                    ? 'Các ca trong tháng'
                    : 'Lịch ngày ${displayDate(d.day(selected!))}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              if (records.isEmpty)
                const EmptyState(
                  'Chưa có lịch làm việc',
                  'Quản trị viên phân ca trong mục Quản lý.',
                )
              else
                ...records.map((e) {
                  final shift = d.shifts
                      .where((s) => s['id'] == e['shift_id'])
                      .firstOrNull;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: mint,
                      child: Icon(Icons.schedule, color: forest),
                    ),
                    title: Text(
                      d.shiftName(e['shift_id']),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${displayDate(e['work_date'])} · ${d.admin ? '${d.employeeName(e['user_id'])} · ' : ''}${d.branchName(shift?['branch_id'])}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Text(
                      '${shift?['start'] ?? '—'}\n${shift?['end'] ?? '—'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class LeavesPage extends StatefulWidget {
  final Workspace data;
  const LeavesPage({super.key, required this.data});
  @override
  State<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends State<LeavesPage> {
  String filter = 'all';
  final labels = {
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'rejected': 'Từ chối',
  };
  Future<void> edit([Json? item]) async {
    final saved = await showEditor(
      context,
      title: item == null ? 'Tạo đơn nghỉ phép' : 'Cập nhật đơn nghỉ',
      fields: const [
        FormFieldSpec(
          'kind',
          'Loại nghỉ',
          options: {
            'Nghỉ phép': 'Nghỉ phép',
            'Nghỉ ốm': 'Nghỉ ốm',
            'Việc cá nhân': 'Việc cá nhân',
            'Làm từ xa': 'Làm từ xa',
          },
        ),
        FormFieldSpec('start_date', 'Từ ngày', type: 'date'),
        FormFieldSpec('end_date', 'Đến ngày', type: 'date'),
        FormFieldSpec('reason', 'Lý do (tối thiểu 5 ký tự)', type: 'multiline'),
      ],
      initial:
          item ??
          {
            'kind': 'Nghỉ phép',
            'start_date': widget.data.today,
            'end_date': widget.data.today,
          },
      save: (values) async {
        if (values['reason'].toString().length < 5) {
          throw ApiException('Lý do cần ít nhất 5 ký tự');
        }
        if (values['end_date'].toString().compareTo(
              values['start_date'].toString(),
            ) <
            0) {
          throw ApiException('Ngày kết thúc phải từ ngày bắt đầu');
        }
        await widget.data.api.request(
          item == null ? 'POST' : 'PUT',
          '/leaves${item == null ? '' : '/${item['id']}'}',
          values,
        );
      },
    );
    if (saved) await widget.data.reload();
  }

  Future<void> decision(Json item, String status) async {
    final confirmed = await confirm(
      context,
      status == 'approved' ? 'Duyệt đơn nghỉ?' : 'Từ chối đơn nghỉ?',
      '${widget.data.employeeName(item['user_id'])} · ${displayDate(item['start_date'])} — ${displayDate(item['end_date'])}',
    );
    if (!confirmed) return;
    try {
      await widget.data.api.request('POST', '/leaves/${item['id']}/decision', {
        'status': status,
      });
      await widget.data.reload();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final records = d.leaves
        .where((e) => filter == 'all' || e['status'] == filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'Nghỉ ngơi cũng là một phần công việc',
          title: 'Khoảng nghỉ.',
          subtitle: d.admin
              ? 'Quản lý đơn của bạn và duyệt đơn đội ngũ.'
              : 'Tạo, theo dõi và chỉnh sửa đơn nghỉ của bạn.',
          action: IconButton.filled(
            tooltip: 'Tạo đơn nghỉ',
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final entry in {'all': 'Tất cả', ...labels}.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: filter == entry.key,
                onSelected: (_) => setState(() => filter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (records.isEmpty)
          const Panel(
            child: EmptyState(
              'Chưa có đơn nghỉ',
              'Tạo đơn mới khi bạn cần một khoảng nghỉ.',
              icon: Icons.beach_access_outlined,
            ),
          ),
        ...records.map((item) {
          final own = item['user_id'] == d.user['id'];
          final pending = item['status'] == 'pending';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.beach_access_outlined, color: forest),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['kind'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Tag(
                        labels[item['status']] ?? item['status'],
                        color: item['status'] == 'rejected'
                            ? const Color(0xFFAC5A4A)
                            : pending
                            ? const Color(0xFFAA7841)
                            : forest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${displayDate(item['start_date'])} — ${displayDate(item['end_date'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  if (d.admin)
                    Text(
                      d.employeeName(item['user_id']),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    item['reason'],
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  if (pending && (own || d.admin)) ...[
                    const SizedBox(height: 17),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (own) ...[
                          OutlinedButton.icon(
                            onPressed: () => edit(item),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Chỉnh sửa'),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (!await confirm(
                                context,
                                'Xóa đơn nghỉ?',
                                'Đơn đang chờ duyệt sẽ bị xóa.',
                              )) {
                                return;
                              }
                              try {
                                await d.api.request(
                                  'DELETE',
                                  '/leaves/${item['id']}',
                                );
                                await d.reload();
                              } catch (e) {
                                if (context.mounted) toast(context, e);
                              }
                            },
                            child: const Text('Xóa đơn'),
                          ),
                        ] else if (d.admin) ...[
                          FilledButton.icon(
                            onPressed: () => decision(item, 'approved'),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Duyệt đơn'),
                          ),
                          OutlinedButton(
                            onPressed: () => decision(item, 'rejected'),
                            child: const Text('Từ chối'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
