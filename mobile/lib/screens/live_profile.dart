import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/live.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'attendance_flow.dart' show currentPosition;
import 'settings.dart';

class LiveReport extends StatefulWidget {
  final LiveData data;
  const LiveReport({super.key, required this.data});
  @override
  State<LiveReport> createState() => _LiveReportState();
}

class _LiveReportState extends State<LiveReport> {
  late Json report = widget.data.report;
  late String month = widget.data.month;
  bool busy = false;
  String? error;
  Future<void> load(String value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = Json.from(
        await widget.data.api.request('GET', '/reports/monthly?month=$value'),
      );
      if (mounted) {
        setState(() {
          report = result;
          month = value;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    try {
      final file = XFile.fromData(
        utf8.encode(reportCsv(report)),
        mimeType: 'text/csv',
        name: 'NguyenHoangVu-$month.csv',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: ['NguyenHoangVu-$month.csv'],
          sharePositionOrigin: const Rect.fromLTWH(20, 20, 100, 100),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = report['totals'] as Map? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          eyebrow: 'BẢNG THÁNG',
          title: 'Giờ công rõ ràng.',
          subtitle:
              'Giờ đã điều chỉnh và giờ thiết bị gốc được hiển thị riêng.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse('$month-01'),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        await load(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}',
                        );
                      }
                    },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(month),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => load(month),
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : export,
              icon: const Icon(Icons.ios_share),
              label: const Text('Xuất CSV'),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Tag('${totals['shiftCount'] ?? 0} ca'),
            Tag('${totals['completedCount'] ?? 0} hoàn tất'),
            Tag('${totals['lateCount'] ?? 0} đi muộn'),
            Tag('${totals['missingCheckOutCount'] ?? 0} thiếu giờ ra'),
          ],
        ),
        const SizedBox(height: 20),
        if ((report['rows'] as List? ?? []).isEmpty)
          const EmptyState(
            'Chưa có ca trong tháng',
            'Chọn tháng khác hoặc liên hệ quản lý.',
          ),
        for (final row in objects(report['rows'] ?? []))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['employeeName']} · ${row['title']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${row['workDate']} · ${row['branchName']}'),
                  Text(
                    'Vào: ${dateTimeText(row['checkInAt'])}\nRa: ${dateTimeText(row['checkOutAt'])}',
                  ),
                  const SizedBox(height: 8),
                  Tag(stateText(row['timing']?['state'])),
                  const SizedBox(height: 8),
                  Text(
                    'Sau điều chỉnh: ${row['timing']?['rawSpanMinutes'] ?? '—'} phút\nThiết bị gốc: ${row['timing']?['recordedSpanMinutes'] ?? '—'} phút',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        Text(
          'Múi giờ báo cáo: ${report['timeZone'] ?? 'Asia/Ho_Chi_Minh'}. Màn hình hiển thị giờ thiết bị. Khoảng phút không phải bảng lương hay tăng ca được duyệt.',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

void openLiveReport(BuildContext context, LiveData data) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Báo cáo tháng')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: LiveReport(data: data),
        ),
      ),
    ),
  ),
);

class LiveProfile extends StatefulWidget {
  final Session session;
  final LiveData data;
  final Future<void> Function(Future<void> Function()) act;
  const LiveProfile({
    super.key,
    required this.session,
    required this.data,
    required this.act,
  });
  @override
  State<LiveProfile> createState() => _LiveProfileState();
}

class _LiveProfileState extends State<LiveProfile> {
  int ttl = 15;
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          eyebrow: 'CÁ NHÂN',
          title: 'Kết nối có kiểm soát.',
          subtitle: 'Khuôn mặt và vị trí chỉ bật khi bạn chọn.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: mint,
                child: Text(initials(d.user['fullName'] ?? '')),
              ),
              const SizedBox(height: 14),
              Text(
                '${d.user['fullName']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${d.user['email']}'),
              const SizedBox(height: 10),
              Tag(roleName(d.user['role'])),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => openLiveReport(context, d),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Báo cáo tháng'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cài đặt cá nhân',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Thiết lập khuôn mặt, cỡ chữ, màu nền và cập nhật hồ sơ.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(session: widget.session),
                    ),
                  );
                  if (mounted && widget.session.user != null) {
                    setState(() => d.user = widget.session.user!);
                    await widget.act(d.load);
                  }
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Mở Cài đặt'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: forest, size: 30),
              const SizedBox(height: 12),
              Text(
                'Chia sẻ vị trí có hạn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gửi một vị trí hiện tại cho quản lý theo phân quyền. Không tự theo dõi nền hoặc tự gia hạn.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: ttl,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Thời hạn chia sẻ',
                ),
                items: [15, 30, 60, 120]
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v phút')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => ttl = v ?? 15),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => widget.act(() async {
                  if (!await confirm(
                    context,
                    'Chia sẻ vị trí?',
                    'Quản lý có quyền sẽ xem tọa độ hiện tại trong $ttl phút. Bạn có thể dừng sớm.',
                  )) {
                    return;
                  }
                  final p = await currentPosition();
                  await d.api.request('POST', '/location-shares', {
                    'latitude': p.latitude,
                    'longitude': p.longitude,
                    'accuracyMeters': p.accuracy,
                    'ttlMinutes': ttl,
                  });
                  if (context.mounted) {
                    toast(context, 'Đã chia sẻ vị trí trong $ttl phút.');
                  }
                }),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Chia sẻ vị trí hiện tại'),
              ),
              const SizedBox(height: 12),
              if (d.locations.isEmpty)
                const Text(
                  'Không có vị trí đang chia sẻ.',
                  style: TextStyle(color: muted),
                ),
              for (final r in d.locations)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['fullName']}'),
                      Text(
                        '${r['latitude'] ?? r['lat']}, ${r['longitude'] ?? r['lng']} · sai số ${r['accuracyMeters']} m',
                      ),
                      Text(
                        'Hết hạn: ${dateTimeText(r['expiresAt'])}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            if (!await launchUrl(
                              locationMapUri(r),
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw ApiException('Không mở được bản đồ.');
                            }
                          } catch (e) {
                            if (context.mounted) toast(context, e);
                          }
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Mở bản đồ'),
                      ),
                      if (r['userId'] == d.user['id'])
                        TextButton(
                          onPressed: () => widget.act(() async {
                            await d.api.request(
                              'DELETE',
                              '/location-shares/${r['id']}',
                            );
                          }),
                          child: const Text('Dừng chia sẻ'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await widget.session.logout();
            } catch (e) {
              if (context.mounted) {
                toast(
                  context,
                  'Đã xóa phiên trên thiết bị. Máy chủ chưa xác nhận đăng xuất: $e',
                );
              }
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }
}
